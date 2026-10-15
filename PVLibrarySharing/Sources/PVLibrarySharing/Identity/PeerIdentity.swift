//
//  PeerIdentity.swift
//  PVLibrarySharing
//
//  This install's long-term pairing identity.
//

import CryptoKit
import Foundation

/// A stable id, a display name and an Ed25519 signing key.
///
/// Peers remember the id and public key after consent (iFly) or pairing
/// (iCube), so both must survive relaunches: a fresh key on every launch
/// would look like pairing that never sticks.
public struct PeerIdentity: Sendable {
    public let id: String
    /// Shown on the host's consent or pairing prompt. Name Provenance in it
    /// ("Provenance on iPhone") so the owner knows which app is asking.
    public let name: String
    public let signingKey: Curve25519.Signing.PrivateKey

    /// 32-byte raw public key: what both peer apps expect on the wire.
    public var publicKeyData: Data { signingKey.publicKey.rawRepresentation }
    public var privateKeyData: Data { signingKey.rawRepresentation }

    /// A fresh identity.
    public init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
        self.signingKey = Curve25519.Signing.PrivateKey()
    }

    /// A restored identity.
    public init(id: String, name: String, privateKeyData: Data) throws {
        self.id = id
        self.name = name
        self.signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    }
}
