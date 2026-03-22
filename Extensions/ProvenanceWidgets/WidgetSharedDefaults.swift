//
//  WidgetSharedDefaults.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation

// MARK: - Shared UserDefaults Keys

/// Keys used to share data between the main app and widget extension via App Groups.
/// The main app writes these values; widgets read them.
public enum WidgetSharedDefaults {
    static var appGroupID: String {
        Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
            ?? "group.org.provenance-emu.provenance"
    }

    public enum Keys {
        /// JSON-encoded array of `WidgetGameData` written by the host app; widgets decode this into `[WidgetGameEntry]` for recent games.
        static let recentGames = "widget.recentGames"
        /// JSON-encoded `WidgetNowPlayingData` written by the host app; widgets decode this into `WidgetNowPlayingEntry` for the currently-playing track.
        static let nowPlaying = "widget.nowPlaying"
        /// Total game count (Int).
        static let gameCount = "widget.gameCount"
        /// JSON-encoded array of `WidgetGameData` written by the host app; widgets decode this into `[WidgetGameEntry]` for the art gallery rotation.
        static let galleryGames = "widget.galleryGames"
        /// JSON-encoded array of `WidgetGameData` for favorite games, sorted by title.
        static let favoriteGames = "widget.favoriteGames"
        /// Total number of distinct systems in the library (Int).
        static let systemCount = "widget.systemCount"
        /// Aggregate play time across all games, in seconds (Int).
        static let totalPlayTime = "widget.totalPlayTime"
        /// Number of games marked as favorites (Int).
        static let favoritesCount = "widget.favoritesCount"
    }

    /// Returns the App Group `UserDefaults` suite, or `nil` if the suite is unavailable
    /// (e.g. missing entitlement). Callers show empty state when this is `nil` rather
    /// than falling back to `.standard`, which could mask configuration issues.
    static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

// MARK: - Data Models

/// Minimal game representation written by the main app and read by widgets.
public struct WidgetGameEntry: Codable, Identifiable {
    public let id: String
    public let title: String
    public let systemName: String
    /// Relative path inside the App Group container where box art is cached.
    public let artworkPath: String?
    public let lastPlayedDate: Date?

    // MARK: Not Codable — populated by timeline providers before passing to views.
    /// Raw artwork bytes loaded from `artworkPath` at timeline-provider time.
    /// Never nil-checks needed in views; just display `GameArtworkView(artworkData: entry.artworkData)`.
    public var artworkData: Data?

    // MARK: Derived helpers (not stored)

    /// The game's MD5 hash identifier — same as `id`.
    public var md5Hash: String { id }

    /// Abbreviated system name displayed in badges. Falls back to `systemName`.
    public var systemShortName: String { systemName }

    /// Deep-link URL for launching the game from a widget tap.
    public var launchURL: URL? {
        guard !id.isEmpty else { return nil }
        return URL(string: "provenance://open?md5=\(id)")
    }

    public init(
        id: String,
        title: String,
        systemName: String,
        artworkPath: String? = nil,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.systemName = systemName
        self.artworkPath = artworkPath
        self.lastPlayedDate = lastPlayedDate
        self.artworkData = nil
    }

    // MARK: Codable — exclude artworkData from JSON
    enum CodingKeys: String, CodingKey {
        case id, title, systemName, artworkPath, lastPlayedDate
    }
}

/// Library statistics written by the main app and read by the Library Stats widget.
public struct WidgetLibraryStats: Sendable {
    public let totalGames: Int
    public let totalSystems: Int
    public let totalPlayTimeSeconds: Int
    public let favoritesCount: Int

    public var totalPlayTimeFormatted: String {
        let hours = totalPlayTimeSeconds / 3600
        let minutes = (totalPlayTimeSeconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}

/// Now-playing track info written by the Music Player (#2654) and read by widgets.
public struct WidgetNowPlayingEntry: Codable {
    public let trackTitle: String
    public let artistName: String?
    public let albumTitle: String?
    /// Relative path inside the App Group container for cached album art.
    public let albumArtPath: String?
    public let timestamp: Date

    public init(
        trackTitle: String,
        artistName: String? = nil,
        albumTitle: String? = nil,
        albumArtPath: String? = nil
    ) {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.albumArtPath = albumArtPath
        self.timestamp = Date()
    }
}

// MARK: - Helpers

extension WidgetSharedDefaults {
    static func loadRecentGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.recentGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadGalleryGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.galleryGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadNowPlaying() -> WidgetNowPlayingEntry? {
        guard let data = shared?.data(forKey: Keys.nowPlaying) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetNowPlayingEntry.self, from: data)
    }

    static func loadGameCount() -> Int {
        shared?.integer(forKey: Keys.gameCount) ?? 0
    }

    /// Resolves a relative artwork path to a full URL inside the App Group container.
    static func artworkURL(forRelativePath path: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(path)
    }

    /// Loads raw image bytes for the given relative artwork path.
    /// Call this in a timeline provider (not in a view body) to avoid synchronous
    /// disk I/O during widget rendering.
    static func artworkData(forRelativePath path: String) -> Data? {
        guard let url = artworkURL(forRelativePath: path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Returns up to `limit` recently-played games with `artworkData` pre-loaded.
    /// Safe to call from a timeline provider; performs disk I/O at provider time so
    /// views never block on artwork reads during rendering.
    static func loadRecentGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        var games = Array(loadRecentGames().prefix(limit))
        for index in games.indices {
            if let path = games[index].artworkPath {
                games[index].artworkData = artworkData(forRelativePath: path)
            }
        }
        return games
    }

    /// Returns up to `limit` gallery games with `artworkData` pre-loaded.
    static func loadGalleryGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        var games = Array(loadGalleryGames().prefix(limit))
        for index in games.indices {
            if let path = games[index].artworkPath {
                games[index].artworkData = artworkData(forRelativePath: path)
            }
        }
        return games
    }

    static func loadFavoriteGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.favoriteGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadFavoriteGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        var games = Array(loadFavoriteGames().prefix(limit))
        for index in games.indices {
            if let path = games[index].artworkPath {
                games[index].artworkData = artworkData(forRelativePath: path)
            }
        }
        return games
    }

    static func loadLibraryStats() -> WidgetLibraryStats {
        guard let defaults = shared else {
            return WidgetLibraryStats(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0)
        }
        return WidgetLibraryStats(
            totalGames: defaults.integer(forKey: Keys.gameCount),
            totalSystems: defaults.integer(forKey: Keys.systemCount),
            totalPlayTimeSeconds: defaults.integer(forKey: Keys.totalPlayTime),
            favoritesCount: defaults.integer(forKey: Keys.favoritesCount)
        )
    }
}
#endif
