//
//  WidgetSharedDefaults.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import Foundation
import PVLibrary

// MARK: - Shared UserDefaults Keys

/// Keys used to share data between the main app and widget extension via App Groups.
/// The main app writes these values; widgets read them.
///
/// **App Group ID note:** `appGroupID` here reads the `APP_GROUP_IDENTIFIER` build
/// setting from Info.plist at runtime (with fallback for dev/CI builds).  This is a
/// *necessary local copy* — the widget extension cannot import PVAppIntents.
/// Deep-link URL helpers use `PVLibrary` (`PVAppConstants`), which wraps primitives.

/// The canonical sources are:
///   - PVLibrary: `PVLibrary/Sources/PVFileSystem/Paths.swift` → `public let PVAppGroupId`
///   - PVAppIntents: `PVAppIntents/Sources/PVAppIntents/AppGroupID.swift` → `internal let pvAppGroupID`
/// All three must remain in sync with the `APP_GROUP_IDENTIFIER` build setting.
public enum WidgetSharedDefaults {
    static var appGroupID: String {
        let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
        guard let raw, !raw.isEmpty, !raw.contains("$(") else {
            return "group.org.provenance-emu.provenance"
        }
        return raw
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
    /// Reverse-DNS system id (e.g. `com.provenance.snes`) when present in shared JSON; drives per-system SF Symbols in widgets.
    public let systemIdentifier: String?
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
        return URL(string: PVOpenGameMD5URI(id))
    }

    public init(
        id: String,
        title: String,
        systemName: String,
        systemIdentifier: String? = nil,
        artworkPath: String? = nil,
        lastPlayedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.artworkPath = artworkPath
        self.lastPlayedDate = lastPlayedDate
        self.artworkData = nil
    }

    // MARK: Codable — exclude artworkData from JSON
    enum CodingKeys: String, CodingKey {
        case id, title, systemName, systemIdentifier, artworkPath, lastPlayedDate
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
        if hours > 0 {
            let format = NSLocalizedString(
                "widget.common.playtime-hours-minutes %lld %lld",
                bundle: .main,
                comment: "Library Stats total play time formatted as hours and minutes"
            )
            return String(format: format, locale: Locale.current, hours, minutes)
        }
        if minutes > 0 {
            let format = NSLocalizedString(
                "widget.common.playtime-minutes %lld",
                bundle: .main,
                comment: "Library Stats total play time formatted as minutes only"
            )
            return String(format: format, locale: Locale.current, minutes)
        }
        return String(
            localized: "widget.common.playtime-under-one-minute",
            defaultValue: "<1m",
            comment: "Library Stats total play time under one minute"
        )
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
    ///
    /// Returns `nil` — without blocking — when the file is an iCloud ubiquity
    /// placeholder that has not yet been downloaded locally.  Views will show the
    /// `GameArtworkView` placeholder until the next widget timeline refresh after
    /// the file is available.
    ///
    /// Call this in a timeline provider (not in a view body) to keep disk I/O
    /// out of the rendering path.
    static func artworkData(forRelativePath path: String) -> Data? {
        guard let url = artworkURL(forRelativePath: path) else { return nil }
        // Skip iCloud placeholder files that would block waiting for a network download.
        if url.isUbiquitousPlaceholder { return nil }
        return try? Data(contentsOf: url)
    }

    /// Returns up to `limit` recently-played games with `artworkData` pre-loaded.
    static func loadRecentGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        loadGames(loadRecentGames(), limit: limit)
    }

    /// Returns up to `limit` gallery games with `artworkData` pre-loaded.
    static func loadGalleryGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        loadGames(loadGalleryGames(), limit: limit)
    }

    static func loadFavoriteGames() -> [WidgetGameEntry] {
        guard let data = shared?.data(forKey: Keys.favoriteGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadFavoriteGamesWithArtwork(limit: Int = 12) -> [WidgetGameEntry] {
        loadGames(loadFavoriteGames(), limit: limit)
    }

    // MARK: - Private

    /// Truncates `games` to `limit` entries and pre-populates `artworkData` from disk.
    private static func loadGames(_ games: [WidgetGameEntry], limit: Int) -> [WidgetGameEntry] {
        var result = Array(games.prefix(limit))
        for index in result.indices {
            if let path = result[index].artworkPath {
                result[index].artworkData = artworkData(forRelativePath: path)
            }
        }
        return result
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

// MARK: - URL iCloud helpers

private extension URL {
    /// `true` when the URL points to an iCloud ubiquity item that has not yet been
    /// downloaded to this device.  Reading such a URL would trigger a blocking network
    /// fetch, so callers should treat it as absent and wait for the next refresh.
    var isUbiquitousPlaceholder: Bool {
        guard (try? resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true else {
            return false
        }
        let status = (try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            .ubiquitousItemDownloadingStatus) ?? .notDownloaded
        return status != .current
    }
}
#endif
