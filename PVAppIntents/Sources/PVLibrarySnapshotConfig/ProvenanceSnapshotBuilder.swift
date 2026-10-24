//
//  ProvenanceSnapshotBuilder.swift
//  PVLibrarySnapshotConfig
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Realm-free projection of library games into the shared snapshot. The host
//  app (PVUIBase `LibrarySnapshotWriter`) reads Realm into
//  `ProvenanceSnapshotSource` values on the main actor and hands them here.
//

import Foundation

/// One library game as the host app read it from Realm.
public struct ProvenanceSnapshotSource: Sendable, Equatable {
    /// `PVGame.md5Hash`, the snapshot id and the launch URL's `md5` value.
    public let md5: String
    public let title: String
    public let romPath: String
    /// Reverse-DNS system id, stored as the snapshot game's `platform`.
    public let systemIdentifier: String
    public let regionName: String?
    /// Newest real play date; nil when the game has never been played.
    /// Never the import date: the snapshot treats any non-nil value as played.
    public let lastPlayed: Date?
    public let isFavorite: Bool
    public let importDate: Date?
    /// The game's `PVMediaCache` key (custom artwork, else original); nil without art.
    public let artworkKey: String?

    public init(md5: String, title: String, romPath: String, systemIdentifier: String,
                regionName: String?, lastPlayed: Date?, isFavorite: Bool,
                importDate: Date?, artworkKey: String?) {
        self.md5 = md5
        self.title = title
        self.romPath = romPath
        self.systemIdentifier = systemIdentifier
        self.regionName = regionName
        self.lastPlayed = lastPlayed
        self.isFavorite = isFavorite
        self.importDate = importDate
        self.artworkKey = artworkKey
    }
}

public enum ProvenanceSnapshotBuilder {
    /// `PVRecentGame` rows scanned for the recents list. Larger than
    /// `LibrarySnapshot.maxRecentlyPlayed` because rows whose game was deleted
    /// or is contentless are skipped.
    public static let recentScanDepth = LibrarySnapshot.maxRecentlyPlayed * 2

    /// Prefix of every mirrored cover file, so pruning never touches anything else.
    public static let coverFilenamePrefix = "cover_"

    /// Basename of a game's mirrored cover. It carries a hash of the artwork key,
    /// so a changed cover is written as a new file rather than skipped as
    /// already mirrored.
    public static func coverFilename(gameID: String, artworkKey: String) -> String {
        "\(coverFilenamePrefix)\(gameID)_\(stableHash(artworkKey)).jpg"
    }

    /// Newest of `PVRecentGame.lastPlayedDate` and `PVGame.lastPlayed`.
    public static func lastPlayed(recent: Date?, game: Date?) -> Date? {
        [recent, game].compactMap { $0 }.max()
    }

    /// Builds the snapshot from a bounded set of candidate games (the recents,
    /// favorites and newest imports), never the whole library: every extension
    /// decodes the whole blob, and `byGameID` holds every game passed in.
    ///
    /// - Parameter covers: game id → cover filename, for covers present in the
    ///   App Group media directory. Games without an entry get no cover.
    public static func snapshot(from sources: [ProvenanceSnapshotSource],
                                covers: [String: String],
                                now: Date = Date()) -> LibrarySnapshot {
        LibrarySnapshot.build(from: sources.map { game(from: $0, coverFilename: covers[$0.md5]) }, now: now)
    }

    static func game(from source: ProvenanceSnapshotSource, coverFilename: String?) -> LibrarySnapshotGame {
        LibrarySnapshotGame(
            id: source.md5,
            title: source.title,
            filePath: source.romPath,
            platform: source.systemIdentifier,
            gametdbID: nil,
            region: source.regionName,
            lastPlayed: source.lastPlayed,
            isFavorite: source.isFavorite,
            dateAdded: source.importDate,
            coverFilename: coverFilename
        )
    }

    /// FNV-1a (64-bit) as hex. Stable across launches and processes, unlike `Hasher`.
    static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
