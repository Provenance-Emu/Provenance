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
// Re-exported so that host-app code importing PVAppIntents (e.g. PVUIBase's
// `WidgetDataWriter+Realm`) sees the snapshot models and bounds without needing
// a second import.
@_exported import PVLibrarySnapshot

#if canImport(WidgetKit)
import WidgetKit
#endif

#if os(tvOS) && canImport(TVServices)
import TVServices
#endif

// MARK: - Shared Data Models

/// Lightweight game info written by the main app and read by extensions.
///
/// The canonical declaration lives in `PVLibrarySnapshot` so that extensions
/// which cannot (or should not) link the whole of PVAppIntents still share one
/// definition. This alias preserves the existing call sites.
public typealias WidgetGameData = LibrarySnapshotGame

/// Resolves a single activity timestamp for `WidgetGameData.lastPlayedDate` from Realm fields that can diverge:
/// `PVRecentGame.lastPlayedDate` (updated when a session is queued) and `PVGame.lastPlayed` (session / play tracking).
public enum WidgetPlayActivityTimestamp {
    /// Returns the latest play-related timestamp, or `importDate` when neither play field is set.
    public static func best(recentLastPlayed: Date?, gameLastPlayed: Date?, importDate: Date) -> Date {
        [recentLastPlayed, gameLastPlayed].compactMap { $0 }.max() ?? importDate
    }
}

/// Now-playing track info written by Music Player (#2654) and read by extensions.
/// Canonical declaration lives in `PVLibrarySnapshot`.
public typealias WidgetNowPlayingData = LibrarySnapshotNowPlaying

// MARK: - Writer

/// Pushes library and now-playing data to the shared App Group so
/// the ProvenanceWidgets extension can render without Realm access.
public final class WidgetDataWriter: Sendable {
    public static let shared = WidgetDataWriter()

    /// Key strings are declared once in `LibrarySnapshotKeys`; never inline them here.
    private typealias Key = LibrarySnapshotKeys

    private var defaults: UserDefaults? { pvAppGroupDefaults }

    private init() {}

    // MARK: - Public API

    /// Write the current game library state to shared UserDefaults and reload widget timelines.
    /// - Parameters:
    ///   - recentGames: Recently-played games, ordered most-recent first (up to 12).
    ///   - galleryGames: Games chosen for art gallery rotation (up to 12).
    ///   - favoriteGames: Favorite games sorted by title (up to 16 — covers systemExtraLarge 4×4 grid).
    ///   - recentlyAddedGames: Games ordered by import date descending (up to 16). Top Shelf only.
    ///   - totalCount: Total number of games in the library.
    ///   - systemCount: Number of distinct systems in the library.
    ///   - totalPlayTimeSeconds: Aggregate play time across all games.
    ///   - favoritesCount: Number of favorite games.
    ///
    /// Writes are individually atomic (`UserDefaults` handles cross-process
    /// coordination for the App Group suite), so a reader never sees a torn
    /// JSON blob. It can briefly see one list from before this call and another
    /// from after; the lists are independent display sections, so that is
    /// harmless and cheaper than a coordinated single-file rewrite.
    public func writeGameData(
        recentGames: [WidgetGameData],
        galleryGames: [WidgetGameData],
        favoriteGames: [WidgetGameData] = [],
        recentlyAddedGames: [WidgetGameData] = [],
        totalCount: Int,
        systemCount: Int = 0,
        totalPlayTimeSeconds: Int = 0,
        favoritesCount: Int = 0
    ) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        func write(_ games: [WidgetGameData], limit: Int, key: String) {
            guard let data = try? encoder.encode(Array(games.prefix(limit))) else { return }
            defaults.set(data, forKey: key)
        }

        write(recentGames, limit: LibrarySnapshotSchema.maxGalleryGames, key: Key.recentGames)
        write(galleryGames, limit: LibrarySnapshotSchema.maxGalleryGames, key: Key.galleryGames)
        write(favoriteGames, limit: LibrarySnapshotSchema.maxFavoriteGames, key: Key.favoriteGames)
        write(recentlyAddedGames, limit: LibrarySnapshotSchema.maxRecentlyAddedGames, key: Key.recentlyAddedGames)

        defaults.set(totalCount, forKey: Key.gameCount)
        defaults.set(systemCount, forKey: Key.systemCount)
        defaults.set(totalPlayTimeSeconds, forKey: Key.totalPlayTime)
        defaults.set(favoritesCount, forKey: Key.favoritesCount)

        // Stamp version + freshness last, so a reader that observes the new
        // version has already been able to observe the new lists.
        defaults.set(LibrarySnapshotSchema.currentVersion, forKey: Key.schemaVersion)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)

        notifyExtensionsOfChange()
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

        notifyExtensionsOfChange()
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

    /// Tells snapshot consumers that the shared data changed.
    ///
    /// iOS: debounced `WidgetCenter.reloadAllTimelines()`.
    /// tvOS: `TVTopShelfContentProvider.topShelfContentDidChange()` — without
    /// this, Top Shelf keeps rendering the previous snapshot until the system
    /// happens to re-query the provider.
    private func notifyExtensionsOfChange() {
#if canImport(WidgetKit) && os(iOS)
        Task { await WidgetTimelineReloader.shared.requestReload() }
#endif
#if os(tvOS) && canImport(TVServices)
        TVTopShelfContentProvider.topShelfContentDidChange()
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
