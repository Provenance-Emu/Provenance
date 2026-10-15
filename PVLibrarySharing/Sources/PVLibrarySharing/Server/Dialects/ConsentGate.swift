//
//  ConsentGate.swift
//  PVLibrarySharing
//
//  Consent-first library auth, bearer tokens and per-game pull approval:
//  iFly's model, shared by the iFly dialect and `_pvlibrary` (spec §3.2).
//

import Foundation

/// Library bearer tokens, stored as SHA-256 digests and scoped to one peer.
struct TokenRegistry {
    private struct Issued {
        let peerId: String
        let peerName: String
        let expiresAt: Date
    }

    let lifetime: TimeInterval
    private var issued: [String: Issued] = [:]

    init(lifetime: TimeInterval) {
        self.lifetime = lifetime
    }

    var count: Int { issued.count }

    mutating func mint(peerId: String, peerName: String) -> String {
        let token = ServerTokens.mint()
        issued[ServerTokens.digest(token)] = Issued(peerId: peerId, peerName: peerName, expiresAt: Date().addingTimeInterval(lifetime))
        return token
    }

    /// The peer behind an `Authorization` header, or nil.
    mutating func peer(forAuthorization header: String?) -> (id: String, name: String)? {
        prune()
        guard let token = ServerTokens.bearer(header), let entry = issued[ServerTokens.digest(token)] else { return nil }
        return (entry.peerId, entry.peerName)
    }

    mutating func revoke(peerId: String) {
        issued = issued.filter { $0.value.peerId != peerId }
    }

    mutating func revokeAll() {
        issued.removeAll()
    }

    mutating func prune() {
        let now = Date()
        issued = issued.filter { $0.value.expiresAt > now }
    }
}

/// The body of a consent `auth/start`: iFly's `AuthStartRequest`.
struct ConsentAuthStart: Codable, Sendable {
    var peerId: String
    var name: String
    var publicKey: Data
    var icloudHash: String?
}

