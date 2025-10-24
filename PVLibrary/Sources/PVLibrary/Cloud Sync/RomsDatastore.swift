//
//  RomsDatastore.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import RealmSwift
import PVPrimitives

/// Datastore for accessing saves and anything related to saves.
actor RomsDatastore {
    private let realm: Realm
    private let fileManager: FileManager
    
    init() async throws {
        realm = try await Realm(actor: RealmActor.shared)
        fileManager = .default
    }
    
    /// queries datastore for save using id
    /// - Parameter id: primary key of save
    /// - Returns: save or nil if one exists
    @RealmActor
    func findSaveState(forPrimaryKey id: String) -> PVSaveState? {
        realm.object(ofType: PVSaveState.self, forPrimaryKey: id)
    }
    
    /// queries datastore for game that corresponds to save
    /// - Parameter save: save to use to query for game
    /// - Returns: game or nil if one exists
    @RealmActor
    func findGame(md5: String, forSave save: PVSaveState) -> PVGame? {
        // See if game is missing and set
        guard save.game?.system == nil
        else {
            return nil
        }
        return realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased())
    }
    
    /// stores game assoicated with save
    /// - Parameters:
    ///   - save: save to associate game with
    ///   - game: game to store
    @RealmActor
    func update(existingSave save: PVSaveState, with game: PVGame) async throws {
        try await realm.asyncWrite {
            save.game = game
        }
    }
    
    /// inserts a new save into datastore
    /// - Parameter save: save to create
    @RealmActor
    func create(newSave save: SaveState) async throws {
        let newSave = await realm.buildSaveState(from: save)
        try await realm.asyncWrite {
            realm.add(newSave, update: .all)
        }
        DLOG("Added new save \(newSave.debugDescription)")
    }
    
    /// deletes all saves that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    @RealmActor
    func deleteSaveStatesRemoveWhileApplicationClosed() async throws {
        try await realm.asyncWrite {
            realm.objects(PVSaveState.self).forEach { save in
                guard let file = save.file,
                      let url = file.url
                else {
                    return
                }
                let saveUrl = url.appendingPathExtension("json").pathDecoded
                if !fileManager.fileExists(atPath: saveUrl) {
                    ILOG("save: \(saveUrl) does NOT exist, removing from datastore")
                    realm.delete(save)
                }
            }
        }
    }
    
    /// tries to delete save state from the database
    /// - Parameter file: file is used to query for the save state in the database attempt to delete
    @RealmActor
    func deleteSaveState(file: URL) async throws {
        DLOG("attempting to query PVSaveState by file: \(file)")
        let gameDirectory = file.parentPathComponent
        let savesDirectory = file.deletingLastPathComponent().parentPathComponent
        let partialPath = "\(savesDirectory)/\(gameDirectory)/\(file.lastPathComponent)"
        let imageField = NSExpression(forKeyPath: \PVSaveState.image.self).keyPath
        let partialPathField = NSExpression(forKeyPath: \PVImageFile.partialPath.self).keyPath
        let results = await realm.objects(PVSaveState.self).filter(NSPredicate(format: "\(imageField).\(partialPathField) CONTAINS[c] %@", partialPath))
        DLOG("saves found: \(results.count)")
        guard let save: PVSaveState = results.first
        else {
            return
        }
        ILOG("""
        removing save: \(partialPath)
        full file: \(file)
        """)
        try await realm.asyncWrite {
            realm.delete(save)
        }
    }
    
    /// deletes all games that do NOT exist in the file system, but exist in the database. this will happen when the user deletes on a different device, or outside of the app and the app is opened. the app won't get a notification in this case, we have to manually do this check
    /// - Parameter romsPath: rull ROMs path
    @RealmActor
    func deleteGamesDeletedWhileApplicationClosed(romsPath: URL) async {
        for (_, game) in RomDatabase.gamesCache {
            let gameUrl = romsPath.appendingPathComponent(game.romPath)
            DLOG("""
            rom partial path: \(game.romPath)
            full game URL: \(gameUrl)
            """)
            guard await !fileManager.fileExists(atPath: gameUrl.pathDecoded)
            else {
                continue
            }
            do {
                if let gameToDelete = await realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash) {
                    ILOG("\(gameUrl) does NOT exists, removing from datastore")
                    try await deleteGame(gameToDelete)
                }
            } catch {
                ELOG("error deleting \(gameUrl), \(error)")
            }
        }
    }
    
    /// tries to delete game from database
    /// - Parameter md5Hash: hash used to query for the game in the database
    @RealmActor
    func deleteGame(md5Hash: String) async throws {
        guard let game: PVGame = await realm.object(ofType: PVGame.self, forPrimaryKey: md5Hash.uppercased())
        else {
            return
        }
        ILOG("deleting \(game.fileName) from datastore")
        try await deleteGame(game)
    }
    
    /// helper to delete saves/cheats/recentPlays/screenShots related to the game
    /// - Parameter game: game entity to delete related entities
    @RealmActor
    private func deleteGame(_ game: PVGame) async throws {
        // Make a frozen copy of the game before deletion to use for cache removal
        let frozenGame = game.freeze()
        
        try await realm.asyncWrite {
            guard !game.isInvalidated else { return }
            // Delete related objects if they exist
            if !game.saveStates.isInvalidated {
                game.saveStates.forEach { save in
                    if !save.isInvalidated {
                        realm.delete(save)
                    }
                }
            }
            if !game.cheats.isInvalidated {
                game.cheats.forEach { cheat in
                    if !cheat.isInvalidated {
                        realm.delete(cheat)
                    }
                }
            }
            if !game.recentPlays.isInvalidated {
                game.recentPlays.forEach { play in
                    if !play.isInvalidated {
                        realm.delete(play)
                    }
                }
            }
            if !game.screenShots.isInvalidated {
                game.screenShots.forEach { screenshot in
                    if !screenshot.isInvalidated {
                        realm.delete(screenshot)
                    }
                }
            }
            realm.delete(game)
            
            // Use the more efficient cache removal instead of reloading the entire cache
            RomDatabase.removeGameFromCache(frozenGame)
        }
    }
}

