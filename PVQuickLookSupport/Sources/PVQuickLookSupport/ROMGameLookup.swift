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

/// Shared Realm lookup helpers for QuickLook and Thumbnail extensions.
///
/// All lookups are performed synchronously on the calling thread.
/// No Realm objects escape these functions — only plain value types are returned.
///
/// Usage example:
/// ```swift
/// import PVQuickLookSupport
///
/// if let info = ROMGameLookup.lookup(forROMFilename: "SuperMario.sfc") {
///     let artworkData = ArtworkResolver.data(forKey: info.artworkURLKey ?? "")
/// }
/// ```
public struct ROMGameLookup {

    // MARK: - Public API

    /// Looks up game metadata by ROM filename from the shared Realm database.
    ///
    /// Searches for a `PVGame` whose `romPath` ends with `"/\(romFilename)"` (to
    /// match the `{systemID}/{filename}` storage format) and falls back to an
    /// exact match on `romPath == romFilename`.
    ///
    /// - Parameter romFilename: The bare filename including extension
    ///   (e.g. `"SuperMario64.n64"`).
    /// - Returns: A `GameInfo` value, or `nil` when App Groups are unavailable
    ///   or no game matches the filename.
    public static func lookup(forROMFilename romFilename: String) -> GameInfo? {
        guard !romFilename.isEmpty else { return nil }
        guard RealmConfiguration.supportsAppGroups else {
            WLOG("[PVQuickLookSupport] App Groups unavailable — skipping Realm lookup for \(romFilename)")
            return nil
        }
        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()

            let game = findGame(in: realm, forFilename: romFilename)
            guard let game = game else {
                DLOG("[PVQuickLookSupport] No game found for ROM filename: \(romFilename)")
                return nil
            }
            return gameInfo(from: game)
        } catch {
            ELOG("[PVQuickLookSupport] Realm lookup failed for \(romFilename): \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns the local file URL for the screenshot image of a save state file.
    ///
    /// - Parameter saveStatePath: Full or partial path to the `.pvsav` file.
    /// - Returns: A file URL pointing to the screenshot image, or `nil` when not found.
    public static func saveStateImageURL(forSaveStatePath saveStatePath: String) -> URL? {
        guard !saveStatePath.isEmpty else { return nil }
        guard RealmConfiguration.supportsAppGroups else {
            WLOG("[PVQuickLookSupport] App Groups unavailable — skipping save state lookup")
            return nil
        }
        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()
            let filename = (saveStatePath as NSString).lastPathComponent
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
            ELOG("[PVQuickLookSupport] Realm save state lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Internal Helpers (package-internal for testability)

    /// Returns `true` when `romPath` ends with `"/\(filename)"` or equals `filename`.
    ///
    /// This mirrors the Realm predicate used in `findGame(in:forFilename:)` and is
    /// exposed at the package-internal level so unit tests can exercise the matching
    /// logic without needing a live Realm instance.
    static func romPathMatches(_ romPath: String, filename: String) -> Bool {
        guard !filename.isEmpty else { return false }
        return romPath.hasSuffix("/" + filename) || romPath == filename
    }

    // MARK: - Private

    private static func findGame(in realm: Realm, forFilename filename: String) -> PVGame? {
        let bySuffix = realm.objects(PVGame.self)
            .filter("romPath ENDSWITH %@", "/" + filename)
        if let game = bySuffix.first { return game }
        return realm.objects(PVGame.self)
            .filter("romPath == %@", filename)
            .first
    }

    private static func derivedTitle(from romPath: String) -> String {
        let base = (romPath as NSString).lastPathComponent
        let noExt = (base as NSString).deletingPathExtension
        return noExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func gameInfo(from game: PVGame) -> GameInfo {
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

    private static func emptyToNil(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }
}
