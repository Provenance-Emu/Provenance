//
//  PairingGate.swift
//  PVLibrarySharing
//
//  Code pairing as iCube's `ContinuityPairingServer` runs it, for the iCube
//  dialect and `_pvlibrary._tcp`.
//

import Foundation

/// `pair/start` and `pair/complete`:
///
/// - `start {peerId,name,publicKey}` → `{pairingId,serverId,serverName,serverPublicKey}`;
///   the owner sees a 6-digit code. At most 3 pairings in flight (429).
/// - `complete {pairingId,proof}`: 202 until the owner approves, 403
///   declined, 410 unknown/expired or out of tries, 401 wrong code. A right
///   code stores the trust, then answers `paired`: iCube's 404 "no active
///   handoff session", or `_pvlibrary`'s 200 `{"paired":true}`.
actor PairingGate {
    static let pairingLifetime: TimeInterval = 120
    static let maxProofAttempts = 3
    static let maxPendingPairings = 3

    private struct PendingPairing {
        let request: ICubePairStartRequest
        let code: String
        let expiresAt: Date
        var attemptsLeft: Int
        var approval: Bool?
    }

    private let identity: PeerIdentity
    private let device: HostDevice
    private let domain: ContinuityAuthDomain
    private let app: PeerApp
    private let trust: any HostTrustStore
    private let approver: any LibraryHostApproving
    private let paired: ServerResponse
    private var pairings: [String: PendingPairing] = [:]

    init(
        identity: PeerIdentity,
        device: HostDevice,
        domain: ContinuityAuthDomain,
        app: PeerApp,
        trust: any HostTrustStore,
        approver: any LibraryHostApproving,
        paired: ServerResponse
    ) {
        self.identity = identity
        self.device = device
        self.domain = domain
        self.app = app
        self.trust = trust
        self.approver = approver
        self.paired = paired
    }

    func reset() {
        pairings.removeAll()
    }

    func start(_ request: ServerRequest) -> ServerResponse {
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
            await self.resolve(pairingId, approved: approved)
        }
        return .encoded(ICubePairStartResponse(
            pairingId: pairingId, serverId: identity.id, serverName: device.name, serverPublicKey: identity.publicKeyData
        ))
    }

    private func resolve(_ pairingId: String, approved: Bool) {
        pairings[pairingId]?.approval = approved
    }

    func complete(_ request: ServerRequest) async -> ServerResponse {
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
            domain: domain, pairingId: body.pairingId, clientId: pending.request.peerId,
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
            id: pending.request.peerId, name: pending.request.name, publicKey: pending.request.publicKey, app: app.rawValue
        ))
        // A paired device browses without a consent prompt; "Ask per game" still guards copies.
        if await trust.grant(forPeerId: pending.request.peerId) == nil {
            await trust.setGrant(.askPerGame, forPeerId: pending.request.peerId)
        }
        return paired
    }
}
