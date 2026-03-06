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
import RealmSwift
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
        // First, dismiss any presented views
        await dismissPresentedViews()

        let frozenGame = game.freeze()
        let frozenCore = core?.freeze()
        let frozenSaveState = saveState?.freeze()

        // Route all launches through SceneCoordinator for consistent sync validation
        if let saveState = frozenSaveState {
            // Launch with save state (includes game ROM, BIOS, and save state validation)
            SceneCoordinator.shared.launchSaveState(saveState, core: frozenCore)
        } else {
            // Launch game (includes game ROM and BIOS validation)
            SceneCoordinator.shared.launchGame(frozenGame, core: frozenCore)
        }
    }

    public func root_loadPath(_ path: String, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        // First, dismiss any presented views
        await dismissPresentedViews()

        // Route through SceneCoordinator for consistent sync validation
        let frozenGame = game.freeze()
        let frozenCore = core?.freeze()
        let frozenSaveState = saveState?.freeze()

        SceneCoordinator.shared.launchGame(frozenGame, discPath: path, core: frozenCore, saveState: frozenSaveState)
    }

    public func root_openSaveState(_ saveState: PVSaveState) async {
        // First, dismiss any presented views
        await dismissPresentedViews()

        // Check if a game is already running
        if let gameVC = presentedViewController as? PVEmualatorControllerProtocol {
            // If a game is already running, use the existing openSaveState method
            await self.openSaveState(saveState.warmUp())
        } else {
            // Use SceneCoordinator to launch with proper sync validation
            // This ensures game ROM, BIOS, and save state are all validated and synced
            let frozenSaveState = saveState.freeze()
            SceneCoordinator.shared.launchSaveState(frozenSaveState)
        }
    }

    public func root_updateRecentGames(_ game: PVGame) {
        self.updateRecentGames(game.warmUp())
    }

    public func root_presentCoreSelection(forGame game: PVGame, sender: Any?) {
        self.presentCoreSelection(forGame: game.warmUp(), sender: sender)
    }

    public func root_loadDisc(_ disc: PVFile, forGame game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        // First, dismiss any presented views
        await dismissPresentedViews()

        // Route through SceneCoordinator for consistent sync validation
        // SceneCoordinator will handle the disc path via selectedDiscFilename
        guard let discPath = disc.url?.path else {
            SceneCoordinator.shared.alertState.show(
                title: "Cannot Load Disc",
                message: "The disc file path is not available.",
                type: .error
            )
            return
        }

        let frozenGame = game.freeze()
        let frozenCore = core?.freeze()
        let frozenSaveState = saveState?.freeze()

        SceneCoordinator.shared.launchGame(frozenGame, discPath: discPath, core: frozenCore, saveState: frozenSaveState)
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
            // Use Task to handle async property access
            Task {
                let importQueue = await GameImporter.shared.importQueue
                if importQueue.count > 0 {
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
                        // Use Task to handle the async call
                        Task {
                            await gameImporter.clearCompleted()
                        }
                    }
                    let hostingController = self.makeHostingController(settingsView)
                    let navigationController = UINavigationController(rootViewController: hostingController)
                    self.present(navigationController, animated: true)
                }
            }
            }
        }
    }
}
#endif

#endif
