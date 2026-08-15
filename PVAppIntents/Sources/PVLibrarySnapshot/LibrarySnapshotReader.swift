//
//  LibrarySnapshotReader.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Read side of the App Group library snapshot.
//
//  ## Why this exists
//
//  App extensions cannot call into the host app: there is no general
//  extension→app IPC on iOS/tvOS, and Top Shelf, Spotlight and Widget
//  extensions run precisely when Provenance is *not* running.  The only
//  supported channel is the shared App Group container.  So the host app
//  pre-serialises a bounded projection of the library, and extensions read
//  that instead of opening Realm.
//
//  ## Cost
//
//  Reading is a `UserDefaults` plist read plus a JSON decode of at most a few
//  dozen small structs.  No Realm, no schema migration, no file locking, no
//  full-library materialisation.  Lists are decoded lazily and independently,
//  so a Top Shelf refresh never pays for gallery data it does not display.
//
//  ## Failure behaviour
//
//  Every path degrades to empty. Nothing in this file traps, force-unwraps, or
//  throws: an extension that crashes under memory pressure is the exact failure
//  mode this replaces.
//

import Foundation

/// The bounded lists carried by the snapshot.
public enum LibrarySnapshotList: String, Sendable, CaseIterable {
    /// Most-recently-played first.
    case recentlyPlayed
    /// Random sample of the library, for art rotation. **Not** ordered.
    case gallery
    /// Favourites, sorted by title ascending.
    case favorites
    /// Most-recently-imported first.
    case recentlyAdded

    var storageKey: String {
        switch self {
        case .recentlyPlayed: return LibrarySnapshotKeys.recentGames
        case .gallery: return LibrarySnapshotKeys.galleryGames
        case .favorites: return LibrarySnapshotKeys.favoriteGames
        case .recentlyAdded: return LibrarySnapshotKeys.recentlyAddedGames
        }
    }
}

/// Reads the library snapshot from an App Group `UserDefaults` suite.
///
/// Construct one per read burst and reuse it; it holds no cache, so each
/// accessor is an independent, cheap read.
///
/// `@unchecked Sendable`: the only stored property is a `UserDefaults` suite,
/// which Apple documents as thread-safe, and this type never mutates it.
public struct LibrarySnapshotReader: @unchecked Sendable {
    private let defaults: UserDefaults?

    /// - Parameter defaults: the suite to read. Defaults to the App Group suite;
    ///   inject a scratch suite in tests.
    public init(defaults: UserDefaults? = LibrarySnapshotAppGroup.defaults) {
        self.defaults = defaults
    }

    // MARK: - Versioning

    /// Schema version of the stored data. `0` when written by a build that
    /// predates versioning, which is still readable.
    public var schemaVersion: Int {
        guard let defaults else { return LibrarySnapshotSchema.unversioned }
        return defaults.integer(forKey: LibrarySnapshotKeys.schemaVersion)
    }

    /// `false` when the stored data was written by a *newer* build than this
    /// reader understands. Older data is always readable — missing keys simply
    /// decode to empty.
    public var isSchemaSupported: Bool {
        schemaVersion <= LibrarySnapshotSchema.currentVersion
    }

    /// When the host app last wrote the snapshot, or `nil` if never / unversioned.
    public var updatedAt: Date? {
        guard let defaults else { return nil }
        let seconds = defaults.double(forKey: LibrarySnapshotKeys.updatedAt)
        guard seconds > 0 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// `true` when the snapshot was last written more than `interval` ago.
    ///
    /// A snapshot with no timestamp is *not* reported stale: it was written by
    /// an older build and is still the best data available. Callers should
    /// prefer stale content over an empty shelf.
    public func isStale(olderThan interval: TimeInterval) -> Bool {
        guard let updatedAt else { return false }
        return Date().timeIntervalSince(updatedAt) > interval
    }

    /// `true` when the host app has written a usable snapshot this reader can
    /// interpret. Consumers must render an empty/onboarding state otherwise —
    /// never fall back to opening Realm.
    public var isAvailable: Bool {
        guard defaults != nil, isSchemaSupported else { return false }
        return stats.totalGames > 0
    }

    // MARK: - Lists

    /// Decodes one bounded list. Returns `[]` on any failure.
    public func games(_ list: LibrarySnapshotList) -> [LibrarySnapshotGame] {
        guard isSchemaSupported,
              let data = defaults?.data(forKey: list.storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LibrarySnapshotGame].self, from: data)) ?? []
    }

    /// Decodes one bounded list, capped at `limit` entries.
    public func games(_ list: LibrarySnapshotList, limit: Int) -> [LibrarySnapshotGame] {
        guard limit > 0 else { return [] }
        return Array(games(list).prefix(limit))
    }

    // MARK: - Scalars

    public var stats: LibrarySnapshotStats {
        guard let defaults, isSchemaSupported else { return .empty }
        return LibrarySnapshotStats(
            totalGames: defaults.integer(forKey: LibrarySnapshotKeys.gameCount),
            totalSystems: defaults.integer(forKey: LibrarySnapshotKeys.systemCount),
            totalPlayTimeSeconds: defaults.integer(forKey: LibrarySnapshotKeys.totalPlayTime),
            favoritesCount: defaults.integer(forKey: LibrarySnapshotKeys.favoritesCount)
        )
    }

    public var nowPlaying: LibrarySnapshotNowPlaying? {
        guard isSchemaSupported,
              let data = defaults?.data(forKey: LibrarySnapshotKeys.nowPlaying) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LibrarySnapshotNowPlaying.self, from: data)
    }
}
