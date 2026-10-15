//
//  ICubeContinuitySource.swift
//  PVLibrarySharing
//
//  Client for iCube's library dialect (PVContinuity, spec §1.2).
//

import Foundation

/// An iCube pairing in flight: what `completePairing` needs once the user has
/// typed the code shown on the iCube device.
public struct ICubePairingHandle: Sendable, Equatable {
    public let pairingId: String
    public let serverId: String
    /// The iCube device's name, for "Enter the code shown on <name>".
    public let serverName: String
    public let serverPublicKey: Data
}

/// Browses an iCube library.
///
/// iCube serves its library only to **paired** peers: `library/auth/start
/// {peerId}` answers 403 otherwise (and also when the host has sharing off
/// for this peer; iCube doesn't tell the two apart). Pairing is a 6-digit code
/// shown on the iCube device:
///
/// 1. `POST pair/start {peerId,name,publicKey}` →
///    `{pairingId,serverId,serverName,serverPublicKey}`; the host shows the
///    code and an approval prompt.
/// 2. `POST pair/complete {pairingId,proof}`, where `proof` is HMAC-SHA256
///    keyed on SHA-256(code) over the `icube-continuity-pair-v1|` transcript.
///    202 while the owner hasn't answered (poll), 401 wrong code (retry),
///    403 declined, 410 expired. iCube stores the trust **before** looking for
///    a handoff session, so both 200 and 404 "no active handoff session" mean
///    paired.
///
/// Then: `library/auth/start` + `complete` (signature over
/// `"icube-continuity-auth-v1|peerId|serverId|" + nonce`) → `{libraryToken}`,
/// `GET library/catalog` (Bearer, version-checked) and `GET library/art?key=`
/// with the entry's `stableKey`.
public actor ICubeContinuitySource: LibrarySource {
    public static let defaultApprovalTimeout: TimeInterval = 120
    public static let defaultPollInterval: TimeInterval = 1

    public nonisolated let app: PeerApp = .iCube

    private let candidates: [URL]
    private let identity: PeerIdentity
    private let transport: any LibraryHTTPTransport
    private let pollInterval: TimeInterval
    private let approvalTimeout: TimeInterval

    private var activeBase: URL?
    private var token: String?

    public init(
        baseURLs: [URL],
        identity: PeerIdentity,
        transport: any LibraryHTTPTransport = URLSessionLibraryTransport(),
        pollInterval: TimeInterval = ICubeContinuitySource.defaultPollInterval,
        approvalTimeout: TimeInterval = ICubeContinuitySource.defaultApprovalTimeout
    ) {
        self.candidates = baseURLs
        self.identity = identity
        self.transport = transport
        self.pollInterval = pollInterval
        self.approvalTimeout = approvalTimeout
    }

    // MARK: - LibrarySource

    /// Throws `LibrarySharingError.notPaired` when the host doesn't know this
    /// device: offer `beginPairing()`.
    public func catalogue(
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> RemoteCatalogue {
        progress(.connecting)
        var response = try await authorizedGet(path: ContinuityRoutes.iCubeLibraryCatalog, key: nil, progress: progress)
        if response.status == 401 {
            token = nil
            response = try await authorizedGet(path: ContinuityRoutes.iCubeLibraryCatalog, key: nil, progress: progress)
        }
        switch response.status {
        case 200:
            return try Self.decodeCatalogue(response.body)
        default:
            if response.status == 401 || response.status == 403 { token = nil }
            throw Self.error(forStatus: response.status)
        }
    }

    public func artwork(for item: RemoteLibraryItem) async throws -> Data? {
        guard let artKey = item.artKey else { return nil }
        let response = try await authorizedGet(path: ContinuityRoutes.libraryArt, key: artKey, progress: { _ in })
        // A missing cover is a placeholder, never an error (iCube's own client agrees).
        return response.status == 200 ? response.body : nil
    }

    // MARK: - Pairing

    /// Asks the iCube device to show a pairing code.
    public func beginPairing() async throws -> ICubePairingHandle {
        let body = ICubePairStartRequest(peerId: identity.id, name: identity.name, publicKey: identity.publicKeyData)
        let (response, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            try .jsonPost(url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.pairStart), body: body)
        }
        activeBase = base
        guard response.status == 200 else { throw Self.error(forStatus: response.status) }
        let started = try JSONDecoder().decode(ICubePairStartResponse.self, from: response.body)
        return ICubePairingHandle(
            pairingId: started.pairingId,
            serverId: started.serverId,
            serverName: started.serverName,
            serverPublicKey: started.serverPublicKey
        )
    }

    /// Submits the code and polls until the owner approves. Returns when this
    /// device is paired. Throws `.wrongCode` (retryable with the same handle),
    /// `.declined`, `.expired` or `.approvalTimedOut`.
    public func completePairing(_ handle: ICubePairingHandle, code: String) async throws {
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .iCube,
            pairingId: handle.pairingId,
            clientId: identity.id,
            serverId: handle.serverId,
            clientPublicKey: identity.publicKeyData,
            serverPublicKey: handle.serverPublicKey
        )
        let body = ICubePairCompleteRequest(
            pairingId: handle.pairingId,
            proof: ContinuityAuthMath.pairingProof(code: code, transcript: transcript)
        )
        let deadline = Date().addingTimeInterval(approvalTimeout)
        while true {
            try Task.checkCancellation()
            let (response, base) = try await sendToFirstReachable(
                candidates: candidates, preferred: activeBase, transport: transport
            ) { base in
                try .jsonPost(url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.pairComplete), body: body)
            }
            activeBase = base
            switch Self.pairingOutcome(forStatus: response.status) {
            case .paired:
                token = nil
                return
            case .pending:
                guard Date() < deadline else { throw LibrarySharingError.approvalTimedOut }
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            case .failed(let error):
                throw error
            }
        }
    }

    enum PairingOutcome: Equatable {
        case paired
        case pending
        case failed(LibrarySharingError)
    }

    /// `pair/complete` statuses (iCube `ContinuityPairingServer`).
    static func pairingOutcome(forStatus status: Int) -> PairingOutcome {
        switch status {
        // 404 "no active handoff session": trust was stored, there was just no
        // handoff token to return. Confirmed by the iCube session (spec, answers).
        case 200, 404: return .paired
        case 202: return .pending
        case 401: return .failed(.wrongCode)
        case 403: return .failed(.declined)
        case 410: return .failed(.expired)
        case 429: return .failed(.tooManyPeers)
        default: return .failed(.invalidResponse(status: status))
        }
    }

    // MARK: - Mapping

    static func decodeCatalogue(_ data: Data) throws -> RemoteCatalogue {
        struct VersionProbe: Decodable { var version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let probe = try decoder.decode(VersionProbe.self, from: data)
        guard ICubeLibraryCatalog.supportedVersions.contains(probe.version) else {
            throw LibrarySharingError.unsupportedCatalogueVersion(probe.version)
        }
        let catalog = try decoder.decode(ICubeLibraryCatalog.self, from: data)
        let items = catalog.entries.map { entry in
            RemoteLibraryItem(
                id: entry.key,
                title: entry.game.displayName,
                platform: entry.game.platform,
                systemIdentifier: SystemMap.systemIdentifier(forPlatform: entry.game.platform, app: .iCube),
                md5: entry.game.md5,
                sizeBytes: entry.sizeBytes,
                artKey: entry.hasArtwork ? entry.key : nil,
                source: .iCube,
                gameID: entry.game.gameID,
                discNumber: entry.game.discNumber,
                revision: entry.game.revision
            )
        }
        return RemoteCatalogue(deviceName: catalog.sourceDevice.name, items: items, source: .iCube)
    }

    // MARK: - Private

    private func authorizedGet(
        path: String,
        key: String?,
        progress: @escaping @Sendable (LibraryBrowseProgress) -> Void
    ) async throws -> LibraryHTTPResponse {
        let token = try await libraryToken()
        progress(.loadingCatalogue)
        let (response, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { base in
            .authorizedGet(url: ContinuityRoutes.url(base: base, path: path, key: key), token: token)
        }
        activeBase = base
        return response
    }

    private func libraryToken() async throws -> String {
        if let token { return token }
        let (startResponse, base) = try await sendToFirstReachable(
            candidates: candidates, preferred: activeBase, transport: transport
        ) { [peerId = identity.id] base in
            try .jsonPost(
                url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthStart),
                body: ICubeAuthStartRequest(peerId: peerId)
            )
        }
        activeBase = base
        guard startResponse.status == 200 else { throw Self.error(forStatus: startResponse.status) }
        let challenge = try JSONDecoder().decode(AuthStartResponse.self, from: startResponse.body)
        let signature = try ContinuityAuthMath.signAuth(
            domain: .iCube, nonce: challenge.nonce, peerId: identity.id,
            serverId: challenge.serverId, signingKey: identity.signingKey
        )
        let completeResponse = try await transport.send(.jsonPost(
            url: ContinuityRoutes.url(base: base, path: ContinuityRoutes.libraryAuthComplete),
            body: AuthCompleteRequest(authId: challenge.authId, peerId: identity.id, signature: signature)
        ))
        guard completeResponse.status == 200 else { throw Self.error(forStatus: completeResponse.status) }
        let fresh = try JSONDecoder().decode(LibraryTokenResponse.self, from: completeResponse.body).libraryToken
        token = fresh
        return fresh
    }

    /// iCube's library status mapping (`ContinuityLibraryClient` + server).
    static func error(forStatus status: Int) -> LibrarySharingError {
        switch status {
        case 401, 403: return .notPaired
        case 404: return .sharingUnavailable
        case 410: return .expired
        case 429: return .tooManyPeers
        default: return .invalidResponse(status: status)
        }
    }
}
