//
//  PVRootViewController.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
#if canImport(Combine)
import Foundation
import UIKit
import SwiftUI
import SideMenu
import RealmSwift
import Combine

// PVRootViewController serves as a UIKit parent for child SwiftUI menu views.

// The goal one day may be to move entirely to a SwiftUI app life cycle, but under
// current circumstances (iOS 11 deployment target, some critical logic being coupled
// to UIViewControllers, etc.) it will be more easier to integrate by starting here
// and porting the remaining views/logic over to as conditions change moving forward.

enum PVNavOption {
    case settings
    case home
    case console(title: String)
    
    var title: String {
        switch self {
        case .settings: return "Settings"
        case .home: return "Home"
        case .console(let title):  return title
        }
    }
}

public protocol PVRootDelegate: GameLaunchingViewController {
    func attemptToDelete(game: PVGame)
}
  
@available(iOS 14.0.0, *)
class PVRootViewController: UIViewController, GameLaunchingViewController, GameSharingViewController {
    
    var menu: PVSideMenu!
    let containerView = UIView()
    
    lazy var menuButton = UIBarButtonItem.makeFromCustomView(image: UIImage.symbolNameWithFallBack(name: "line.3.horizontal")!, target: self, action: #selector(PVRootViewController.showMenu))
    
    var updatesController: PVGameLibraryUpdatesController!
    var gameLibrary: PVGameLibrary!
    var gameImporter: GameImporter!
    
    let disposeBag = DisposeBag()
    var selectedTabCancellable: AnyCancellable?
    
    lazy var consolesWrapperViewDelegate = ConsolesWrapperViewDelegate()
    
    static func instantiate(updatesController: PVGameLibraryUpdatesController, gameLibrary: PVGameLibrary, gameImporter: GameImporter) -> PVRootViewController {
        let controller = PVRootViewController()
        controller.updatesController = updatesController
        controller.gameLibrary = gameLibrary
        controller.gameImporter = gameImporter
        return controller
    }
    
    override func viewDidLoad() {
        menu = loadSideMenu()
        
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = menuButton
        
        self.view.addSubview(containerView)
        self.fillParentView(child: containerView, parent: self.view)
        
        let homeView = HomeView(gameLibrary: self.gameLibrary, delegate: self)
        self.loadIntoContainer(.home, newVC: UIHostingController(rootView: homeView))
        
        let hud = MBProgressHUD(view: view)!
        hud.isUserInteractionEnabled = false
        view.addSubview(hud)
        updatesController.hudState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { state in
                switch state {
                case .hidden:
                    hud.hide(true)
                case .title(let title):
                    hud.show(true)
                    hud.mode = .indeterminate
                    hud.labelText = title
                case .titleAndProgress(let title, let progress):
                    hud.show(true)
                    hud.mode = .annularDeterminate
                    hud.progress = progress
                    hud.labelText = title
                }
            })
            .disposed(by: disposeBag)

//        updatesController.conflicts
//            .map { !$0.isEmpty }
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { hasConflicts in
//                self.updateConflictsButton(hasConflicts)
//                if hasConflicts {
//                    self.showConflictsAlert()
//                }
//            })
//            .disposed(by: disposeBag)
    }
    
    deinit {
        selectedTabCancellable?.cancel()
    }
    
    @objc func showMenu() {
        menu = loadSideMenu()
        present(menu, animated: true, completion: nil)
    }
    
    func loadSideMenu() -> PVSideMenu {
        let hostingController = UIHostingController(rootView: SideMenuView(consoles: nil, delegate: self))
        let menu = PVSideMenu(rootViewController: hostingController)
         SideMenuManager.default.leftMenuNavigationController = menu
         SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: self.containerView, forMenu: .left)
        return menu
    }
    
    func loadIntoContainer(_ navItem: PVNavOption, newVC: UIViewController) {
        // remove old view
        self.containerView.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
        // set title
        self.navigationItem.title = navItem.title
        // set bar button items (if any)
        switch navItem {
        case .settings, .home, .console: break
        }
        // load new view
        self.addChildViewController(newVC, toContainerView: self.containerView)
        self.fillParentView(child: newVC.view, parent: self.containerView)
    }
}

// MARK: - Menu Delegate

protocol PVMenuDelegate {
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
    func didTapToggleNewUI()
}

@available(iOS 14.0.0, *)
extension PVRootViewController: PVMenuDelegate {
    func didTapSettings() {
        guard
            let settingsNav = UIStoryboard(name: "Provenance", bundle: nil).instantiateViewController(withIdentifier: "settingsNavigationController") as? UINavigationController,
            let settingsVC = settingsNav.topViewController as? PVSettingsViewController
        else { return }
        
        settingsVC.conflictsController = updatesController
        menu.dismiss(animated: true, completion: nil)
        // modal
//        menu.dismiss(animated: true, completion: {
//            self.present(settingsNav, animated: true)
//        })
        // inline (still doesn't show all bar button items)
        self.loadIntoContainer(.settings, newVC: settingsVC)
    }

    func didTapHome() {
        menu.dismiss(animated: true, completion: nil)
        self.navigationItem.title = "Home"
        let homeView = HomeView(gameLibrary: self.gameLibrary, delegate: self)
        self.loadIntoContainer(.home, newVC: UIHostingController(rootView: homeView))
    }

