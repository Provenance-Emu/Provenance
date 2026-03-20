//
//  GameInfo.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Lightweight value type carrying metadata for a game looked up from Realm.
//  No Realm objects are stored — only plain Foundation types.
//

import Foundation

/// Metadata for a ROM game, extracted from the shared Realm database.
///
/// All stored properties are plain value types — no Realm objects are retained.
/// This struct is `Sendable` and safe to pass across threads.
public struct GameInfo: Sendable {

    /// Display title of the game, guaranteed to be non-empty.
    public let title: String

    /// Human-readable system name (e.g. "Super Nintendo").  `nil` when unknown.
    public let systemName: String?

    /// Reverse-DNS system identifier (e.g. `"com.provenance.snes"`).  `nil` when unknown.
    public let systemIdentifier: String?

    /// Developer / publisher name, or `nil` when not in the database.
    public let developer: String?

    /// Publication year string (e.g. `"1996"`), or `nil` when not in the database.
    public let year: String?

    /// Comma-separated genres, or `nil` when not in the database.
    public let genre: String?

    /// Long-form game description, or `nil` when not in the database.
    public let gameDescription: String?

    /// Number of times the game has been launched.
    public let playCount: Int

    /// Whether the user has marked this game as a favourite.
    public let isFavorite: Bool

    /// The `PVMediaCache` key used to look up cached box art.
    ///
    /// Pass this to `ArtworkResolver.fileURL(forKey:)` or
    /// `ArtworkResolver.data(forKey:)`.  `nil` when no artwork URL is recorded.
    public let artworkURLKey: String?

    public init(
        title: String,
        systemName: String?,
        systemIdentifier: String?,
        developer: String?,
        year: String?,
        genre: String?,
        gameDescription: String?,
        playCount: Int,
        isFavorite: Bool,
        artworkURLKey: String?
    ) {
        self.title = title
        self.systemName = systemName
        self.systemIdentifier = systemIdentifier
        self.developer = developer
        self.year = year
        self.genre = genre
        self.gameDescription = gameDescription
        self.playCount = playCount
        self.isFavorite = isFavorite
        self.artworkURLKey = artworkURLKey
    }
}
