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
    public func root_canLoad(_ game: PVGame) async throws {
        try await self.canLoad(game.warmUp())
    }

    public func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        await self.load(game.warmUp(), sender: sender, core: core?.warmUp(), saveState: saveState?.warmUp())
    }

    public func root_openSaveState(_ saveState: PVSaveState) async {
        await self.openSaveState(saveState.warmUp())
    }

    public func root_updateRecentGames(_ game: PVGame) {
        self.updateRecentGames(game.warmUp())
    }

    public func root_presentCoreSelection(forGame game: PVGame, sender: Any?) {
        self.presentCoreSelection(forGame: game.warmUp(), sender: sender)
    }

    public func attemptToDelete(game: PVGame) {
        do {
            try self.delete(game: game)
        } catch {
            self.presentError(error.localizedDescription, source: self.view)
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
    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
    }
}

extension PVRootViewController: WebServerActivatorController {

}

#if canImport(SafariServices)
extension PVRootViewController: SFSafariViewControllerDelegate {

}
#endif

#endif