    func didTapAddGames() {
        menu.dismiss(animated: true, completion: nil)

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
    }

    func didTapConsole(with consoleId: String) {
        menu.dismiss(animated: true, completion: nil)
        guard let console = try? Realm().object(ofType: PVSystem.self, forPrimaryKey: consoleId) else { return }
        let consoles = try? Realm().objects(PVSystem.self).filter("games.@count > 0").sorted(byKeyPath: "name")
        guard let consoles = consoles else { return }
        consolesWrapperViewDelegate.selectedTab = console.identifier
        let consolesView = ConsolesWrapperView(consolesWrapperViewDelegate: consolesWrapperViewDelegate, gameLibrary: self.gameLibrary, rootDelegate: self, consoles: consoles)
        selectedTabCancellable = consolesWrapperViewDelegate.$selectedTab.sink { [weak self] tab in
            guard let self = self else { return }
            self.navigationItem.title = tab // TODO: map PVSystem identifier to console name
        }
        self.loadIntoContainer(.console(title: console.name), newVC: UIHostingController(rootView: consolesView))
    }

    func didTapCollection(with collection: Int) { /* TODO: collections */ }
    
    func didTapToggleNewUI() {
        menu.dismiss(animated: true, completion: nil)
        
        PVSettingsModel.shared.debugOptions.useSwiftUI.toggle()
        
        let alert = UIAlertController(title: "Preference Updated", message: "Next time Provence starts, it will use the \(PVSettingsModel.shared.debugOptions.useSwiftUI == true ? "new" : "old") UI", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Helpers

@available(iOS 14.0.0, *)
extension PVRootViewController {
    
    func addChildViewController(_ child: UIViewController, toContainerView containerView: UIView) {
        addChild(child)
        containerView.addSubview(child.view)
        child.didMove(toParent: self)
    }
    
    func fillParentView(child: UIView, parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }
    
}

// MARK: - PVControllerMethodsDelegate methods

@available(iOS 14.0.0, *)
extension PVRootViewController: PVRootDelegate {
    func attemptToDelete(game: PVGame) {
        do {
            try self.delete(game: game)
        } catch {
            self.presentError(error.localizedDescription)
        }
    }
}

// MARK: - Methods from PVGameLibraryViewController

@available(iOS 14.0.0, *)
extension PVRootViewController {
    func delete(game: PVGame) throws {
        try RomDatabase.sharedInstance.delete(game: game)
    }
}

// MARK: - UIDocumentPickerDelegate
@available(iOS 14.0.0, *)
extension PVRootViewController: UIDocumentPickerDelegate {
    // copied from PVGameLibraryViewController#documentPicker()
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // If directory, map out sub directories if folder
        let urls: [URL] = urls.compactMap { (url) -> [URL]? in
            if url.hasDirectoryPath {
                ILOG("Trying to import directory \(url.path). Scanning subcontents")
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    let subFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, URLResourceKey.parentDirectoryURLKey, URLResourceKey.fileSecurityKey], options: .skipsHiddenFiles)
                    url.stopAccessingSecurityScopedResource()
                    return subFiles
                } catch {
                    ELOG("Subdir scan failed. \(error)")
                    return [url]
                }
            } else {
                return [url]
            }
        }.joined().map { $0 }

        let sortedUrls = PVEmulatorConfiguration.sortImportURLs(urls: urls)

        let importPath = PVEmulatorConfiguration.Paths.romsImportPath

        sortedUrls.forEach { url in
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // Doesn't seem we need access in dev builds?
            _ = url.startAccessingSecurityScopedResource()

            let fileName = url.lastPathComponent
            let destination: URL
            destination = importPath.appendingPathComponent(fileName, isDirectory: url.hasDirectoryPath)
            do {
                // Since we're in UIDocumentPickerModeImport, these URLs are temporary URLs so a move is what we want
                try FileManager.default.moveItem(at: url, to: destination)
                ILOG("Document picker to moved file from \(url.path) to \(destination.path)")
            } catch {
                ELOG("hsllo::\(error)")
                ELOG("Failed to move file from \(url.path) to \(destination.path)")
            }
        }

        // Test for moving directory subcontents
        //                    if #available(iOS 9.0, *) {
        //                        if url.hasDirectoryPath {
        //                            ILOG("Tryingn to import directory \(url.path)")
        //                            let subFiles = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        //                            for subFile in subFiles {
        //                                _ = subFile.startAccessingSecurityScopedResource()
        //                                try FileManager.default.moveItem(at: subFile, to: destination)
        //                                subFile.stopAccessingSecurityScopedResource()
        //                                ILOG("Moved \(subFile.path) to \(destination.path)")
        //                            }
        //                        } else {
        //                            try FileManager.default.moveItem(at: url, to: destination)
        //                        }
        //                    } else {
        //                        try FileManager.default.moveItem(at: url, to: destination)
        //                    }
//                } catch {
//                    ELOG("Failed to move file from \(url.path) to \(destination.path)")
//                }
//            } else {
//                ELOG("Wasn't granded access to \(url.path)")
//            }
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        ILOG("Document picker was cancelled")
    }
}


#endif
#endif
