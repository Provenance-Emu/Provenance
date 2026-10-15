//
//  GameRekey.swift
//  PVLibrary
//
//  Created by Provenance Emu on 2026-10-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import RealmSwift
import PVRealm

/// Moves a game to a new MD5 after its ROM file was overwritten in place ("Replace the Original").
///
/// `PVGame.md5Hash` is the Realm primary key, so the row cannot be renamed: a copy is inserted under
/// the new key, everything that points at the old row is re-pointed, and the old row is deleted with
/// a plain `realm.delete`. `RomDatabase.delete(game:)` must never be used for this: it removes the
/// ROM file, the saves and the patches.
///
/// Realm only; the caller handles Spotlight, caches, widgets and per-game settings.
public enum GameRekey {
    public enum Failure: Error, Equatable {
        /// No game has the old MD5.
        case gameNotFound
        /// A game with the new MD5 is already in the library.
        case targetExists(title: String)
    }

    /// Re-keys the game stored under `oldMD5` to `newMD5`. Call inside a write transaction on
    /// `realm`. Returns the game under its new key (the same row when the MD5 did not change).
    ///
    /// - Parameters:
    ///   - crc: The new file's CRC32 as stored in `PVGame.crc`.
    ///   - fileSize: The new file's size in bytes.
    @discardableResult
    public static func rekey(
        gameWithMD5 oldMD5: String,
        to newMD5: String,
        crc: String,
        fileSize: Int,
        in realm: Realm
    ) throws -> PVGame {
        guard let old = realm.object(ofType: PVGame.self, forPrimaryKey: oldMD5) else {
            throw Failure.gameNotFound
        }
        let newKey = newMD5.uppercased()
        let changesKey = newKey != old.md5Hash
        if changesKey, let existing = realm.object(ofType: PVGame.self, forPrimaryKey: newKey) {
            throw Failure.targetExists(title: existing.title)
        }
        old.file?.invalidateContentCaches()
        old.crc = crc
        old.fileSize = fileSize
        guard changesKey else { return old }

        // Every persisted property, `id` included (skins and artwork look games up by it). Lists of
        // objects (relatedFiles, screenShots) link the same rows; LinkingObjects are rebuilt below
        // by re-pointing their owners.
        let game = PVGame(value: old)
        game.md5Hash = newKey
        // The cloud copy is the old file under the old key; the new content has none yet.
        game.cloudRecordID = nil
        game.hasCloudAssets = false
        game.lastCloudSyncDate = nil
        game.requiresSync = true
        realm.add(game)

        for state in Array(old.saveStates) { state.game = game }
        for cheat in Array(old.cheats) { cheat.game = game }
        for recent in Array(old.recentPlays) { recent.game = game }
        for patch in Array(old.patches) { patch.game = game }
        for patch in Array(old.variantOfPatches) {
            patch.variantGame = game
            patch.variantGameMD5 = newKey
        }
        for patch in realm.objects(PVPatch.self).filter("baseGameMD5 ==[c] %@", oldMD5) {
            patch.baseGameMD5 = newKey
        }
        for variant in realm.objects(PVGame.self).filter("baseGameMD5 ==[c] %@", oldMD5) {
            variant.baseGameMD5 = newKey
        }
        for library in Array(old.libraries) {
            if let index = library.games.index(of: old) {
                library.games.replace(index: index, object: game)
            }
        }
        for profile in realm.objects(PVControllerProfile.self).filter("gameID ==[c] %@", oldMD5) {
            profile.gameID = newKey
        }

        realm.delete(old)
        return game
    }
}
