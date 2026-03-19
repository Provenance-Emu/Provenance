//
//  WidgetEntry.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation
import WidgetKit

/// Lightweight game representation for use in widget timeline entries.
/// Widgets are stateless — all data must be embedded in the entry at provider time.
struct WidgetGameEntry: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let md5Hash: String
    let systemIdentifier: String
    let systemShortName: String
    let artworkPath: String?
    let lastPlayedDate: Date?
    let isFavorite: Bool

    /// Deep link URL for launching the game in the main app.
    /// Returns nil for empty md5Hash (placeholder/padding entries).
    var launchURL: URL? {
        guard !md5Hash.isEmpty else { return nil }
        return URL(string: "provenance://open?md5=\(md5Hash)")
    }
}

// MARK: - Recently Played Entry

struct RecentlyPlayedEntry: TimelineEntry {
    let date: Date
    let games: [WidgetGameEntry]
    let isPlaceholder: Bool

    static var placeholder: RecentlyPlayedEntry {
        RecentlyPlayedEntry(date: Date(), games: [], isPlaceholder: true)
    }
}

// MARK: - Favorites Entry

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let games: [WidgetGameEntry]
    let isPlaceholder: Bool

    static var placeholder: FavoritesEntry {
        FavoritesEntry(date: Date(), games: [], isPlaceholder: true)
    }
}

// MARK: - Library Stats Entry

struct LibraryStatsData: Codable, Sendable {
    let totalGames: Int
    let totalSystems: Int
    let totalPlayTimeSeconds: Int
    let favoritesCount: Int

    var totalPlayTimeFormatted: String {
        let hours = totalPlayTimeSeconds / 3600
        let minutes = (totalPlayTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

struct LibraryStatsEntry: TimelineEntry {
    let date: Date
    let stats: LibraryStatsData
    let isPlaceholder: Bool

    static var placeholder: LibraryStatsEntry {
        LibraryStatsEntry(
            date: Date(),
            stats: LibraryStatsData(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0),
            isPlaceholder: true
        )
    }
}
#endif
