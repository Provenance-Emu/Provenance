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

#if canImport(FreemiumKit)
import FreemiumKit
#endif

#if canImport(PVWebServer)
import PVWebServer
#endif
#if canImport(SafariServices)
import SafariServices
#endif

// MARK: - Menu Delegate

public protocol PVMenuDelegate: AnyObject {
    func didTapImports()
    func didTapSettings()
    func didTapHome()
    func didTapAddGames()
    func didTapConsole(with consoleId: String)
    func didTapCollection(with collection: Int)
    func closeMenu()
}
@available(iOS 14, tvOS 14, *)
extension PVRootViewController: PVMenuDelegate {

    public func didTapImports() {
        guard let gameImporter = AppState.shared.gameImporter else {
            ELOG("No game importer")
            presentError("Importer could not be loaded", source: self.view)
            return
        }

        NotificationCenter.default.post(name: NSNotification.Name.PVReimportLibrary, object: nil)

        let settingsView = ImportStatusView(updatesController:updatesController, gameImporter: gameImporter, delegate: self) {
            gameImporter.clearCompleted()
        }

        let hostingController = UIHostingController(rootView: settingsView)
        let navigationController = UINavigationController(rootViewController: hostingController)

        self.closeMenu()
        self.present(navigationController, animated: true)
    }

    public func didTapSettings() {
        let settingsView = PVSettingsView(
            conflictsController: updatesController,
            menuDelegate: self,
            dismissAction: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        .environmentObject(updatesController)
        #if canImport(FreemiumKit)
            .environmentObject(FreemiumKit.shared)
        #endif

        let hostingController = UIHostingController(rootView: settingsView)
        let navigationController = UINavigationController(rootViewController: hostingController)

        self.closeMenu()
        self.present(navigationController, animated: true)
    }

    public func didTapAddGames() {
        self.closeMenu()


        self.showImportOptionsAlert()
    }

    public func showImportOptionsAlert() {
#if os(iOS) || os(tvOS)
        /// from PVGameLibraryViewController#getMoreROMs
        let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)

#if !os(tvOS)
        actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in

            let documentPicker: UIDocumentPickerViewController
            let utis: [UTType] = [UTType.rom, UTType.artwork, UTType.savestate, UTType.zip, UTType.sevenZipArchive, UTType.gzip, UTType.image, UTType.jpeg, UTType.png, UTType.bios, UTType.data, UTType.rar]

            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: utis, asCopy: true)
            documentPicker.allowsMultipleSelection = true
            documentPicker.delegate = self
            self.dismiss(animated: true)
            self.present(documentPicker, animated: true, completion: nil)
        }))
#endif

        #if canImport(PVWebServer)
        let webServerAction = UIAlertAction(title: "Web Server", style: .default, handler: { _ in
            self.dismiss(animated: true)
            self.startWebServer()
        })

        actionSheet.addAction(webServerAction)
        #endif
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        actionSheet.preferredContentSize = CGSize(width: 300, height: 150)

        actionSheet.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
//        actionSheet.popoverPresentationController?.sourceView = self.view
//        actionSheet.popoverPresentationController?.sourceRect = self.view?.bounds ?? UIScreen.main.bounds


        // Add Free ROMs option
        actionSheet.addAction(UIAlertAction(title: "Free ROMs", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true) {
                let freeROMsView = FreeROMsView(
                    onROMDownloaded: { rom, tempURL in
                        // Handle the downloaded ROM
                        DLOG("Recieved downloaded file at: \(tempURL)")
                        self?.updatesController.handlePickedDocuments([tempURL])
                    },
                    onDismiss: {
                        // Optional: Handle dismiss if needed
                        self?.didTapImports()
                    }
                )

                let hostingController = UIHostingController(rootView: freeROMsView)
                let navigationController = UINavigationController(rootViewController: hostingController)
                self?.present(navigationController, animated: true)
            }
        }))

        if let presentedViewController = presentedViewController {
            presentedViewController.present(actionSheet, animated: true, completion: nil)
        } else {
            present(actionSheet, animated: true, completion: nil)
        }
        #endif
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
        guard let ipURL: String = PVWebServer.shared.urlString else {
            ELOG("`PVWebServer.shared.urlString` was nil")
            return
        }
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

#if !os(tvOS)
extension PVRootViewController: UIDocumentPickerDelegate {
    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        updatesController.handlePickedDocuments(urls)
        let gameImporter = AppState.shared.gameImporter ?? GameImporter.shared
        // Re-present the ImportStatusView
        if !urls.isEmpty {
            DispatchQueue.main.async {
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

    public func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        ILOG("Document picker was cancelled")
    }
}
#endif

extension PVRootViewController: ImportStatusDelegate {
    public func dismissAction() {
        AppState.shared.gameImporter?.clearCompleted()
        self.dismiss(animated: true)
    }

    public func addImportsAction() {
        self.showImportOptionsAlert()
    }

    public func forceImportsAction() {
        //reset the status of each item that conflict or failed so we can try again.
        GameImporter.shared.importQueue.forEach { item in
            if (item.status == .failure || item.status == .conflict || item.status == .partial) {
                item.status = .queued
            }
        }

        GameImporter.shared.startProcessing()
    }
}
