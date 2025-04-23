//
//  PVRootViewController+PVMenuDelegate.swift
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
import PVFeatureFlags
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
            // Use Task to handle the async call
            Task {
                await gameImporter.clearCompleted()
            }
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

        // Ensure we're on the main thread when checking the feature flag
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let isEnabled = PVFeatureFlagsManager.shared.inAppFreeROMs
            print("Checking inAppFreeROMs in showImportOptionsAlert: \(isEnabled)")

            if isEnabled {
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
            }

            if let presentedViewController = self.presentedViewController {
                presentedViewController.present(actionSheet, animated: true, completion: nil)
            } else {
                self.present(actionSheet, animated: true, completion: nil)
            }
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
                    // Use Task to handle the async call
                    Task {
                        await gameImporter.clearCompleted()
                    }
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
        // Use Task to handle the async call
        Task {
            await AppState.shared.gameImporter?.clearCompleted()
            // Ensure UI updates happen on the main thread
            await MainActor.run {
                self.dismiss(animated: true)
            }
        }
    }

    public func addImportsAction() {
        self.showImportOptionsAlert()
    }

    public func forceImportsAction() {
        // Use Task to handle async operations
        Task {
            //reset the status of each item that conflict or failed so we can try again.
            let importQueue = await GameImporter.shared.importQueue
            for item in importQueue {
                if (item.status == .failure || item.status == .conflict || item.status == .partial) {
                    item.status = .queued
                }
            }

            GameImporter.shared.startProcessing()
        }
    }

    public func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem) {
        // Start processing if we're not already processing
        if GameImporter.shared.processingState == .idle {
            GameImporter.shared.startProcessing()
        } else if GameImporter.shared.processingState == .paused {
            // If paused, just process this specific item
            Task {
                await GameImporter.shared.processItem(item)
            }
        }
    }
}
