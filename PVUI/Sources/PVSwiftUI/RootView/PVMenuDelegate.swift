//
//  PVMenuDelegate.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/15/24.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import PVUIKit
import UIKit
#endif
import RxSwift
import PVUIBase
import SwiftUI
import RealmSwift
import Combine
import PVLibrary
import PVRealm
import PVPrimitives
import PVLogging
import UniformTypeIdentifiers

#if canImport(PVWebServer)
import PVWebServer
#endif
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - Menu Delegate

public protocol PVMenuDelegate: AnyObject {
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
}

@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVMenuDelegate {
    public func didTapSettings() {
        #if os(iOS)

        guard
            let settingsNav = UIStoryboard(name: "Provenance", bundle: PVUIKit.BundleLoader.bundle).instantiateViewController(withIdentifier: "settingsNavigationController") as? UINavigationController,
            let settingsVC = settingsNav.topViewController as? PVSettingsViewController
        else { return }

        settingsVC.conflictsController = updatesController
        self.closeMenu()
        self.present(settingsNav, animated: true)
        #elseif os(tvOS)
        // TODO: load tvOS settings from bundle
        #endif
    }

    public func didTapHome() {
        self.closeMenu()
        let homeView = HomeView(gameLibrary: self.gameLibrary, delegate: self)
        self.loadIntoContainer(.home, newVC: UIHostingController(rootView: homeView))
    }

    public func didTapAddGames() {
        self.closeMenu()
        #if os(iOS) || os(tvOS)

        /// from PVGameLibraryViewController#getMoreROMs
        let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)
#if !os(tvOS)
        actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in

            let documentPicker: UIDocumentPickerViewController
            if #available(iOS 14, *) {
                let utis: [UTType] = [UTType.rom, UTType.artwork, UTType.savestate, UTType.zip, UTType.sevenZipArchive, UTType.gzip, UTType.image, UTType.jpeg, UTType.png, UTType.bios, UTType.data, UTType.rar]

                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: utis, asCopy: true)
            } else {
                let utis: [UTI] = [UTI.rom, UTI.artwork, UTI.savestate, UTI.zipArchive, UTI.sevenZipArchive, UTI.gnuZipArchive, UTI.image, UTI.jpeg, UTI.png, UTI.bios, UTI.data, UTI.rar]

                let extensions = utis.map { $0.rawValue }
                documentPicker = UIDocumentPickerViewController(documentTypes: extensions, in: .import)
            }
            documentPicker.allowsMultipleSelection = true
            documentPicker.delegate = self
            self.present(documentPicker, animated: true, completion: nil)
        }))
#endif

        #if canImport(PVWebServer)
        let webServerAction = UIAlertAction(title: "Web Server", style: .default, handler: { _ in
            self.startWebServer()
        })

        actionSheet.addAction(webServerAction)
        #endif
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        actionSheet.preferredContentSize = CGSize(width: 300, height: 150)
        
        actionSheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
//        actionSheet.popoverPresentationController?.sourceView = self.view
//        actionSheet.popoverPresentationController?.sourceRect = self.view?.bounds ?? UIScreen.main.bounds

        present(actionSheet, animated: true, completion: nil)
        #endif
    }

    public func didTapConsole(with consoleId: String) {
        self.closeMenu()

        guard let console = gameLibrary.system(identifier: consoleId) else { return }
        let consoles = gameLibrary.activeSystems

        consolesWrapperViewDelegate.selectedTab = console.identifier
        self.consoleIdentifiersAndNamesMap.removeAll()
        for console in consoles {
            self.consoleIdentifiersAndNamesMap[console.identifier] = console.name
        }
        selectedTabCancellable?.cancel()
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

    public func didTapCollection(with collection: Int) {
        /* TODO: collections */
    }

#if canImport(PVWebServer)
    func startWebServer() {
        // start web transfer service
        if PVWebServer.shared.startServers() {
            // show alert view
            showServerActiveAlert(sender: self.view, barButtonItem: navigationItem.rightBarButtonItem)
        } else {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS)
            let message = "Check your network connection or settings and free up ports: 8080, 8081."
#else
            let message = "Check your network connection or settings and free up ports: 80, 81."
#endif
            let alert = UIAlertController(title: "Unable to start web server!", message: message, preferredStyle: .alert)
            alert.preferredContentSize = CGSize(width: 300, height: 150)
            alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.view?.bounds ?? UIScreen.main.bounds
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_: UIAlertAction) -> Void in
            }))
            present(alert, animated: true) { () -> Void in }
        }
    }

    public func showServerActiveAlert(sender: UIView?, barButtonItem: UIBarButtonItem?) {
        let alert = UIAlertController(title: "Web Server Active", message: webServerAlertMessage, preferredStyle: .alert)
        alert.popoverPresentationController?.barButtonItem = barButtonItem
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender?.bounds ?? UIScreen.main.bounds
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel, handler: { (_: UIAlertAction) -> Void in
            PVWebServer.shared.stopServers()
        }))
        let viewAction = UIAlertAction(title: "View", style: .default, handler: { (_: UIAlertAction) -> Void in
            self.showServer()
        })
        alert.addAction(viewAction)
        alert.preferredAction = alert.actions.last
        present(alert, animated: true) { () -> Void in }
    }

    func showServer() {
        let ipURL: String = PVWebServer.shared.urlString
        let url = URL(string: ipURL)!
#if targetEnvironment(macCatalyst)
        UIApplication.shared.open(url, options: [:]) { completed in
            ILOG("Completed: \(completed ? "Yes":"No")")
        }
#elseif canImport(SafariServices)
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.delegate = self
        present(safariVC, animated: true) { () -> Void in }
#endif
    }
#endif
}
