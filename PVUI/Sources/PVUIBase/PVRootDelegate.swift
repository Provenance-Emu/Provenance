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

// MARK: - PVRootDelegate

public protocol PVRootDelegate: AnyObject {
    func attemptToDelete(game: PVGame)
    func showUnderConstructionAlert()
    // objects fetched via @ObservedResults are `frozen`, so we need to thaw them before Realm lets us use them
    // the following methods call their equivalent GameLaunchingViewController methods with thawed objects
    func root_canLoad(_ game: PVGame) async throws
    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?, showCoreSelection: Bool) async
    func root_openSaveState(_ saveState: PVSaveState) async
    func root_updateRecentGames(_ game: PVGame)
    func root_presentCoreSelection(forGame game: PVGame, sender: Any?)
    func showMessage(_ message: String, title: String)
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
