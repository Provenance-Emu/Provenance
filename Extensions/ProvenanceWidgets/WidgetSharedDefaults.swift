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
    static let appGroupID = "group.org.provenance-emu.provenance"

    public enum Keys {
        /// JSON-encoded array of `WidgetGameEntry` for recent games.
        static let recentGames = "widget.recentGames"
        /// JSON-encoded `WidgetNowPlayingEntry` for the currently-playing Music track.
        static let nowPlaying = "widget.nowPlaying"
        /// Total game count (Int).
        static let gameCount = "widget.gameCount"
        /// JSON-encoded array of `WidgetGameEntry` for the art gallery rotation.
        static let galleryGames = "widget.galleryGames"
    }

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
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
        guard let data = shared.data(forKey: Keys.recentGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadGalleryGames() -> [WidgetGameEntry] {
        guard let data = shared.data(forKey: Keys.galleryGames) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WidgetGameEntry].self, from: data)) ?? []
    }

    static func loadNowPlaying() -> WidgetNowPlayingEntry? {
        guard let data = shared.data(forKey: Keys.nowPlaying) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetNowPlayingEntry.self, from: data)
    }

    static func loadGameCount() -> Int {
        shared.integer(forKey: Keys.gameCount)
    }

    /// Resolves a relative artwork path to a full URL inside the App Group container.
    static func artworkURL(forRelativePath path: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(path)
    }
}
#endif
