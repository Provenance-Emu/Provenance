//
//  PVRootDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

import PVLibrary
import Foundation
import PVRealm
import PVLogging
import RealmSwift

// MARK: - PVRootDelegate

public protocol PVRootDelegate: AnyObject {
    func attemptToDelete(game: PVGame, deleteSaves: Bool)
    func showUnderConstructionAlert()
    // objects fetched via @ObservedResults are `frozen`, so we need to thaw them before Realm lets us use them
    // the following methods call their equivalent GameLaunchingViewController methods with thawed objects
    func root_canLoad(_ game: PVGame) async throws
    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async
    func root_loadPath(_ path: String, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async
    func root_openSaveState(_ saveState: PVSaveState) async
    func root_updateRecentGames(_ game: PVGame)
    func root_presentCoreSelection(forGame game: PVGame, sender: Any?)
    func showMessage(_ message: String, title: String)
    func root_loadDisc(_ disc: PVFile, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async
    /// Shows the continues management view
    /// - Parameter game: Optional game to filter save states. If nil, shows all save states.
    func root_showContinuesManagement(_ game: PVGame?)
    func root_showContinuesManagement(forSystemID systemID: String)

    /// Dismisses any presented views (sheets, popovers, etc.)
    /// This should be called before loading a game or save state
    @MainActor func dismissPresentedViews() async

    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>! { get }
}

public extension PVRootDelegate {
    /// Default implementation that does nothing
    @MainActor func dismissPresentedViews() async {
        // Default implementation does nothing
        // Implementers should override this to dismiss any presented views
    }

    public func root_openSaveState(_ saveStateId: String) async {
        // Use Task to explicitly run on the main actor
        await MainActor.run {
            do {
                let realm = try Realm()

                // Find the save state
                guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else {
                    showMessage("Failed to load Save State with id: \(saveStateId)", title: "Failed to Load Save State")
                    return
                }

                // Get references to the objects we need
                let game = saveState.game

                // Create frozen copies that can be safely passed across thread boundaries
                let frozenSaveState = saveState.freeze()

                // Now we can safely pass the frozen objects
                // We need to dismiss any presented sheets first, then load the save state
                Task { @MainActor in
                    // First, dismiss any presented sheets
                    await dismissPresentedViews()

                    // Then load the save state
                    await root_load(frozenSaveState.game, sender: nil, core: nil, saveState: frozenSaveState)
                }
            } catch {
                ELOG("Error accessing Realm: \(error.localizedDescription)")
                showMessage("Failed to access database: \(error.localizedDescription)", title: "Database Error")
            }
        }
    }

    /// Load a game by its MD5 hash (primary key)
    public func root_loadGame(byMD5Hash md5: String) async {
        // Use Task to explicitly run on the main actor
        await MainActor.run {
            do {
                let realm = try Realm()

                // Find the game
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                    showMessage("Failed to load game with MD5: \(md5)", title: "Failed to Load Game")
                    return
                }

                // Create a frozen copy that can be safely passed across thread boundaries
                let frozenGame = game.freeze()

                // Now we can safely pass the frozen object
                Task { @MainActor in
                    // First, dismiss any presented sheets
                    await dismissPresentedViews()

                    // Then load the game
                    await root_load(frozenGame, sender: nil, core: nil, saveState: nil)
                }
            } catch {
                ELOG("Error accessing Realm: \(error.localizedDescription)")
                showMessage("Failed to access database: \(error.localizedDescription)", title: "Database Error")
            }
        }
    }

    /// Load a specific disc for a game
    public func root_loadDisc(_ disc: PVFile, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        await root_loadPath(disc.url?.path ?? "", forGame: game, sender: sender, core: core, saveState: saveState)
    }
}

extension PVRootDelegate {
    private func renameGame(_ game: PVGame, toTitle newTitle: String) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.title = newTitle
            }
            showMessage("Game successfully renamed to \(newTitle).", title: "Game Renamed")
        } catch {
            showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
        }
    }
}
