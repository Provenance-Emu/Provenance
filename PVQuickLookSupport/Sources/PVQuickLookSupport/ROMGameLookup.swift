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
/// Uses `PVAppGroupId` from PVLibrary as the canonical app group constant —
/// never hardcode the group ID string outside of that one definition.
private func openReadOnlyGroupRealm() throws -> Realm? {
    guard let groupURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId),
          FileManager.default.isReadableFile(atPath: groupURL.path) else {
        WLOG("[PVQuickLookSupport] App Group container unavailable for: \(PVAppGroupId)")
        return nil
    }
#if os(tvOS)
    // On tvOS, the App Group container's documents path maps to Library/Caches/.
    let realmURL = groupURL.appendingPathComponent("Library/Caches/default.realm", isDirectory: false)
#else
    let realmURL = groupURL.appendingPathComponent("default.realm", isDirectory: false)
#endif
    guard FileManager.default.fileExists(atPath: realmURL.path) else {
        WLOG("[PVQuickLookSupport] Realm not found at \(realmURL.path)")
        return nil
    }
    let config = Realm.Configuration(
        fileURL: realmURL,
        readOnly: true,
        schemaVersion: schemaVersion
    )
    return try Realm(configuration: config)
}
