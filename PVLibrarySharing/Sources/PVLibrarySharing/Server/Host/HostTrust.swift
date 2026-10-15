//
//  HostTrust.swift
//  PVLibrarySharing
//
//  Who may browse this library, and how (spec §3.6, "Trust model").
//

import Foundation

/// A device the owner has let in, by consent (iFly dialect, `_pvlibrary`) or
/// by pairing code (iCube dialect).
public struct TrustedPeer: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var name: String
    /// Raw 32-byte Ed25519 key. A known id can never swap keys.
    public var publicKey: Data
    /// The dialect it arrived on, for the Trusted Devices list.
    public var app: String
    public var addedAt: Date

    public init(id: String, name: String, publicKey: Data, app: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.publicKey = publicKey
        self.app = app
        self.addedAt = addedAt
    }
}

/// What a trusted peer may do. `askPerGame` is the default (iCube's).
public enum LibraryGrant: String, Sendable, Codable, CaseIterable {
    case everything
    case askPerGame
    case denied
}

/// The owner's answer to "X wants to browse your library" (iFly's three choices).
public enum BrowseConsent: Sendable, Equatable {
    case shareEverything
    case askPerGame
    case dontShare
}

/// The owner's answer to "X wants to copy <game>".
public enum PullConsent: Sendable, Equatable {
    case allowOnce
    case allowAlways
    case denyOnce
    case denyAlways
}

/// The prompts the owner answers on this device. The app shows them; a prompt
/// nobody answers within the dialect's window counts as a refusal.
public protocol LibraryHostApproving: Sendable {
    func approveBrowse(peerName: String, app: PeerApp) async -> BrowseConsent
    /// Shows `code` and asks whether to pair (iCube dialect).
    func approvePairing(peerName: String, code: String) async -> Bool
    func approvePull(peerName: String, gameTitle: String) async -> PullConsent
}

/// Trusted peers and their grants.
public protocol HostTrustStore: Sendable {
    func peer(withId id: String) async -> TrustedPeer?
    func allPeers() async -> [TrustedPeer]
    func add(_ peer: TrustedPeer) async
    /// Forgets the peer and its grant.
    func remove(peerId: String) async
    /// nil when never set; the dialect applies its default.
    func grant(forPeerId id: String) async -> LibraryGrant?
    func setGrant(_ grant: LibraryGrant, forPeerId id: String) async
}

/// A JSON-file trust store (or in memory when `fileURL` is nil). Holds only
/// public keys, so Application Support is the right home, not the Keychain.
public actor FileHostTrustStore: HostTrustStore {
    private struct Snapshot: Codable {
        var peers: [String: TrustedPeer] = [:]
        var grants: [String: LibraryGrant] = [:]
    }

    private let fileURL: URL?
    private var snapshot = Snapshot()
    private var loaded = false

    public init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    public func peer(withId id: String) -> TrustedPeer? {
        load()
        return snapshot.peers[id]
    }

    public func allPeers() -> [TrustedPeer] {
        load()
        return snapshot.peers.values.sorted { $0.addedAt < $1.addedAt }
    }

    public func add(_ peer: TrustedPeer) {
        load()
        // Never let a known id swap keys by re-adding itself.
        if let existing = snapshot.peers[peer.id], existing.publicKey != peer.publicKey { return }
        snapshot.peers[peer.id] = peer
        save()
    }

    public func remove(peerId: String) {
        load()
        snapshot.peers[peerId] = nil
        snapshot.grants[peerId] = nil
        save()
    }

    public func grant(forPeerId id: String) -> LibraryGrant? {
        load()
        return snapshot.grants[id]
    }

    public func setGrant(_ grant: LibraryGrant, forPeerId id: String) {
        load()
        snapshot.grants[id] = grant
        save()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        snapshot = stored
    }

    private func save() {
        guard let fileURL else { return }
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }
}

/// Races `body` against a timeout; nil when the timeout wins.
///
/// Returns at the deadline even when `body` never finishes. A task group
/// would wait for every child, and an approval prompt waiting on a
/// continuation can't be cancelled, so the race resumes a continuation
/// exactly once and leaves the loser to finish (its answer is dropped).
func withApprovalTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    _ body: @escaping @Sendable () async -> T
) async -> T? {
    await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        let once = ResumeOnce(continuation)
        Task { once.resume(await body()) }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            once.resume(nil)
        }
    }
}

/// Resumes a continuation the first time only.
final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        let pending = lock.withLock { () -> CheckedContinuation<T, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: value)
    }
}
