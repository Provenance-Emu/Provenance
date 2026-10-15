//
//  IFlyContinuitySource.swift
//  PVLibrarySharing
//
//  Client for iFly's library dialect (ContinuityKit, spec §1.1).
//

import Foundation

/// Browses an iFly library.
///
/// - Auth: `POST library/auth/start {peerId,name,publicKey,icloudHash?}` →
///   `{authId,serverId,nonce}`, then `library/auth/complete
///   {authId,peerId,signature}` → `{libraryToken}`. The signature is Ed25519
///   over `"ifly-continuity-auth-v1|peerId|serverId|" + nonce`. An unknown
///   peer gets a consent prompt on the host; `auth/complete` answers 202 until
///   the owner decides, and this client polls for up to `approvalTimeout`.
/// - Catalogue: `GET library/manifest` (Bearer) is the whole library, with an
///   `ETag`; a repeat fetch sends `If-None-Match` and a 304 reuses the cache.
/// - Art: `GET library/art?key=<artKey>` (Bearer).
public actor IFlyContinuitySource: LibrarySource {
    public static let defaultApprovalTimeout: TimeInterval = 120
    public static let defaultPollInterval: TimeInterval = 1

    public nonisolated let app: PeerApp = .iFly

    private let candidates: [URL]
    private let identity: PeerIdentity
    private let transport: any LibraryHTTPTransport
    private let icloudHash: String?
    private let pollInterval: TimeInterval
    private let approvalTimeout: TimeInterval

    private var activeBase: URL?
    private var token: String?
    private var cached: (etag: String, catalogue: RemoteCatalogue)?

    public init(
        baseURLs: [URL],
        identity: PeerIdentity,
        transport: any LibraryHTTPTransport = URLSessionLibraryTransport(),
        icloudHash: String? = nil,
        pollInterval: TimeInterval = IFlyContinuitySource.defaultPollInterval,
        approvalTimeout: TimeInterval = IFlyContinuitySource.defaultApprovalTimeout
    ) {
        self.candidates = baseURLs
        self.identity = identity
        self.transport = transport
        self.icloudHash = icloudHash
        self.pollInterval = pollInterval
        self.approvalTimeout = approvalTimeout
    }

    // MARK: - LibrarySource

    public func catalogue(
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteCatalogue {
        progress(.connecting)
        var response = try await fetchManifest(progress: progress)
        if response.status == 401 {
            // The token expired or the host restarted. Re-auth once.
            token = nil
            response = try await fetchManifest(progress: progress)
        }
        switch response.status {
        case 200:
            let manifest = try JSONDecoder().decode(IFlyLibraryManifest.self, from: response.body)
            let catalogue = Self.catalogue(from: manifest)
            if let etag = response.header("ETag") ?? manifest.catalogVersion {
                cached = (etag, catalogue)
            }
            return catalogue
        case 304:
            guard let cached else { throw LibrarySharingError.invalidResponse(status: 304) }
            return cached.catalogue
        default:
            if response.status == 401 { token = nil }
            throw Self.error(forStatus: response.status)
        }
    }

    public func artwork(for item: RemoteLibraryItem) async throws -> Data? {
        guard let artKey = item.artKey else { return nil }
        let token = try await libraryToken(progress: { _ in })
        let (response, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            .authorizedGet(url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryArt, key: artKey), token: token)
        }
        activeBase = base
        switch response.status {
        case 200: return response.body
        case 404: return nil
        default: throw Self.error(forStatus: response.status)
        }
    }

    // MARK: - Mapping

    static func catalogue(from manifest: IFlyLibraryManifest) -> RemoteCatalogue {
        let items = manifest.games.map { game in
            RemoteLibraryItem(
                id: game.id,
                title: game.title,
                platform: game.platform,
                systemIdentifier: SystemMap.systemIdentifier(forPlatform: game.platform, app: .iFly),
                md5: game.md5,
                sizeBytes: game.sizeBytes,
                artKey: game.artKey,
                source: .iFly
            )
        }
        return RemoteCatalogue(deviceName: manifest.deviceName, items: items, source: .iFly)
    }

    // MARK: - Private

    private func fetchManifest(
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> LibraryHTTPResponse {
        let token = try await libraryToken(progress: progress)
        progress(.loadingCatalogue)
        let etag = cached?.etag
        let (response, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            var request = LibraryHTTPRequest.authorizedGet(
                url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.iFlyLibraryManifest), token: token
            )
            if let etag { request.headers["If-None-Match"] = etag }
            return request
        }
        activeBase = base
        return response
    }

    private func libraryToken(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> String {
        if let token { return token }
        let fresh = try await authenticate(progress: progress)
        token = fresh
        return fresh
    }

    private func authenticate(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> String {
        let startBody = IFlyAuthStartRequest(
            peerId: identity.id, name: identity.name, publicKey: identity.publicKeyData, icloudHash: icloudHash
        )
        let (startResponse, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            try .jsonPost(url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthStart), body: startBody)
        }
        activeBase = base
        guard startResponse.status == 200 else {
            throw Self.error(forStatus: startResponse.status)
        }
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: startResponse.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .iFly, nonce: challenge.nonce, peerId: identity.id,
            serverId: challenge.serverId, signingKey: identity.signingKey
        )
        let completeRequest = try LibraryHTTPRequest.jsonPost(
            url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: identity.id, signature: signature)
        )

        let deadline = Date().addingTimeInterval(approvalTimeout)
        while true {
            try Task.checkCancellation()
            let response = try await transport.send(completeRequest)
            switch response.status {
            case 200:
                return try JSONDecoder().decode(LibraryTokenResponse.self, from: response.body).libraryToken
            case 202:
                progress(.waitingForApproval)
                guard Date() < deadline else { throw LibrarySharingError.approvalTimedOut }
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            default:
                throw Self.error(forStatus: response.status)
            }
        }
    }

    /// iFly's status mapping (`ContinuityLibraryClient.mapError`).
    static func error(forStatus status: Int) -> LibrarySharingError {
        switch status {
        case 401, 404: return .sharingUnavailable
        case 403: return .declined
        case 410: return .expired
        default: return .invalidResponse(status: status)
        }
    }
}
