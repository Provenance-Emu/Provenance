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

public protocol PVRootDelegate: GameLaunchingViewController {
    func attemptToDelete(game: PVGame)
    func openDrawer()
}

@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVRootDelegate {
    func attemptToDelete(game: PVGame) {
        do {
            try self.delete(game: game)
        } catch {
            self.presentError(error.localizedDescription)
        }
    }
    
    func openDrawer() {
        self.showMenu()
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
        self.loadIntoContainer(.settings, newVC: settingsVC)
        #elseif os(tvOS)
        // TODO: load tvOS settings from bundle
        #endif
    }

    func didTapHome() {
        self.closeMenu()
        self.navigationItem.title = "Home"
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
        guard let console = try? Realm().object(ofType: PVSystem.self, forPrimaryKey: consoleId) else { return }
        let consoles = try? Realm().objects(PVSystem.self).filter("games.@count > 0").sorted(byKeyPath: "name")
        guard let consoles = consoles else { return }
        consolesWrapperViewDelegate.selectedTab = console.identifier
        let consolesView = ConsolesWrapperView(consolesWrapperViewDelegate: consolesWrapperViewDelegate, gameLibrary: self.gameLibrary, rootDelegate: self, consoles: consoles)
        var consoleIdentifiersAndNamesMap: [String:String] = [:]
        for console in consoles {
            consoleIdentifiersAndNamesMap[console.identifier] = console.name
        }
        selectedTabCancellable = consolesWrapperViewDelegate.$selectedTab.sink { [weak self] tab in
            guard let self = self else { return }
            self.navigationItem.title = consoleIdentifiersAndNamesMap[tab]
        }
        self.loadIntoContainer(.console(consoleId: consoleId, title: console.name), newVC: UIHostingController(rootView: consolesView))
    }

    func didTapCollection(with collection: Int) { /* TODO: collections */ }
}

#endif
