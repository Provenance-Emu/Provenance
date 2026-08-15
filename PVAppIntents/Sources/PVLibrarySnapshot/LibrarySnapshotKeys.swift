//
//  LibrarySnapshotKeys.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// Canonical App Group `UserDefaults` keys for the library snapshot.
///
/// This is the **single source of truth** for the key strings. Writers
/// (`WidgetDataWriter` in PVAppIntents) and readers (`LibrarySnapshotReader`,
/// the widget extension's `WidgetSharedDefaults`) must reference these
/// constants rather than re-declaring literals.
///
/// The `widget.` prefix is historical — the snapshot now serves Top Shelf as
/// well as WidgetKit. Renaming the keys would orphan data written by an
/// already-installed build, so the prefix is deliberately preserved.
public enum LibrarySnapshotKeys {
    /// Schema version of the data currently in the suite (`Int`).
    /// Absent for data written by builds predating versioning — treated as `0`.
    public static let schemaVersion = "widget.schemaVersion"
    /// Time the snapshot was last written, as seconds since 1970 (`Double`).
    public static let updatedAt = "widget.updatedAt"

    /// JSON array of `LibrarySnapshotGame`, most-recently-played first.
    public static let recentGames = "widget.recentGames"
    /// JSON array of `LibrarySnapshotGame` sampled for art-rotation display.
    public static let galleryGames = "widget.galleryGames"
    /// JSON array of `LibrarySnapshotGame` marked favorite, sorted by title.
    public static let favoriteGames = "widget.favoriteGames"
    /// JSON array of `LibrarySnapshotGame`, most-recently-imported first.
    public static let recentlyAddedGames = "widget.recentlyAddedGames"
    /// JSON `LibrarySnapshotNowPlaying` for the music player, or absent.
    public static let nowPlaying = "widget.nowPlaying"

    /// Total non-contentless game count (`Int`).
    public static let gameCount = "widget.gameCount"
    /// Number of distinct systems in the library (`Int`).
    public static let systemCount = "widget.systemCount"
    /// Aggregate play time across all games, in seconds (`Int`).
    public static let totalPlayTime = "widget.totalPlayTime"
    /// Number of games marked as favorites (`Int`).
    public static let favoritesCount = "widget.favoritesCount"
}

/// Versioning and bounds for the snapshot format.
public enum LibrarySnapshotSchema {
    /// Bumped whenever the meaning of an existing key changes.
    ///
    /// Adding a *new* optional key or a new list does **not** require a bump:
    /// readers tolerate missing keys, so old data stays usable.  A bump means
    /// "older readers must not interpret this data", and readers reject any
    /// version greater than the one they were built against.
    ///
    /// - Version 0: original widget-only payload (no version key written).
    /// - Version 1: adds `schemaVersion`, `updatedAt`, `recentlyAddedGames`,
    ///   and `LibrarySnapshotGame.remoteArtworkURL`.
    public static let currentVersion = 1

    /// Version written by builds that predate versioning.
    public static let unversioned = 0

    // MARK: - Bounds
    //
    // The snapshot is a *bounded* projection, never the whole library: it lives
    // in a `UserDefaults` plist that every extension reads eagerly. These caps
    // are the design, not an accident.

    /// Maximum recently-played entries persisted.
    public static let maxRecentGames = 24
    /// Maximum gallery entries persisted.
    public static let maxGalleryGames = 12
    /// Maximum favorites persisted (covers the `systemExtraLarge` 4×4 grid).
    public static let maxFavoriteGames = 16
    /// Maximum recently-added entries persisted.
    public static let maxRecentlyAddedGames = 16
}
