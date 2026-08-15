//
//  LibrarySnapshotGame.swift
//  PVLibrarySnapshot
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

/// A single game as projected into the App Group snapshot.
///
/// This is deliberately the *smallest* representation that satisfies every
/// extension consumer — see `LibrarySnapshotReader` for the per-consumer field
/// list. It carries no Realm object, no image bytes, and no file handles.
///
/// `PVAppIntents` exposes this type as `WidgetGameData` for source compatibility
/// with the existing widget write path.
public struct LibrarySnapshotGame: Codable, Sendable, Identifiable, Hashable {
    /// The game's MD5 hash — also its deep-link identifier.
    public let id: String
    public let title: String
    /// Short (preferred) or full system name, for display.
    public let systemName: String
    /// Reverse-DNS system id (e.g. `com.provenance.snes`) when known.
    /// Consumers map this to `SystemIdentifier` for per-system presentation.
    public let systemIdentifier: String?
    /// Path *relative to the App Group container root* where box art is cached,
    /// e.g. `Documents/PVCache/<md5-of-artwork-key>`. `nil` when the art is not
    /// present in the container.
    public let artworkPath: String?
    /// Last play-related activity timestamp, or the import date when the game
    /// has never been played.
    public let lastPlayedDate: Date?
    /// Absolute http(s) artwork URL, used as a fallback when `artworkPath` is
    /// `nil`. Top Shelf can fetch this itself; widgets do not (WidgetKit has no
    /// network budget for timeline rendering).
    public let remoteArtworkURL: String?

    public init(
        id: String,
        title: String,
        systemName: String,
        systemIdentifier: String? = nil,
        artworkPath: String? = nil,
        lastPlayedDate: Date? = nil,
        remoteArtworkURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.artworkPath = artworkPath
        self.lastPlayedDate = lastPlayedDate
        self.remoteArtworkURL = remoteArtworkURL
    }

    /// The game's MD5 hash identifier — same as `id`.
    public var md5Hash: String { id }

    /// Absolute URL of the cached artwork inside the App Group container, if any.
    public var localArtworkURL: URL? {
        guard let artworkPath else { return nil }
        return LibrarySnapshotAppGroup.url(forRelativePath: artworkPath)
    }

    /// Best available artwork URL: the App Group cache when present, otherwise
    /// the remote URL. `nil` when the game has no artwork at all.
    public var bestArtworkURL: URL? {
        if let localArtworkURL, FileManager.default.fileExists(atPath: localArtworkURL.path) {
            return localArtworkURL
        }
        guard let remoteArtworkURL, !remoteArtworkURL.isEmpty else { return nil }
        return URL(string: remoteArtworkURL)
    }
}

/// Now-playing music track info written by the Music Player (#2654).
public struct LibrarySnapshotNowPlaying: Codable, Sendable {
    public let trackTitle: String
    public let artistName: String?
    public let albumTitle: String?
    /// Path relative to the App Group container root for cached album art.
    public let albumArtPath: String?
    public let timestamp: Date

    public init(
        trackTitle: String,
        artistName: String? = nil,
        albumTitle: String? = nil,
        albumArtPath: String? = nil,
        timestamp: Date = Date()
    ) {
        self.trackTitle = trackTitle
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.albumArtPath = albumArtPath
        self.timestamp = timestamp
    }
}

/// Aggregate library counters.
public struct LibrarySnapshotStats: Sendable, Equatable {
    public let totalGames: Int
    public let totalSystems: Int
    public let totalPlayTimeSeconds: Int
    public let favoritesCount: Int

    public static let empty = LibrarySnapshotStats(
        totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0
    )

    public init(totalGames: Int, totalSystems: Int, totalPlayTimeSeconds: Int, favoritesCount: Int) {
        self.totalGames = totalGames
        self.totalSystems = totalSystems
        self.totalPlayTimeSeconds = totalPlayTimeSeconds
        self.favoritesCount = favoritesCount
    }
}
