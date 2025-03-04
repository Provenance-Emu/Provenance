//
//  PVRootViewController+DelegateMethods.swift
//  Provenance
//
//  Created by Ian Clawson on 1/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
import PVPrimitives
import PVUIBase
import PVUIKit
import PVRealm
import PVLogging

#if canImport(SwiftUI)
import SwiftUI
#if canImport(PVWebServer)
import PVWebServer
#endif
#if canImport(SafariServices)
import SafariServices
#endif
@_exported import PVUIBase

import UniformTypeIdentifiers

@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVRootDelegate {
    @MainActor
    public func dismissPresentedViews() async {
        // Dismiss any presented view controllers
        if let presented = self.presentedViewController {
            await presented.dismiss(animated: true)
        }
    }

    public func root_canLoad(_ game: PVGame) async throws {
        try await self.canLoad(game.warmUp())
    }

    public func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        await self.load(game.warmUp(), sender: sender, core: core?.warmUp(), saveState: saveState?.warmUp())
    }

    public func root_loadPath(_ path: String, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        // Create a temporary game object with the new path
        let tempGame = game.copy() as! PVGame
        tempGame.romPath = path

        // Load the temporary game
        await self.load(tempGame.warmUp(), sender: sender, core: core?.warmUp(), saveState: saveState?.warmUp())
    }

    public func root_openSaveState(_ saveState: PVSaveState) async {
        // First, dismiss any presented views
        await dismissPresentedViews()

        // Check if a game is already running
        if let gameVC = presentedViewController as? PVEmualatorControllerProtocol {
            // If a game is already running, use the existing openSaveState method
            await self.openSaveState(saveState.warmUp())
        } else {
            // If no game is running, first load the game, then the save state
            guard let game = saveState.game else {
                ELOG("nil game")
                return
            }
            await self.load(game.warmUp(), sender: nil, core: nil, saveState: saveState.warmUp())
        }
    }

    public func root_updateRecentGames(_ game: PVGame) {
        self.updateRecentGames(game.warmUp())
    }

    public func root_presentCoreSelection(forGame game: PVGame, sender: Any?) {
        self.presentCoreSelection(forGame: game.warmUp(), sender: sender)
    }

    public func root_loadDisc(_ disc: PVFile, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        // Update the game's romPath to point to the selected disc
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.romPath = disc.url!.path
            }

            // Load the game with the updated romPath
            await self.load(game.warmUp(), sender: sender, core: core?.warmUp(), saveState: saveState?.warmUp())
        } catch {
            self.presentError(error.localizedDescription, source: self.view)
        }
    }

    public func attemptToDelete(game: PVGame, deleteSaves: Bool) {
        let title = Bundle.module.localized("DeleteGameTitle")
        let message = Bundle.module.localized("DeleteGameBody", game.title)
        presentDeleteMessage(message, title: title, source: view) {
            do {
                try self.delete(game: game, deleteSaves: deleteSaves)
            } catch {
                self.presentError(error.localizedDescription, source: self.view)
            }
        }
    }

    public func showUnderConstructionAlert() {
        self.presentMessage("Please try again in a future update.", title: "⚠️ Under Construction ⚠️", source: self.view)
    }

    public func showMessage(_ message: String, title: String) {
        self.presentMessage(message, title: title, source: self.view)
    }
}

// MARK: - Methods from PVGameLibraryViewController

@available(iOS 14, tvOS 14, *)
extension PVRootViewController {
    func delete(game: PVGame, deleteSaves: Bool) throws {
        try RomDatabase.sharedInstance.delete(game: game, deleteSaves: deleteSaves)
    }
}

extension PVRootViewController: WebServerActivatorController {

}

#if canImport(SafariServices)
extension PVRootViewController: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true) { [weak self] in
            // Check if there are any imports in the queue
            DLOG("safariViewControllerDidFinish, checking if should present ImportStatusView")
            if GameImporter.shared.importQueue.count > 0 {
                DLOG("safariViewControllerDidFinish, there are imports in the queue, presenting ImportStatusView")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let updatesController = self.updatesController else {
                        WLOG("Nil PVRootViewController or updates controller, can't present ImportStatusView")
                        return
                    }
                    let gameImporter = AppState.shared.gameImporter ?? GameImporter.shared
                    let settingsView = ImportStatusView(
                        updatesController: self.updatesController,
                        gameImporter: gameImporter,
                        delegate: self
                    ) {
                        gameImporter.clearCompleted()
                    }
                    let hostingController = UIHostingController(rootView: settingsView)
                    let navigationController = UINavigationController(rootViewController: hostingController)
                    self.present(navigationController, animated: true)
                }
            }
        }
    }
}
#endif

#endif
