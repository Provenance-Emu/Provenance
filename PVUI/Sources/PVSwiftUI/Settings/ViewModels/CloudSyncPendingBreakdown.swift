//
//  CloudSyncPendingBreakdown.swift
//  PVUI
//
//  Files still to sync, per content type, for the Cloud Sync progress card.
//

import Foundation

/// One content type and how many of its files are still to sync.
struct CloudSyncPendingItem: Equatable, Identifiable {
    let label: String
    let count: Int
    var id: String { label }
}

enum CloudSyncPendingBreakdown {
    /// Content types in display order, with the syncer directory names that belong to each
    /// (CloudKit and iCloud Drive syncers name some folders differently).
    static let kinds: [(label: String, directories: Set<String>)] = [
        ("ROMs", ["ROMs"]),
        ("Save States", ["Saves", "Save States"]),
        ("BIOS", ["BIOS", "System"]),
        ("Battery Saves", ["Battery States"]),
        ("Screenshots", ["Screenshots"]),
        ("Skins", ["DeltaSkins"])
    ]

    /// Sums each syncer's pending files under its content type. Types with nothing pending are left out;
    /// a syncer whose folders match no known type is listed under its folder names, after the known types.
    static func items(from syncers: [(directories: Set<String>, pending: Int)]) -> [CloudSyncPendingItem] {
        var order = kinds.map(\.label)
        var counts: [String: Int] = [:]
        for syncer in syncers where syncer.pending > 0 {
            let label = kinds.first { !$0.directories.isDisjoint(with: syncer.directories) }?.label
                ?? syncer.directories.sorted().joined(separator: ", ")
            if !order.contains(label) { order.append(label) }
            counts[label, default: 0] += syncer.pending
        }
        return order.compactMap { label in counts[label].map { CloudSyncPendingItem(label: label, count: $0) } }
    }
}
