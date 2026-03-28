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
    /// Reverse-DNS system id (e.g. `com.provenance.snes`) when known; used by widgets for per-system glyphs.
    public let systemIdentifier: String?
    /// Path relative to the App Group container root where artwork is cached.
    public let artworkPath: String?
    public let lastPlayedDate: Date?

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
    }
}

/// Resolves a single activity timestamp for `WidgetGameData.lastPlayedDate` from Realm fields that can diverge:
/// `PVRecentGame.lastPlayedDate` (updated when a session is queued) and `PVGame.lastPlayed` (session / play tracking).
public enum WidgetPlayActivityTimestamp {
    /// Returns the latest play-related timestamp, or `importDate` when neither play field is set.
    public static func best(recentLastPlayed: Date?, gameLastPlayed: Date?, importDate: Date) -> Date {
        [recentLastPlayed, gameLastPlayed].compactMap { $0 }.max() ?? importDate
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
public final class WidgetDataWriter: Sendable {
    public static let shared = WidgetDataWriter()

    // Keys must match `WidgetSharedDefaults.Keys` in the widget extension.
    private enum Key {
        static let recentGames = "widget.recentGames"
        static let nowPlaying = "widget.nowPlaying"
        static let gameCount = "widget.gameCount"
        static let galleryGames = "widget.galleryGames"
        static let favoriteGames = "widget.favoriteGames"
        static let systemCount = "widget.systemCount"
        static let totalPlayTime = "widget.totalPlayTime"
        static let favoritesCount = "widget.favoritesCount"
    }

    private var defaults: UserDefaults? { pvAppGroupDefaults }

    private init() {}

    // MARK: - Public API

    /// Write the current game library state to shared UserDefaults and reload widget timelines.
    /// - Parameters:
    ///   - recentGames: Recently-played games, ordered most-recent first (up to 12).
    ///   - galleryGames: Games chosen for art gallery rotation (up to 12).
    ///   - favoriteGames: Favorite games sorted by title (up to 16 — covers systemExtraLarge 4×4 grid).
    ///   - totalCount: Total number of games in the library.
    ///   - systemCount: Number of distinct systems in the library.
    ///   - totalPlayTimeSeconds: Aggregate play time across all games.
    ///   - favoritesCount: Number of favorite games.
    public func writeGameData(
        recentGames: [WidgetGameData],
        galleryGames: [WidgetGameData],
        favoriteGames: [WidgetGameData] = [],
        totalCount: Int,
        systemCount: Int = 0,
        totalPlayTimeSeconds: Int = 0,
        favoritesCount: Int = 0
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
        if let data = try? encoder.encode(Array(favoriteGames.prefix(16))) {
            defaults.set(data, forKey: Key.favoriteGames)
        }
        defaults.set(totalCount, forKey: Key.gameCount)
        defaults.set(systemCount, forKey: Key.systemCount)
        defaults.set(totalPlayTimeSeconds, forKey: Key.totalPlayTime)
        defaults.set(favoritesCount, forKey: Key.favoritesCount)

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
        // Take a single snapshot so recents and gallery are derived from a consistent store state.
        let all = store.allEntities()

        // Derive recents: sort snapshot by last-played date descending.
        let recents = all
            .sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
            .prefix(12)
            .map { $0.asWidgetGameData }

        // Gallery: sample up to 12 random games from the same snapshot (no intra-gallery duplicates; may overlap with recents).
        let gallery = all.shuffled().prefix(12).map { $0.asWidgetGameData }

        writeGameData(recentGames: recents, galleryGames: gallery, totalCount: totalCount)
    }
#endif

    // MARK: - Private

    private func reloadWidgetTimelines() {
#if canImport(WidgetKit) && os(iOS)
        Task { await WidgetTimelineReloader.shared.requestReload() }
#endif
    }
}

// MARK: - Debounced Timeline Reloader

#if canImport(WidgetKit) && os(iOS)
/// Debounces `WidgetCenter.reloadAllTimelines()` calls so rapid sequential writes
/// (e.g., batch imports) only trigger a single reload after a short settling delay.
private actor WidgetTimelineReloader {
    static let shared = WidgetTimelineReloader()

    private var isScheduled = false
    private let debounceInterval: TimeInterval = 2

    func requestReload() {
        guard !isScheduled else { return }
        isScheduled = true

        Task { [debounceInterval] in
            let delay = UInt64(debounceInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            await self.reset()
        }
    }

    private func reset() {
        isScheduled = false
    }
}
#endif

// MARK: - GameEntity + WidgetGameData Bridge

#if canImport(AppIntents)
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
private extension GameEntity {
    var asWidgetGameData: WidgetGameData {
        WidgetGameData(
            id: id,
            title: title,
            systemName: systemName,
            systemIdentifier: systemIdentifier.isEmpty ? nil : systemIdentifier,
            artworkPath: artworkURL.flatMap { Self.relativePath(for: $0) },
            lastPlayedDate: lastPlayedDate
        )
    }

    /// Converts an artwork URL to a path relative to the App Group container.
    static func relativePath(for url: URL) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: pvAppGroupID
        ) else { return nil }
        let containerPath = containerURL.path
        let urlPath = url.path
        guard urlPath.hasPrefix(containerPath) else { return nil }
        return String(urlPath.dropFirst(containerPath.count + 1))
    }
}
#endif
