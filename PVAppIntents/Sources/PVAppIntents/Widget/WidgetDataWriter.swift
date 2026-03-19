//
//  WidgetDataWriter.swift
//  PVAppIntents
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

//  Writes game and now-playing data to the shared App Group UserDefaults so
//  the ProvenanceWidgets extension can read it without depending on Realm.
//
//  The host app should call `WidgetDataWriter.shared.writeGameData(...)` after
//  any library change (game added/removed, recently-played updated, etc.) and
//  `WidgetDataWriter.shared.writeNowPlaying(...)` when the Music Player
//  track changes (Part of #2654).
//
//  On iOS the writer also calls `WidgetCenter.reloadAllTimelines()` so widgets
//  refresh immediately.

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Shared Data Models

/// Lightweight game info written by the main app and read by the widget extension.
/// Must remain Codable-compatible with `WidgetGameEntry` in the widget target.
public struct WidgetGameData: Codable, Sendable {
    public let id: String
    public let title: String
    public let systemName: String
    /// Path relative to the App Group container root where artwork is cached.
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

/// Now-playing track info written by Music Player (#2654) and read by the widget extension.
/// Must remain Codable-compatible with `WidgetNowPlayingEntry` in the widget target.
public struct WidgetNowPlayingData: Codable, Sendable {
    public let trackTitle: String
    public let artistName: String?
    public let albumTitle: String?
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

// MARK: - Writer

/// Pushes library and now-playing data to the shared App Group so
/// the ProvenanceWidgets extension can render without Realm access.
public final class WidgetDataWriter: @unchecked Sendable {
    public static let shared = WidgetDataWriter()

    private let appGroupID = "group.org.provenance-emu.provenance"

    // Keys must match `WidgetSharedDefaults.Keys` in the widget extension.
    private enum Key {
        static let recentGames = "widget.recentGames"
        static let nowPlaying = "widget.nowPlaying"
        static let gameCount = "widget.gameCount"
        static let galleryGames = "widget.galleryGames"
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - Public API

    /// Write the current game library state to shared UserDefaults and reload widget timelines.
    /// - Parameters:
    ///   - recentGames: Recently-played games, ordered most-recent first (up to 12).
    ///   - galleryGames: Games chosen for art gallery rotation (up to 12).
    ///   - totalCount: Total number of games in the library.
    public func writeGameData(
        recentGames: [WidgetGameData],
        galleryGames: [WidgetGameData],
        totalCount: Int
    ) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(Array(recentGames.prefix(12))) {
            defaults.set(data, forKey: Key.recentGames)
        }
        if let data = try? encoder.encode(Array(galleryGames.prefix(12))) {
            defaults.set(data, forKey: Key.galleryGames)
        }
        defaults.set(totalCount, forKey: Key.gameCount)

        reloadWidgetTimelines()
    }

    /// Write the current now-playing track info to shared UserDefaults and reload widget timelines.
    /// Call with `nil` when playback stops.
    public func writeNowPlaying(_ nowPlaying: WidgetNowPlayingData?) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let nowPlaying, let data = try? encoder.encode(nowPlaying) {
            defaults.set(data, forKey: Key.nowPlaying)
        } else {
            defaults.removeObject(forKey: Key.nowPlaying)
        }

        reloadWidgetTimelines()
    }

    // MARK: - Convenience: bridge from GameEntity

#if canImport(AppIntents)
    /// Bridge from `GameEntity` to `WidgetGameData`.
    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
    public func writeFromEntityStore(totalCount: Int) {
        let store = GameEntityStore.shared
        let recents = store.recentEntities(limit: 12).map { $0.asWidgetGameData }
        // Gallery uses all games in random order, capped at 12
        let gallery = store.allEntities().shuffled().prefix(12).map { $0.asWidgetGameData }
        writeGameData(recentGames: recents, galleryGames: Array(gallery), totalCount: totalCount)
    }
#endif

    // MARK: - Private

    private func reloadWidgetTimelines() {
#if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }
}

// MARK: - GameEntity + WidgetGameData Bridge

#if canImport(AppIntents)
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
private extension GameEntity {
    var asWidgetGameData: WidgetGameData {
        WidgetGameData(
            id: id,
            title: title,
            systemName: systemName,
            artworkPath: artworkURL.flatMap { Self.relativePath(for: $0) },
            lastPlayedDate: lastPlayedDate
        )
    }

    /// Converts an artwork URL to a path relative to the App Group container.
    static func relativePath(for url: URL) -> String? {
        let groupID = "group.org.provenance-emu.provenance"
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) else { return nil }
        let containerPath = containerURL.path
        let urlPath = url.path
        guard urlPath.hasPrefix(containerPath) else { return nil }
        return String(urlPath.dropFirst(containerPath.count + 1))
    }
}
#endif
