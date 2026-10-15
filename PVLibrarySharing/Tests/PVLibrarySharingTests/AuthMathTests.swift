//
//  AuthMathTests.swift
//  PVLibrarySharingTests
//

import CryptoKit
import XCTest
@testable import PVLibrarySharing

final class AuthMathTests: XCTestCase {
    private let nonce = Data([0x00, 0x01, 0x7F, 0xFF])

    func testIFlyAuthTranscriptBytes() {
        let message = ContinuityAuthMath.authMessage(domain: .iFly, nonce: nonce, peerId: "peer-1", serverId: "server-9")
        XCTAssertEqual(message, Data("ifly-continuity-auth-v1|peer-1|server-9|".utf8) + nonce)
    }

    func testICubeAuthTranscriptBytes() {
        let message = ContinuityAuthMath.authMessage(domain: .iCube, nonce: nonce, peerId: "peer-1", serverId: "server-9")
        XCTAssertEqual(message, Data("icube-continuity-auth-v1|peer-1|server-9|".utf8) + nonce)
    }

    func testPrefixes() {
        XCTAssertEqual(ContinuityAuthDomain.iFly.authPrefix, "ifly-continuity-auth-v1|")
        XCTAssertEqual(ContinuityAuthDomain.iCube.authPrefix, "icube-continuity-auth-v1|")
        XCTAssertEqual(ContinuityAuthDomain.iFly.pairPrefix, "ifly-continuity-pair-v1|")
        XCTAssertEqual(ContinuityAuthDomain.iCube.pairPrefix, "icube-continuity-pair-v1|")
        XCTAssertEqual(PeerApp.iFly.authDomain, .iFly)
        XCTAssertEqual(PeerApp.iCube.authDomain, .iCube)
    }

    /// Ed25519 signatures are randomised, so verify rather than compare bytes.
    /// A signature for one app must not verify as the other's.
    func testSignatureVerifiesOnlyInItsOwnDomain() throws {
        let identity = PeerIdentity(id: "peer-1", name: "Provenance on Test")
        let signature = try ContinuityAuthMath.signAuth(
            domain: .iFly, nonce: nonce, peerId: identity.id, serverId: "server-9", signingKey: identity.signingKey
        )
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: identity.publicKeyData)
        XCTAssertTrue(publicKey.isValidSignature(
            signature, for: Data("ifly-continuity-auth-v1|peer-1|server-9|".utf8) + nonce
        ))
        XCTAssertFalse(publicKey.isValidSignature(
            signature, for: Data("icube-continuity-auth-v1|peer-1|server-9|".utf8) + nonce
        ))
    }

    func testPairingTranscriptBytes() {
        let clientKey = Data(0..<32)
        let serverKey = Data(32..<64)
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .iCube, pairingId: "pair-1", clientId: "client-1", serverId: "server-1",
            clientPublicKey: clientKey, serverPublicKey: serverKey
        )
        var expected = Data("icube-continuity-pair-v1|pair-1|client-1|server-1|".utf8)
        expected += clientKey
        expected += Data("|".utf8)
        expected += serverKey
        XCTAssertEqual(transcript, expected)
    }

    /// Expected value computed independently with Python's hmac/hashlib:
    /// HMAC-SHA256(key: SHA256("123456"), msg: the transcript above).
    func testPairingProofMatchesIndependentHMAC() {
        let transcript = ContinuityAuthMath.pairingTranscript(
            domain: .iCube, pairingId: "pair-1", clientId: "client-1", serverId: "server-1",
            clientPublicKey: Data(0..<32), serverPublicKey: Data(32..<64)
        )
        let proof = ContinuityAuthMath.pairingProof(code: "123456", transcript: transcript)
        XCTAssertEqual(proof.map { String(format: "%02x", $0) }.joined(),
                       "e3f305f669957416df4301f9000d7124c60752d2e46168cd61ec7a738c67f3ca")
    }

    func testIdentityStoreKeepsIdAndKeyAcrossLoads() {
        let store = InMemoryPeerIdentityStore()
        let first = store.loadOrCreate(name: "Provenance on iPhone")
        let second = store.loadOrCreate(name: "Provenance on Renamed iPhone")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.publicKeyData, second.publicKeyData)
        XCTAssertEqual(second.name, "Provenance on Renamed iPhone")
        XCTAssertEqual(first.publicKeyData.count, 32)
    }
}
