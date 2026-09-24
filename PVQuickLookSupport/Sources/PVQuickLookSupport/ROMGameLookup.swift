//
//  ROMGameLookup.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Looks up game and save-state metadata from the App Group library index
//  by ROM filename or save-state file path.
//

import Foundation
import PVLibrarySnapshot

// MARK: - GamePreviewDataSource protocol

/// Abstraction over the game database for QuickLook and Thumbnail extensions.
///
/// The default implementation (`SnapshotGamePreviewDataSource`) reads from the
/// App Group library index written by the host app. When SwiftData support is
/// added, provide a new conforming type without touching `PreviewProvider`,
/// `GameMetadataCard`, or any other caller.
///
/// Inject a mock in tests:
/// ```swift
/// ROMGameLookup.dataSource = MockGamePreviewDataSource(games: [...])
/// ```
public protocol GamePreviewDataSource: Sendable {
    /// Returns game metadata for the ROM with the given bare filename (e.g. `"Super Mario World.sfc"`).
    func game(forROMFilename filename: String) -> GameInfo?
    /// Returns the local screenshot URL for the save-state file at `path`, or `nil`.
    func saveStateImageURL(forPath path: String) -> URL?
}

// MARK: - ROMGameLookup (façade)

/// Public façade for game-preview data lookups.
///
/// Uses `dataSource` for all queries, defaulting to `SnapshotGamePreviewDataSource`.
/// All methods are safe to call from extension processes (QuickLook, Thumbnail, etc.).
///
/// Usage:
/// ```swift
/// if let info = ROMGameLookup.lookup(forROMFilename: "SuperMario64.n64") {
///     let artworkData = ArtworkResolver.data(forKey: info.artworkURLKey ?? "")
/// }
/// ```
public struct ROMGameLookup {

    /// The data source used for all lookups.  Override in tests.
    public static var dataSource: any GamePreviewDataSource = SnapshotGamePreviewDataSource()

    public static func lookup(forROMFilename romFilename: String) -> GameInfo? {
        dataSource.game(forROMFilename: romFilename)
    }

    public static func saveStateImageURL(forSaveStatePath saveStatePath: String) -> URL? {
        dataSource.saveStateImageURL(forPath: saveStatePath)
    }

    // MARK: - iCloud placeholder helpers

    /// Recovers the real filename from an iCloud placeholder URL.
    ///
    /// iCloud evicts locally-stored files and replaces them with hidden placeholder
    /// files named `.<OriginalName>.<ext>.icloud`.  QuickLook is invoked with the
    /// placeholder URL, so we strip the `.icloud` suffix (and the leading `.`)
    /// to recover the original filename for lookups — no download required.
    ///
    /// Examples:
    /// - `SuperMario64.n64`        → `SuperMario64.n64`   (unchanged)
    /// - `.SuperMario64.n64.icloud` → `SuperMario64.n64`  (placeholder stripped)
    /// - `SuperMario64.n64.icloud`  → `SuperMario64.n64`  (suffix only stripped)
    public static func realFilename(from url: URL) -> String {
        var name = url.lastPathComponent
        if name.hasSuffix(".icloud") {
            name = String(name.dropLast(".icloud".count))
            if name.hasPrefix(".") {
                name = String(name.dropFirst())
            }
        }
        return name
    }

    // MARK: - Internal (for testability via @testable import)

    /// Returns `true` when `romPath` ends with `"/\(filename)"` or equals `filename`.
    static func romPathMatches(_ romPath: String, filename: String) -> Bool {
        guard !filename.isEmpty else { return false }
        return romPath.hasSuffix("/" + filename) || romPath == filename
    }
}

// MARK: - SnapshotGamePreviewDataSource

/// Reads the App Group library index written by the host app
/// (`WidgetDataWriter.writeLibraryIndex`). No database is opened in the
/// extension process; a missing or stale index simply yields `nil`.
public struct SnapshotGamePreviewDataSource: GamePreviewDataSource {
    private let reader: LibraryIndexReader

    public init(reader: LibraryIndexReader = LibraryIndexReader()) {
        self.reader = reader
    }

    public func game(forROMFilename filename: String) -> GameInfo? {
        guard !filename.isEmpty, let entry = reader.game(forROMFilename: filename) else {
            QuickLookLog.debug("No index entry for \(filename)")
            return nil
        }
        return GameInfo(
            title: entry.title.isEmpty ? derivedTitle(from: entry.filename) : entry.title,
            systemName: entry.systemName,
            systemIdentifier: entry.systemIdentifier,
            developer: entry.developer,
            publishDate: entry.publishDate,
            genre: entry.genre,
            gameDescription: entry.gameDescription,
            playCount: entry.playCount,
            isFavorite: entry.isFavorite,
            artworkURLKey: entry.artworkKey
        )
    }

    public func saveStateImageURL(forPath path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let filename = (path as NSString).lastPathComponent
        guard let url = reader.saveStateImageURL(forFilename: filename),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func derivedTitle(from filename: String) -> String {
        let noExt = (filename as NSString).deletingPathExtension
        return noExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}
