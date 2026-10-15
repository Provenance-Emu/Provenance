//
//  ContinuityAuthMath.swift
//  PVLibrarySharing
//
//  The byte transcripts each peer app signs or MACs. Pure and side-effect
//  free so tests can pin every byte.
//

import CryptoKit
import Foundation

/// The domain a transcript is bound to. Each app uses its own prefix, so a
/// signature made for iFly never verifies on iCube and vice versa.
public enum ContinuityAuthDomain: String, Sendable, CaseIterable {
    case iFly = "ifly-continuity"
    case iCube = "icube-continuity"

    /// `"<domain>-auth-v1|"`: prefix of the library-auth message.
    public var authPrefix: String { "\(rawValue)-auth-v1|" }
    /// `"<domain>-pair-v1|"`: prefix of the pairing transcript.
    public var pairPrefix: String { "\(rawValue)-pair-v1|" }
}

/// Transcript and proof construction, matching `ContinuityPairingMath` in
/// iFly's ContinuityKit and iCube's PVContinuity byte for byte.
public enum ContinuityAuthMath {

    /// `prefix + "peerId|serverId|" + nonce`: what a client signs with its
    /// Ed25519 key to finish `library/auth/complete`.
    public static func authMessage(domain: ContinuityAuthDomain, nonce: Data, peerId: String, serverId: String) -> Data {
        var message = Data(domain.authPrefix.utf8)
        message += Data("\(peerId)|\(serverId)|".utf8)
        message += nonce
        return message
    }

    public static func signAuth(
        domain: ContinuityAuthDomain,
        nonce: Data,
        peerId: String,
        serverId: String,
        signingKey: Curve25519.Signing.PrivateKey
    ) throws -> Data {
        try signingKey.signature(for: authMessage(domain: domain, nonce: nonce, peerId: peerId, serverId: serverId))
    }

    /// `prefix + "pairingId|clientId|serverId|" + clientKey + "|" + serverKey`:
    /// the transcript an iCube pairing proof is bound to.
    public static func pairingTranscript(
        domain: ContinuityAuthDomain,
        pairingId: String,
        clientId: String,
        serverId: String,
        clientPublicKey: Data,
        serverPublicKey: Data
    ) -> Data {
        var transcript = Data(domain.pairPrefix.utf8)
        transcript += Data("\(pairingId)|\(clientId)|\(serverId)|".utf8)
        transcript += clientPublicKey
        transcript += Data("|".utf8)
        transcript += serverPublicKey
        return transcript
    }

    /// HMAC-SHA256 over `transcript`, keyed on SHA-256 of the 6-digit code.
    public static func pairingProof(code: String, transcript: Data) -> Data {
        let key = SymmetricKey(data: Data(SHA256.hash(data: Data(code.utf8))))
        return Data(HMAC<SHA256>.authenticationCode(for: transcript, using: key))
    }

    // MARK: - Server side

    /// True when `signature` is `publicKey`'s Ed25519 signature over the
    /// domain's auth message.
    public static func verifyAuth(
        domain: ContinuityAuthDomain,
        signature: Data,
        nonce: Data,
        peerId: String,
        serverId: String,
        publicKey: Data
    ) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else { return false }
        return key.isValidSignature(signature, for: authMessage(domain: domain, nonce: nonce, peerId: peerId, serverId: serverId))
    }

    /// Constant-time check of a pairing proof.
    public static func verifyPairingProof(_ proof: Data, code: String, transcript: Data) -> Bool {
        let key = SymmetricKey(data: Data(SHA256.hash(data: Data(code.utf8))))
        return HMAC<SHA256>.isValidAuthenticationCode(proof, authenticating: transcript, using: key)
    }
}
