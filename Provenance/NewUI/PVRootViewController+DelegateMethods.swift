//
//  PVRootViewController+DelegateMethods.swift
//  Provenance
//
//  Created by Ian Clawson on 1/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVLibrary
#if canImport(SwiftUI)
import SwiftUI

// MARK: - PVRootDelegate

public protocol PVRootDelegate {
    func attemptToDelete(game: PVGame)
    func showUnderConstructionAlert()
    // objects fetched via @ObservedResults are `frozen`, so we need to thaw them before Realm lets us use them
    // the following methods call their equivalent GameLaunchingViewController methods with thawed objects
    func root_canLoad(_ game: PVGame) throws
    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?)
    func root_openSaveState(_ saveState: PVSaveState)
    func root_updateRecentGames(_ game: PVGame)
    func root_presentCoreSelection(forGame game: PVGame, sender: Any?)
}

@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVRootDelegate {
    func root_canLoad(_ game: PVGame) throws {
        try self.canLoad(game.warmUp())
    }
    
    func root_load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) {
        self.load(game.warmUp(), sender: sender, core: core?.warmUp(), saveState: saveState?.warmUp())
    }
    
    func root_openSaveState(_ saveState: PVSaveState) {
        self.openSaveState(saveState.warmUp())
    }
    
    func root_updateRecentGames(_ game: PVGame) {
        self.updateRecentGames(game.warmUp())
    }
    
    func root_presentCoreSelection(forGame game: PVGame, sender: Any?) {
        self.presentCoreSelection(forGame: game.warmUp(), sender: sender)
    }
    
    func attemptToDelete(game: PVGame) {
        do {
            try self.delete(game: game)
        } catch {
            self.presentError(error.localizedDescription)
        }
    }
    
    func showUnderConstructionAlert() {
        self.presentMessage("Please try again in a future update.", title: "⚠️ Under Construction ⚠️")
    }
}

// MARK: - Methods from PVGameLibraryViewController

@available(iOS 14, tvOS 14, *)
extension PVRootViewController {
    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
//        loadLastKnownNavOption()
        // we're still retaining a refernce to the removed game, causing a realm crash. Need to reload the view
    }
}


// MARK: - Menu Delegate

public protocol PVMenuDelegate {
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
}

@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVMenuDelegate {
    func didTapSettings() {
        #if os(iOS)
        
        guard
            let settingsNav = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "settingsNavigationController") as? UINavigationController,
            let settingsVC = settingsNav.topViewController as? PVSettingsViewController
        else { return }
        
        settingsVC.conflictsController = updatesController
        self.closeMenu()
        self.present(settingsNav, animated: true)
        #elseif os(tvOS)
        // TODO: load tvOS settings from bundle
        #endif
    }

    func didTapHome() {
        self.closeMenu()
        let homeView = HomeView(gameLibrary: self.gameLibrary, delegate: self)
        self.loadIntoContainer(.home, newVC: UIHostingController(rootView: homeView))
    }

    func didTapAddGames() {
        self.closeMenu()
        #if os(iOS)

        /// from PVGameLibraryViewController#getMoreROMs
        let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in
            let extensions = [UTI.rom, UTI.artwork, UTI.savestate, UTI.zipArchive, UTI.sevenZipArchive, UTI.gnuZipArchive, UTI.image, UTI.jpeg, UTI.png, UTI.bios, UTI.data].map { $0.rawValue }
            
            let documentPicker = PVDocumentPickerViewController(documentTypes: extensions, in: .import)
            documentPicker.allowsMultipleSelection = true
            documentPicker.delegate = self
            self.present(documentPicker, animated: true, completion: nil)
        }))

        let webServerAction = UIAlertAction(title: "Web Server", style: .default, handler: { _ in
//            self.startWebServer() // TODO: this
        })

        actionSheet.addAction(webServerAction)
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        actionSheet.preferredContentSize = CGSize(width: 300, height: 150)

        present(actionSheet, animated: true, completion: nil)
        #endif
    }

    func didTapConsole(with consoleId: String) {
        self.closeMenu()
        
        guard let console = gameLibrary.system(identifier: consoleId) else { return }
        let consoles = gameLibrary.activeSystems
        
        consolesWrapperViewDelegate.selectedTab = console.identifier
        self.consoleIdentifiersAndNamesMap.removeAll()
        for console in consoles {
            self.consoleIdentifiersAndNamesMap[console.identifier] = console.name
        }
        selectedTabCancellable = consolesWrapperViewDelegate.$selectedTab.sink { [weak self] tab in
            guard let self = self else { return }
            if let cachedTitle = self.consoleIdentifiersAndNamesMap[tab] {
                self.navigationItem.title = cachedTitle
            } else if let console = self.gameLibrary.system(identifier: tab) {
                self.consoleIdentifiersAndNamesMap[console.identifier] = console.name
                self.navigationItem.title = self.consoleIdentifiersAndNamesMap[tab]
            } else {
                self.navigationItem.title = tab
            }
        }
        
        let consolesView = ConsolesWrapperView(consolesWrapperViewDelegate: consolesWrapperViewDelegate, viewModel: self.viewModel, rootDelegate: self)
        self.loadIntoContainer(.console(consoleId: consoleId, title: console.name), newVC: UIHostingController(rootView: consolesView))
    }

    func didTapCollection(with collection: Int) { /* TODO: collections */ }
}

#endif
