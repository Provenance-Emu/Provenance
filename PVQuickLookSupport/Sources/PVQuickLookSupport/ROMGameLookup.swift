//
//  ROMGameLookup.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Looks up PVGame and PVSaveState records from the shared App Group Realm
//  database by ROM filename or save-state file path.
//

import Foundation
import PVLibrary
import RealmSwift

// MARK: - GamePreviewDataSource protocol

/// Abstraction over the game database for QuickLook and Thumbnail extensions.
///
/// The default implementation (`RealmGamePreviewDataSource`) reads from the shared
/// App Group Realm database. When SwiftData support is added, provide a new conforming
/// type without touching `PreviewProvider`, `GameMetadataCard`, or any other caller.
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
/// Uses `dataSource` for all queries, defaulting to `RealmGamePreviewDataSource`.
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
    public static var dataSource: any GamePreviewDataSource = RealmGamePreviewDataSource()

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
    /// to recover the original filename for Realm lookups — no download required.
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

// MARK: - RealmGamePreviewDataSource

/// Reads from the shared App Group Realm database in **read-only** mode.
///
/// `RealmConfiguration.setDefaultRealmConfig()` is intentionally NOT used —
/// it opens the database with write access and a migration block, both unsafe
/// from extension processes sharing the live Realm with the running main app.
/// Schema version is derived from PVLibrary's `schemaVersion` constant so it
/// stays in sync automatically.
public struct RealmGamePreviewDataSource: GamePreviewDataSource {

    public init() {}

    public func game(forROMFilename filename: String) -> GameInfo? {
        guard !filename.isEmpty else { return nil }
        do {
            guard let realm = try openReadOnlyGroupRealm() else { return nil }
            guard let game = findGame(in: realm, forFilename: filename) else {
                DLOG("[PVQuickLookSupport] No game found for: \(filename)")
                return nil
            }
            return gameInfo(from: game)
        } catch {
            ELOG("[PVQuickLookSupport] Realm lookup failed for \(filename): \(error.localizedDescription)")
            return nil
        }
    }

    public func saveStateImageURL(forPath path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        do {
            guard let realm = try openReadOnlyGroupRealm() else { return nil }
            let filename = (path as NSString).lastPathComponent
            let saveStates = realm.objects(PVSaveState.self)
                .filter("file.partialPath ENDSWITH %@", filename)
            guard let saveState = saveStates.first,
                  let imageFile = saveState.image,
                  let imageURL = imageFile.url,
                  FileManager.default.fileExists(atPath: imageURL.path) else {
                return nil
            }
            return imageURL
        } catch {
            ELOG("[PVQuickLookSupport] Realm save-state lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private helpers

    private func findGame(in realm: Realm, forFilename filename: String) -> PVGame? {
        let bySuffix = realm.objects(PVGame.self)
            .filter("romPath ENDSWITH %@", "/" + filename)
        if let game = bySuffix.first { return game }
        return realm.objects(PVGame.self)
            .filter("romPath == %@", filename)
            .first
    }

    private func gameInfo(from game: PVGame) -> GameInfo {
        let artworkKey = game.artworkURL
        return GameInfo(
            title: game.title.isEmpty ? derivedTitle(from: game.romPath) : game.title,
            systemName: game.system?.name ?? game.systemShortName,
            systemIdentifier: game.systemIdentifier,
            developer: emptyToNil(game.developer),
            publishDate: emptyToNil(game.publishDate),
            genre: emptyToNil(game.genres),
            gameDescription: game.gameDescription,
            playCount: game.playCount,
            isFavorite: game.isFavorite,
            artworkURLKey: artworkKey.isEmpty ? nil : artworkKey
        )
    }

    private func derivedTitle(from romPath: String) -> String {
        let base = (romPath as NSString).lastPathComponent
        let noExt = (base as NSString).deletingPathExtension
        return noExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func emptyToNil(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }
}

// MARK: - Extension-safe Realm open

/// Opens the shared App Group Realm in read-only mode.
///
/// Tries the App Group container first (preferred), then falls back to the
/// app's sandboxed Documents directory for configurations where App Groups
/// are not provisioned.  Both paths are opened read-only so the extension
/// process never migrates or writes to the database.
private func openReadOnlyGroupRealm() throws -> Realm? {
    // Build the ordered list of candidate Realm URLs to try.
    var candidates: [URL] = []

    if let groupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId),
       FileManager.default.isReadableFile(atPath: groupURL.path) {
#if os(tvOS)
        // On tvOS the App Group documents path maps to Library/Caches/.
        candidates.append(groupURL.appendingPathComponent("Library/Caches/default.realm", isDirectory: false))
#else
        candidates.append(groupURL.appendingPathComponent("default.realm", isDirectory: false))
#endif
    } else {
        WLOG("[PVQuickLookSupport] App Group container unavailable for: \(PVAppGroupId)")
    }

    // Find the first candidate that actually exists on disk.
    guard let realmURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        WLOG("[PVQuickLookSupport] Realm database not found. Checked: \(candidates.map(\.path))")
        return nil
    }

    DLOG("[PVQuickLookSupport] Opening Realm read-only at \(realmURL.path) (schemaVersion=\(schemaVersion))")
    let config = Realm.Configuration(
        fileURL: realmURL,
        readOnly: true,
        schemaVersion: schemaVersion
    )
    do {
        return try Realm(configuration: config)
    } catch {
        ELOG("[PVQuickLookSupport] Failed to open Realm at \(realmURL.path): \(error.localizedDescription)")
        throw error
    }
}
