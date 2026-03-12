//
//  CloudKitGameMetadataUpdateQueue.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 1/8/26.
//

import Foundation
import PVLogging

/// Durable, coalescing queue for PVGame metadata updates that must be forwarded to CloudKit.
/// Stores MD5s only (idempotent) and retries until the update succeeds.
public actor CloudKitGameMetadataUpdateQueue {
    public static let shared = CloudKitGameMetadataUpdateQueue()

    private struct Storage: Codable, Sendable {
        var md5s: [String]
    }

    private let storageKey = "org.provenance.cloudsync.cloudkit.gameMetadata.pendingMD5s"
    private let userDefaults: UserDefaults

    private var pending: Set<String>
    private var isDraining: Bool = false

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.pending = []
        self.pending = Self.load(from: userDefaults, key: storageKey)
    }

    public func enqueue(md5: String) {
        let normalized = md5.uppercased()
        guard !normalized.isEmpty else { return }
        pending.insert(normalized)
        persist()
    }

    public func drain(using syncer: CloudKitRomsSyncer) async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        while !pending.isEmpty {
            if await MainActor.run(body: { CloudSyncManager.shared.isPausedForEmulation }) {
                return
            }

            let md5 = pending.first!
            do {
                _ = try await syncer.updateGameMetadata(md5: md5)
                pending.remove(md5)
                persist()
            } catch {
                WLOG("[SYNC] Metadata update queue failed for \(md5): \(error.localizedDescription)")
                return
            }
        }
    }

    private func persist() {
        let payload = Storage(md5s: pending.sorted())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func load(from userDefaults: UserDefaults, key: String) -> Set<String> {
        guard let data = userDefaults.data(forKey: key),
              let payload = try? JSONDecoder().decode(Storage.self, from: data)
        else {
            return []
        }
        return Set(payload.md5s.map { $0.uppercased() }.filter { !$0.isEmpty })
    }
}
