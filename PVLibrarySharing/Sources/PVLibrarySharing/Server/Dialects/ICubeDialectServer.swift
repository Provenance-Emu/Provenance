//
//  ICubeDialectServer.swift
//  PVLibrarySharing
//
//  Provenance answering an unmodified iCube client (spec §3.1, phase 3).
//

import Foundation
import PVSystems

/// iCube's pairing and library routes, answered as iCube's
/// `ContinuityPairingServer` and `ContinuityLibraryServer` answer them:
///
/// - `POST pair/start {peerId,name,publicKey}` → `{pairingId,serverId,serverName,serverPublicKey}`
///   and the owner sees a 6-digit code. At most 3 pairings in flight (429).
/// - `POST pair/complete {pairingId,proof}`: 202 until the owner approves,
///   403 declined, 410 unknown/expired or out of tries, 401 wrong code. A
///   right code stores the trust, then answers **404 "no active handoff
///   session"**: Provenance never hosts a handoff, and iCube's client counts
///   that 404 as paired.
/// - `POST library/auth/start {peerId}`: 403 unless paired and sharing.
/// - `POST library/auth/complete`: `{libraryToken}`; 429 past 16 live tokens.
/// - `GET library/catalog`, `GET library/art?key=`, `GET library/manifest?key=`,
///   `GET library/file?key=&path=`. The file route re-derives the entry's
///   manifest and, for an "Ask per game" peer, waits for the owner's answer.
///
/// Only GameCube and Wii games are listed, as `Software/<file>`: the only
/// folder iCube's scanner reads.
public actor ICubeDialectServer {
    static let pairingLifetime: TimeInterval = 120
    static let authLifetime: TimeInterval = 30
    static let maxProofAttempts = 3
    static let maxPendingPairings = 3
    static let maxActiveTokens = 16
    static let softwareFolder = "Software"

    private struct PendingPairing {
        let request: ICubePairStartRequest
        let code: String
        let expiresAt: Date
        var attemptsLeft: Int
        var approval: Bool?
    }

    private struct PendingAuth {
        let peerId: String
        let nonce: Data
        let expiresAt: Date
    }

    private let identity: PeerIdentity
    private let device: HostDevice
    private let library: any SharedLibraryProviding
    private let trust: any HostTrustStore
    private let approver: any LibraryHostApproving
    private let hashes: FileHashCache
    private let sharingEnabled: @Sendable () async -> Bool
    private var pairings: [String: PendingPairing] = [:]
    private var auths: [String: PendingAuth] = [:]
    private var tokens = TokenRegistry(lifetime: 60 * 60)
    /// `peerId|key` pulls the owner allowed once.
    private var approvedPulls: Set<String> = []

    public init(
        identity: PeerIdentity,
        device: HostDevice,
        library: any SharedLibraryProviding,
        trust: any HostTrustStore,
        approver: any LibraryHostApproving,
        hashes: FileHashCache,
        sharingEnabled: @escaping @Sendable () async -> Bool
    ) {
        self.identity = identity
        self.device = device
        self.library = library
        self.trust = trust
        self.approver = approver
        self.hashes = hashes
        self.sharingEnabled = sharingEnabled
    }

    public func revokeAll() {
        pairings.removeAll()
        auths.removeAll()
        tokens.revokeAll()
        approvedPulls.removeAll()
    }

    public func revoke(peerId: String) {
        tokens.revoke(peerId: peerId)
        auths = auths.filter { $0.value.peerId != peerId }
        approvedPulls = approvedPulls.filter { !$0.hasPrefix("\(peerId)|") }
    }

    public func handle(_ request: ServerRequest) async -> ServerResponse {
        switch (request.method, request.path) {
        case ("POST", ContinuityRoutes.pairStart): return pairStart(request)
        case ("POST", ContinuityRoutes.pairComplete): return await pairComplete(request)
        default: break
        }
        guard await sharingEnabled() else { return .error(403, "this device isn't sharing its library") }
        switch (request.method, request.path) {
        case ("POST", ContinuityRoutes.libraryAuthStart): return await authStart(request)
        case ("POST", ContinuityRoutes.libraryAuthComplete): return await authComplete(request)
        default: break
        }
        guard let peer = await authorizedPeer(request) else {
            return .error(401, "invalid or expired library token")
        }
        switch (request.method, request.path) {
        case ("GET", ContinuityRoutes.iCubeLibraryCatalog): return await catalog()
        case ("GET", ContinuityRoutes.libraryArt): return await art(request)
        case ("GET", ContinuityRoutes.iCubeLibraryManifest): return await manifestRoute(request)
        case ("GET", ContinuityRoutes.libraryFile): return await file(request, peer: peer)
        default: return .error(404, "not found")
        }
    }

    // MARK: - Pairing

    private func pairStart(_ request: ServerRequest) -> ServerResponse {
        guard let body: ICubePairStartRequest = decodeBody(request) else { return .error(400, "invalid pairing request") }
        let now = Date()
        pairings = pairings.filter { $0.value.expiresAt > now }
        guard pairings.count < Self.maxPendingPairings else { return .error(429, "too many pairing attempts in flight") }
        let pairingId = UUID().uuidString
        let code = ServerTokens.pairingCode()
        pairings[pairingId] = PendingPairing(
            request: body, code: code, expiresAt: now.addingTimeInterval(Self.pairingLifetime), attemptsLeft: Self.maxProofAttempts
        )
        Task { [approver] in
            let approved = await withApprovalTimeout(Self.pairingLifetime) {
                await approver.approvePairing(peerName: body.name, code: code)
            } ?? false
            await self.resolvePairing(pairingId, approved: approved)
        }
        return .encoded(ICubePairStartResponse(
            pairingId: pairingId, serverId: identity.id, serverName: device.name, serverPublicKey: identity.publicKeyData
        ))
    }

    private func resolvePairing(_ pairingId: String, approved: Bool) {
        pairings[pairingId]?.approval = approved
    }

    private func pairComplete(_ request: ServerRequest) async -> ServerResponse {
        guard let body: ICubePairCompleteRequest = decodeBody(request) else { return .error(400, "invalid pairing completion") }
        guard var pending = pairings[body.pairingId], pending.expiresAt > Date() else {
            pairings[body.pairingId] = nil
            return .error(410, "pairing expired or unknown")
        }
        switch pending.approval {
        case nil:
            return .error(202, "waiting for approval on the other device")
        case false?:
            pairings[body.pairingId] = nil
            return .error(403, "pairing was declined")
        case true?:
            break
        }
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .iCube, pairingId: body.pairingId, clientId: pending.request.peerId,
            serverId: identity.id, clientPublicKey: pending.request.publicKey, serverPublicKey: identity.publicKeyData
        )
        guard ContinuityAuthMath.verifyPairingProof(body.proof, code: pending.code, transcript: transcript) else {
            pending.attemptsLeft -= 1
            if pending.attemptsLeft <= 0 {
                pairings[body.pairingId] = nil
                return .error(410, "too many bad codes — start pairing again")
            }
            pairings[body.pairingId] = pending
            return .error(401, "wrong code")
        }
        pairings[body.pairingId] = nil
        await trust.add(TrustedPeer(
            id: pending.request.peerId, name: pending.request.name,
            publicKey: pending.request.publicKey, app: PeerApp.iCube.rawValue
        ))
        // Trust first, then iCube's "no handoff session" answer: there is never one here.
        return .error(404, "no active handoff session")
    }

    // MARK: - Library auth

    private func grant(for peerId: String) async -> LibraryGrant {
        await trust.grant(forPeerId: peerId) ?? .askPerGame
    }

    private func authStart(_ request: ServerRequest) async -> ServerResponse {
        guard let body: ICubeAuthStartRequest = decodeBody(request) else { return .error(400, "invalid auth request") }
        if await grant(for: body.peerId) == .denied {
            return .error(403, "library sharing is turned off for this device")
        }
        guard await trust.peer(withId: body.peerId) != nil else { return .error(403, "not a paired device") }
        let now = Date()
        auths = auths.filter { $0.value.expiresAt > now }
        let authId = UUID().uuidString
        let nonce = ServerTokens.nonce()
        auths[authId] = PendingAuth(peerId: body.peerId, nonce: nonce, expiresAt: now.addingTimeInterval(Self.authLifetime))
        return .encoded(AuthStartResponse(authId: authId, serverId: identity.id, nonce: nonce))
    }

    private func authComplete(_ request: ServerRequest) async -> ServerResponse {
        guard let body: AuthCompleteRequest = decodeBody(request) else { return .error(400, "invalid auth completion") }
        guard let pending = auths.removeValue(forKey: body.authId), pending.expiresAt > Date(), pending.peerId == body.peerId else {
            return .error(410, "auth challenge expired or unknown")
        }
        guard let peer = await trust.peer(withId: body.peerId), ContinuityAuthMath.verifyAuth(
            domain: .iCube, signature: body.signature, nonce: pending.nonce,
            peerId: peer.id, serverId: identity.id, publicKey: peer.publicKey
        ) else {
            return .error(403, "signature verification failed")
        }
        if await grant(for: peer.id) == .denied {
            return .error(403, "library sharing is turned off for this device")
        }
        tokens.prune()
        guard tokens.count < Self.maxActiveTokens else { return .error(429, "too many devices browsing at once") }
        return .encoded(LibraryTokenResponse(libraryToken: tokens.mint(peerId: peer.id, peerName: peer.name)))
    }

    private func authorizedPeer(_ request: ServerRequest) async -> (id: String, name: String)? {
        guard let peer = tokens.peer(forAuthorization: request.header("Authorization")) else { return nil }
        guard await trust.peer(withId: peer.id) != nil, await grant(for: peer.id) != .denied else {
            revoke(peerId: peer.id)
            return nil
        }
        return peer
    }

    // MARK: - Catalogue

    private func entries() async -> [(game: SharedGame, identity: ICubeWireGameIdentity)] {
        await library.sharedGames().compactMap { game in
            guard let platform = SystemMap.wirePlatform(for: game.system, app: .iCube), !game.files.isEmpty else { return nil }
            return (game, ICubeWireGameIdentity(
                gameID: game.serial?.uppercased(), md5: game.md5, crc32: nil,
                displayName: game.title, platform: platform, discNumber: nil, revision: nil
            ))
        }
    }

    private func entry(forKey key: String) async -> (game: SharedGame, identity: ICubeWireGameIdentity)? {
        await entries().first { $0.identity.stableKey == key }
    }

    private func catalog() async -> ServerResponse {
        let catalog = ICubeWireCatalog(sourceDevice: WireSourceDevice(device), entries: await entries().map {
            ICubeWireCatalog.Entry(key: $0.identity.stableKey, game: $0.identity, sizeBytes: $0.game.sizeBytes, hasArtwork: $0.game.hasArtwork)
        })
        guard let data = try? iCubeEncoded(catalog) else { return .error(500, "catalog build failed") }
        return .json(data)
    }

    private func art(_ request: ServerRequest) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        guard let found = await entry(forKey: key), found.game.hasArtwork,
              let data = await library.artwork(forGameId: found.game.id) else {
            return .error(404, "no artwork for that entry")
        }
        return ServerResponse(status: 200, headers: ["Content-Type": "image/png"], body: .data(data))
    }

    /// `Software/<path>` per file; the primary first.
    static func layout(of game: SharedGame) -> [(String, SharedFile)] {
        game.files.map { ("\(softwareFolder)/\($0.relativePath)", $0) }
    }

    private func manifest(for key: String) async throws -> (game: SharedGame, manifest: ICubeWireManifest)? {
        guard let found = await entry(forKey: key) else { return nil }
        var files: [WireFileDescriptor] = []
        for (path, file) in Self.layout(of: found.game) {
            let sha = try await hashes.sha256(of: file.url)
            files.append(WireFileDescriptor(kind: RemoteFile.gameFileKind, relativePath: path, sha256: sha, size: file.size, required: true))
        }
        return (found.game, ICubeWireManifest(
            sessionId: key, mintedAt: Date(), sourceDevice: WireSourceDevice(device), game: found.identity, files: files
        ))
    }

    private func manifestRoute(_ request: ServerRequest) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        do {
            guard let built = try await manifest(for: key) else { return .error(404, "no such game") }
            return .json(try iCubeEncoded(built.manifest))
        } catch {
            return .error(500, "manifest encode failed: \(error)")
        }
    }

    private func file(_ request: ServerRequest, peer: (id: String, name: String)) async -> ServerResponse {
        guard let key = request.query[ContinuityRoutes.keyQueryItem], !key.isEmpty else { return .error(400, "missing ?key=") }
        guard let path = request.query[ContinuityRoutes.pathQueryItem], !path.isEmpty else { return .error(400, "missing ?path=") }
        guard let found = await entry(forKey: key) else { return .error(404, "no such game") }
        guard let file = Self.layout(of: found.game).first(where: { $0.0 == path })?.1 else {
            return .error(404, "not part of that game")
        }
        guard await approvePull(peer: peer, key: key, title: found.game.title) else {
            return .error(403, "the other device declined this copy")
        }
        guard FileManager.default.fileExists(atPath: file.url.path) else { return .error(404, "file unavailable") }
        return .file(file.url, size: file.size, rangeHeader: request.header("Range"))
    }

    /// iCube asks inside the file request and holds it open for the answer.
    private func approvePull(peer: (id: String, name: String), key: String, title: String) async -> Bool {
        switch await grant(for: peer.id) {
        case .denied: return false
        case .everything: return true
        case .askPerGame: break
        }
        let approvalKey = "\(peer.id)|\(key)"
        if approvedPulls.contains(approvalKey) { return true }
        let consent = await withApprovalTimeout(ConsentGate.approvalLifetime) { [approver] in
            await approver.approvePull(peerName: peer.name, gameTitle: title)
        } ?? .denyOnce
        switch consent {
        case .allowOnce:
            approvedPulls.insert(approvalKey)
            return true
        case .allowAlways:
            approvedPulls.insert(approvalKey)
            await trust.setGrant(.everything, forPeerId: peer.id)
            return true
        case .denyOnce:
            return false
        case .denyAlways:
            await trust.setGrant(.denied, forPeerId: peer.id)
            revoke(peerId: peer.id)
            return false
        }
    }
}
