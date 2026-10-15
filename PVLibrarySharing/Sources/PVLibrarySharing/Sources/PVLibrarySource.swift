//
//  PVLibrarySource.swift
//  PVLibrarySharing
//
//  Client for the shared v1.1 type `_pvlibrary._tcp` (spec §3.2, phase 4).
//

import Foundation
import PVSystems

/// Browses and copies from a `_pvlibrary._tcp` peer (another Provenance today).
///
/// - Auth: iFly's consent flow (`library/auth/start {peerId,name,publicKey}`,
///   202 while the owner decides) signed with `pvlibrary-auth-v1|`.
/// - Catalogue: `GET library/catalog?systemIdentifier=…&limit=200&cursor=…`
///   page by page until `nextCursor` is absent. A 410 (the catalogue changed
///   between pages) starts over once. The first page's `ETag` is cached and
///   a 304 reuses the whole list. Results are always filtered locally too.
/// - Copy: `GET library/manifest?key=` (202 while an "Ask per game" owner
///   decides, 403 declined), then `GET library/file?key=&path=` with Range.
public actor PVLibrarySource: LibrarySource {
    public static let pageSize = 200
    public static let defaultApprovalTimeout: TimeInterval = 120
    public static let defaultPollInterval: TimeInterval = 1

    public nonisolated let app: PeerApp = .pvLibrary

    private let candidates: [URL]
    private let identity: PeerIdentity
    private let transport: any LibraryHTTPTransport
    private let systems: Set<SystemIdentifier>?
    private let pollInterval: TimeInterval
    private let approvalTimeout: TimeInterval

    private var activeBase: URL?
    private var token: String?
    private var cached: (etag: String, catalogue: RemoteCatalogue)?

    /// - Parameter systems: sent as the catalogue filter (the systems this
    ///   device can play); nil asks for everything.
    public init(
        baseURLs: [URL],
        identity: PeerIdentity,
        systems: Set<SystemIdentifier>? = nil,
        transport: any LibraryHTTPTransport = URLSessionLibraryTransport(),
        pollInterval: TimeInterval = PVLibrarySource.defaultPollInterval,
        approvalTimeout: TimeInterval = PVLibrarySource.defaultApprovalTimeout
    ) {
        self.candidates = baseURLs
        self.identity = identity
        self.systems = systems
        self.transport = transport
        self.pollInterval = pollInterval
        self.approvalTimeout = approvalTimeout
    }

    // MARK: - Catalogue

    public func catalogue(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        progress(.connecting)
        do {
            return try await loadAllPages(progress: progress)
        } catch CatalogueQuery.PageError.staleCursor {
            return try await loadAllPages(progress: progress)
        }
    }

    private func loadAllPages(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> RemoteCatalogue {
        var items: [RemoteLibraryItem] = []
        var deviceName = ""
        var cursor: String?
        var firstETag: String?
        repeat {
            let query = CatalogueQuery(systems: systems, limit: Self.pageSize, cursor: cursor)
            let response = try await authorizedGet(ContinuityRoutes.iCubeLibraryCatalog, items: query.queryItems,
                                                   ifNoneMatch: cursor == nil ? cached?.etag : nil, progress: progress)
            switch response.status {
            case 200:
                let page = try Self.decodeCatalog(response.body)
                deviceName = page.sourceDevice.name
                items += page.entries.map(Self.item)
                if cursor == nil { firstETag = response.header("ETag") }
                cursor = page.nextCursor
            case 304 where cursor == nil:
                guard let cached else { throw LibrarySharingError.invalidResponse(status: 304) }
                return cached.catalogue
            case 410:
                throw CatalogueQuery.PageError.staleCursor
            default:
                throw Self.error(forStatus: response.status)
            }
        } while cursor != nil
        let all = RemoteCatalogue(deviceName: deviceName, items: items, source: .pvLibrary)
        let catalogue = systems.map { all.filtered(to: $0) } ?? all
        // The ETag covers the whole filtered list, not just the first page.
        if let firstETag { cached = (firstETag, catalogue) }
        return catalogue
    }

    static func decodeCatalog(_ data: Data) throws -> PVWireCatalog {
        struct VersionProbe: Decodable { var version: Int }
        let version = try JSONDecoder().decode(VersionProbe.self, from: data).version
        guard ICubeLibraryCatalog.supportedVersions.contains(version) else {
            throw LibrarySharingError.unsupportedCatalogueVersion(version)
        }
        return try JSONDecoder().decode(PVWireCatalog.self, from: data)
    }

    static func item(_ entry: PVWireCatalog.Entry) -> RemoteLibraryItem {
        let system = (entry.systemIdentifier ?? entry.game.platform).flatMap { SystemMap.systemIdentifier(compact: $0) }
        return RemoteLibraryItem(
            id: entry.key, title: entry.game.displayName, platform: entry.game.platform, systemIdentifier: system,
            md5: entry.game.md5, sizeBytes: entry.sizeBytes, artKey: entry.hasArtwork ? entry.key : nil,
            source: .pvLibrary, gameID: entry.game.gameID, discNumber: entry.game.discNumber, revision: entry.game.revision
        )
    }

    public func artwork(for item: RemoteLibraryItem) async throws -> Data? {
        guard let artKey = item.artKey else { return nil }
        let response = try await authorizedGet(ContinuityRoutes.libraryArt, items: [URLQueryItem(name: "key", value: artKey)],
                                               ifNoneMatch: nil, progress: { _ in })
        return response.status == 200 ? response.body : nil
    }

    // MARK: - Copy

    public func pullManifest(
        for item: RemoteLibraryItem,
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteManifest {
        progress(.connecting)
        let deadline = Date().addingTimeInterval(approvalTimeout)
        while true {
            try Task.checkCancellation()
            let response = try await authorizedGet(ContinuityRoutes.iCubeLibraryManifest, items: [URLQueryItem(name: "key", value: item.id)],
                                                   ifNoneMatch: nil, progress: progress)
            switch response.status {
            case 200:
                return try JSONDecoder().decode(ContinuityPullManifest.self, from: response.body).remoteManifest(itemId: item.id)
            case 202:
                progress(.waitingForApproval)
                guard Date() < deadline else { throw LibrarySharingError.approvalTimedOut }
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            case 403:
                throw LibrarySharingError.pullDeclined
            case 404:
                throw LibrarySharingError.itemUnavailable
            default:
                throw Self.error(forStatus: response.status)
            }
        }
    }

    public func download(
        _ file: RemoteFile,
        of manifest: RemoteManifest,
        to partialFile: URL,
        resumeOffset: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> LibraryDownloadResponse {
        var reauthenticated = false
        while true {
            let token = try await libraryToken(progress: { _ in })
            guard let base = activeBase ?? candidates.first else { throw LibrarySharingError.unreachable }
            let request = LibraryHTTPRequest.authorizedGet(
                url: ContinuityRoutes.libraryFileURL(base: base, key: manifest.itemId, relativePath: file.relativePath), token: token
            )
            let response = try await transport.download(request, to: partialFile, resumeOffset: resumeOffset, progress: progress)
            if isPullerHandledDownloadStatus(response.status) { return response }
            if response.status == 401 && !reauthenticated {
                reauthenticated = true
                self.token = nil
                continue
            }
            if response.status == 404 { throw LibrarySharingError.fileUnavailable(file.fileName) }
            throw Self.error(forStatus: response.status)
        }
    }

    // MARK: - Requests

    /// A GET with the library token, re-authenticating once on 401.
    private func authorizedGet(
        _ path: String,
        items: [URLQueryItem],
        ifNoneMatch: String?,
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> LibraryHTTPResponse {
        for attempt in 0..<2 {
            let token = try await libraryToken(progress: progress)
            progress(.loadingCatalogue)
            let (response, base) = try await sendToFirstReachable(
                candidates: candidates, preferred: activeBase, transport: transport
            ) { base in
                var components = URLComponents(url: base.appendingRoute(path), resolvingAgainstBaseURL: false)
                components?.queryItems = items.isEmpty ? nil : items
                var request = LibraryHTTPRequest.authorizedGet(url: components?.url ?? base.appendingRoute(path), token: token)
                if let ifNoneMatch { request.headers["If-None-Match"] = ifNoneMatch }
                return request
            }
            activeBase = base
            if response.status == 401 && attempt == 0 {
                self.token = nil
                continue
            }
            return response
        }
        throw LibrarySharingError.sharingUnavailable
    }

    private func libraryToken(progress: @escaping @Sendable (LibraryBrowseProgress) -> Void) async throws -> String {
        if let token { return token }
        let startBody = ConsentAuthStart(peerId: identity.id, name: identity.name, publicKey: identity.publicKeyData, icloudHash: nil)
        let (startResponse, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            try .jsonPost(url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthStart), body: startBody)
        }
        activeBase = base
        guard startResponse.status == 200 else { throw Self.error(forStatus: startResponse.status) }
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: startResponse.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .pvLibrary, nonce: challenge.nonce, peerId: identity.id,
            serverId: challenge.serverId, signingKey: identity.signingKey
        )
        let complete = try LibraryHTTPRequest.jsonPost(
            url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: identity.id, signature: signature)
        )
        let deadline = Date().addingTimeInterval(approvalTimeout)
        while true {
            try Task.checkCancellation()
            let response = try await transport.send(complete)
            switch response.status {
            case 200:
                let fresh = try JSONDecoder().decode(LibraryTokenResponse.self, from: response.body).libraryToken
                token = fresh
                return fresh
            case 202:
                progress(.waitingForApproval)
                guard Date() < deadline else { throw LibrarySharingError.approvalTimedOut }
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            default:
                throw Self.error(forStatus: response.status)
            }
        }
    }

    static func error(forStatus status: Int) -> LibrarySharingError {
        switch status {
        case 401, 404: return .sharingUnavailable
        case 403: return .declined
        case 410: return .expired
        case 429: return .tooManyPeers
        default: return .invalidResponse(status: status)
        }
    }
}