/// Consent auth as iFly's `ContinuityLibraryServer` runs it:
///
/// - `start` hands out a nonce (403 when the peer is denied).
/// - `complete` verifies the signature against the trusted key, or the
///   presented one for a stranger. A trusted peer with a grant gets a token
///   at once. A stranger fires one consent prompt and gets 202 until the
///   owner answers; "Share everything" and "Ask per game" trust the peer on
///   first use, "Don't share" denies it.
/// - `pullApproval` runs "Ask per game": 202 while the owner decides, 403 on
///   a refusal; one approval covers one pull.
actor ConsentGate {
    static let authLifetime: TimeInterval = 30
    static let approvalLifetime: TimeInterval = 120
    static let tokenLifetime: TimeInterval = 60 * 60

    private struct PendingAuth {
        let request: ConsentAuthStart
        let nonce: Data
        var expiresAt: Date
        var promptFired = false
        var decision: Decision = .undecided
    }

    private enum Decision: Equatable {
        case undecided
        case granted(LibraryGrant)
        case denied
    }

    private struct PendingPull {
        var expiresAt: Date
        var decision: Decision = .undecided
    }

    private let identity: PeerIdentity
    private let domain: ContinuityAuthDomain
    private let app: PeerApp
    private let trust: any HostTrustStore
    private let approver: any LibraryHostApproving
    private var pendingAuths: [String: PendingAuth] = [:]
    private var pendingPulls: [String: PendingPull] = [:]
    private var tokens = TokenRegistry(lifetime: ConsentGate.tokenLifetime)

    init(identity: PeerIdentity, domain: ContinuityAuthDomain, app: PeerApp, trust: any HostTrustStore, approver: any LibraryHostApproving) {
        self.identity = identity
        self.domain = domain
        self.app = app
        self.trust = trust
        self.approver = approver
    }

    func revokeAll() {
        pendingAuths.removeAll()
        pendingPulls.removeAll()
        tokens.revokeAll()
    }

    func revoke(peerId: String) {
        tokens.revoke(peerId: peerId)
        pendingAuths = pendingAuths.filter { $0.value.request.peerId != peerId }
    }

    /// The token's peer id, or nil (answer 401).
    func peer(forAuthorization header: String?) -> String? {
        tokens.peer(forAuthorization: header)?.id
    }

    // MARK: - Auth

    func start(_ request: ServerRequest) async -> ServerResponse {
        guard let body: ConsentAuthStart = decodeBody(request) else { return .error(400, "invalid library auth request") }
        if await trust.grant(forPeerId: body.peerId) == .denied {
            return .error(403, "library sharing declined for this device")
        }
        prune()
        let authId = UUID().uuidString
        let nonce = ServerTokens.nonce()
        pendingAuths[authId] = PendingAuth(request: body, nonce: nonce, expiresAt: Date().addingTimeInterval(Self.authLifetime))
        return .encoded(AuthStartResponse(authId: authId, serverId: identity.id, nonce: nonce))
    }

    func complete(_ request: ServerRequest) async -> ServerResponse {
        guard let body: AuthCompleteRequest = decodeBody(request) else { return .error(400, "invalid library auth completion") }
        prune()
        guard let pending = pendingAuths[body.authId], pending.expiresAt > Date(), pending.request.peerId == body.peerId else {
            pendingAuths[body.authId] = nil
            return .error(410, "library auth expired or unknown")
        }
        let trusted = await trust.peer(withId: body.peerId)
        let key = trusted?.publicKey ?? pending.request.publicKey
        guard ContinuityAuthMath.verifyAuth(
            domain: domain, signature: body.signature, nonce: pending.nonce,
            peerId: body.peerId, serverId: identity.id, publicKey: key
        ) else {
            pendingAuths[body.authId] = nil
            return .error(403, "signature verification failed")
        }
        let grant = await trust.grant(forPeerId: body.peerId)
        if grant == .denied {
            pendingAuths[body.authId] = nil
            return .error(403, "library sharing declined for this device")
        }
        if trusted != nil, grant == .everything || grant == .askPerGame {
            pendingAuths[body.authId] = nil
            return mint(pending.request)
        }
        return await consentRound(authId: body.authId, pending: pending, verifiedKey: key, alreadyTrusted: trusted != nil)
    }

    private func consentRound(authId: String, pending: PendingAuth, verifiedKey: Data, alreadyTrusted: Bool) async -> ServerResponse {
        var pending = pending
        if !pending.promptFired {
            pending.promptFired = true
            pending.expiresAt = Date().addingTimeInterval(Self.approvalLifetime)
            pendingAuths[authId] = pending
            let name = pending.request.name
            Task { [approver, app] in
                let consent = await withApprovalTimeout(Self.approvalLifetime) {
                    await approver.approveBrowse(peerName: name, app: app)
                } ?? .dontShare
                await self.resolveBrowse(authId: authId, consent: consent)
            }
            return .error(202, "waiting for approval on the other device")
        }
        let peerId = pending.request.peerId
        switch pending.decision {
        case .undecided:
            return .error(202, "waiting for approval on the other device")
        case .denied:
            pendingAuths[authId] = nil
            await trust.setGrant(.denied, forPeerId: peerId)
            return .error(403, "library sharing declined for this device")
        case .granted(let level):
            pendingAuths[authId] = nil
            await trust.setGrant(level, forPeerId: peerId)
            if !alreadyTrusted {
                await trust.add(TrustedPeer(id: peerId, name: pending.request.name, publicKey: verifiedKey, app: app.rawValue))
            }
            return mint(pending.request)
        }
    }

    private func resolveBrowse(authId: String, consent: BrowseConsent) {
        guard var pending = pendingAuths[authId] else { return }
        switch consent {
        case .shareEverything: pending.decision = .granted(.everything)
        case .askPerGame: pending.decision = .granted(.askPerGame)
        case .dontShare: pending.decision = .denied
        }
        pendingAuths[authId] = pending
    }

    private func mint(_ request: ConsentAuthStart) -> ServerResponse {
        .encoded(LibraryTokenResponse(libraryToken: tokens.mint(peerId: request.peerId, peerName: request.name)))
    }

    private func prune() {
        let now = Date()
        pendingAuths = pendingAuths.filter { $0.value.expiresAt > now }
        pendingPulls = pendingPulls.filter { $0.value.expiresAt > now }
        tokens.prune()
    }

    // MARK: - Ask per game

    /// nil = approved (or the peer's grant needs no approval).
    func pullApproval(peerId: String, gameId: String, gameTitle: String) async -> ServerResponse? {
        switch await trust.grant(forPeerId: peerId) {
        case .everything: return nil
        case .denied: return .error(403, "pull declined on the other device")
        case .askPerGame, nil: break
        }
        prune()
        let key = "\(peerId)|\(gameId)"
        if let pending = pendingPulls[key] {
            switch pending.decision {
            case .undecided:
                return .error(202, "waiting for approval on the other device")
            case .denied:
                pendingPulls[key] = nil
                return .error(403, "pull declined on the other device")
            case .granted:
                pendingPulls[key] = nil
                return nil
            }
        }
        let peerName = await trust.peer(withId: peerId)?.name ?? peerId
        pendingPulls[key] = PendingPull(expiresAt: Date().addingTimeInterval(Self.approvalLifetime))
        Task { [approver] in
            let consent = await withApprovalTimeout(Self.approvalLifetime) {
                await approver.approvePull(peerName: peerName, gameTitle: gameTitle)
            } ?? .denyOnce
            await self.resolvePull(key: key, peerId: peerId, consent: consent)
        }
        return .error(202, "waiting for approval on the other device")
    }

    private func resolvePull(key: String, peerId: String, consent: PullConsent) async {
        guard var pending = pendingPulls[key] else { return }
        switch consent {
        case .allowOnce:
            pending.decision = .granted(.askPerGame)
        case .allowAlways:
            pending.decision = .granted(.everything)
            await trust.setGrant(.everything, forPeerId: peerId)
        case .denyOnce:
            pending.decision = .denied
        case .denyAlways:
            pending.decision = .denied
            await trust.setGrant(.denied, forPeerId: peerId)
            tokens.revoke(peerId: peerId)
        }
        pendingPulls[key] = pending
    }
}

/// Decodes a request's JSON body, or nil.
func decodeBody<T: Decodable>(_ request: ServerRequest) -> T? {
    guard let body = request.body else { return nil }
    return try? JSONDecoder().decode(T.self, from: body)
}
