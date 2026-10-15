//
//  PeerIdentityStore.swift
//  PVLibrarySharing
//
//  Custody of the pairing identity.
//

import Foundation
#if canImport(Security)
import Security
#endif

/// The persisted part of a `PeerIdentity`: id and private key. The display
/// name is supplied at load time, so a renamed device keeps its pairings.
public struct StoredPeerIdentity: Codable, Sendable, Equatable {
    public var id: String
    public var privateKey: Data

    public init(id: String, privateKey: Data) {
        self.id = id
        self.privateKey = privateKey
    }
}

/// Reads and writes the stored identity.
public protocol PeerIdentityStore: Sendable {
    func read() -> StoredPeerIdentity?
    /// Returns false when the identity could not be persisted.
    @discardableResult
    func write(_ identity: StoredPeerIdentity) -> Bool
}

public extension PeerIdentityStore {
    /// The persisted identity, or a new one that is persisted now.
    ///
    /// When the store can't be read or written (Keychain locked before first
    /// unlock, say) this returns a fresh, unpersisted identity. The device then
    /// shows up as a new peer and has to be approved or paired again, which is
    /// visible and honest; silently minting a new key each launch is not.
    func loadOrCreate(name: String) -> PeerIdentity {
        if let stored = read(),
           let restored = try? PeerIdentity(id: stored.id, name: name, privateKeyData: stored.privateKey) {
            return restored
        }
        let fresh = PeerIdentity(name: name)
        write(StoredPeerIdentity(id: fresh.id, privateKey: fresh.privateKeyData))
        return fresh
    }
}

/// In-memory store for tests and previews.
public final class InMemoryPeerIdentityStore: PeerIdentityStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: StoredPeerIdentity?

    public init(_ stored: StoredPeerIdentity? = nil) {
        self.stored = stored
    }

    public func read() -> StoredPeerIdentity? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    @discardableResult
    public func write(_ identity: StoredPeerIdentity) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        stored = identity
        return true
    }
}

#if canImport(Security)
/// Keychain-backed store: one generic-password item holding the JSON-encoded
/// `StoredPeerIdentity`.
///
/// The key lives in the Keychain, never in Documents: Documents is what the
/// upload server and Files expose, and a leaked signing key lets someone else
/// be this device to every peer that trusted it. Accessibility is
/// `AfterFirstUnlockThisDeviceOnly`, so a backup restored onto a second device
/// doesn't clone the identity.
///
/// `accessGroup` is optional. Pass the full `<TEAMID>.com.joemattiello.shared`
/// group to share one identity with iFly and iCube on the same device (spec
/// open question 5, opt-in); nil keeps it in the app's default group.
public struct KeychainPeerIdentityStore: PeerIdentityStore {
    public static let defaultService = "org.provenance-emu.library-sharing"
    public static let defaultAccount = "peer-identity"

    public let service: String
    public let account: String
    public let accessGroup: String?

    public init(
        service: String = KeychainPeerIdentityStore.defaultService,
        account: String = KeychainPeerIdentityStore.defaultAccount,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    public func read() -> StoredPeerIdentity? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredPeerIdentity.self, from: data)
    }

    @discardableResult
    public func write(_ identity: StoredPeerIdentity) -> Bool {
        guard let data = try? JSONEncoder().encode(identity) else { return false }
        SecItemDelete(baseQuery() as CFDictionary)
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
#endif
