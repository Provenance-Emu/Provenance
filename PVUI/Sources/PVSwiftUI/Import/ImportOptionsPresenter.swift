import UIKit
import PVUIBase
import SwiftUI
import UniformTypeIdentifiers
#if canImport(PVWebServer)
import PVWebServer
#endif
import PVFeatureFlags

public class SwiftUIImportOptionsPresenter: PVImportOptionsPresenter {
    public init() {}

    @MainActor
    public func showImportOptions(
        from viewController: UIViewController,
        updatesController: PVGameLibraryUpdatesController,
        sourceBarButtonItem: UIBarButtonItem?,
        sourceView: UIView?
    ) {
        let actionSheet = UIAlertController(title: "Select Import Source", message: nil, preferredStyle: .actionSheet)

        #if !os(tvOS)
        actionSheet.addAction(UIAlertAction(title: "Cloud & Local Files", style: .default, handler: { _ in
            let documentPicker: UIDocumentPickerViewController
            let utis: [UTType] = [UTType.rom, UTType.artwork, UTType.savestate, UTType.zip, UTType.sevenZipArchive, UTType.gzip, UTType.image, UTType.jpeg, UTType.png, UTType.bios, UTType.data, UTType.rar]

            documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: utis, asCopy: true)
            documentPicker.allowsMultipleSelection = true
            documentPicker.delegate = viewController as? UIDocumentPickerDelegate
            viewController.dismiss(animated: true)
            viewController.present(documentPicker, animated: true, completion: nil)
        }))
        #endif

        #if canImport(PVWebServer)
        actionSheet.addAction(UIAlertAction(title: "Web Server", style: .default, handler: { _ in
            viewController.dismiss(animated: true)
            if PVWebServer.shared.startServers() {
                self.showServerActiveAlert(from: viewController, sourceView: sourceView, barButtonItem: sourceBarButtonItem)
            } else {
                self.showWebServerErrorAlert(from: viewController, sourceView: sourceView, barButtonItem: sourceBarButtonItem)
            }
        }))
        #endif

        if PVFeatureFlagsManager.shared.inAppFreeROMs {
            actionSheet.addAction(UIAlertAction(title: "Free ROMs", style: .default, handler: { _ in
                viewController.dismiss(animated: true) {
                    let freeROMsView = FreeROMsView(
                        onROMDownloaded: { rom, tempURL in
                            updatesController.handlePickedDocuments([tempURL])
                        },
                        onDismiss: {
                            let delegate = viewController as? ImportStatusDelegate ?? DefaultImportStatusDelegate(
                                from: viewController,
                                updatesController: updatesController
                            )
                            // Show import status view
                            let gameImporter = AppState.shared.gameImporter ?? GameImporter.shared
                            let settingsView = ImportStatusView(
                                updatesController: updatesController,
                                gameImporter: gameImporter,
                                delegate: delegate,
                                dismissAction: {
                                    // Use Task to handle the async call
                                    Task {
                                        await gameImporter.clearCompleted()
                                    }
                                }
                            )
                            let hostingController = UIHostingController(rootView: settingsView)
                            let navigationController = UINavigationController(rootViewController: hostingController)
                            viewController.present(navigationController, animated: true)
                        }
                    )

                    let hostingController = UIHostingController(rootView: freeROMsView)
                    let navigationController = UINavigationController(rootViewController: hostingController)
                    viewController.present(navigationController, animated: true)
                }
            }))
        }

        actionSheet.addAction(UIAlertAction(title: "Import Queue", style: .default, handler: { _ in
            viewController.dismiss(animated: true) {
                let delegate = viewController as? ImportStatusDelegate ?? DefaultImportStatusDelegate(
                    from: viewController,
                    updatesController: updatesController
                )
                let gameImporter = AppState.shared.gameImporter ?? GameImporter.shared
                let importStatusView = ImportStatusView(
                    updatesController: updatesController,
                    gameImporter: gameImporter,
                    delegate: delegate,
                    dismissAction: {
                        // Use Task to handle the async call
                        Task {
                            await gameImporter.clearCompleted()
                        }
                    }
                )
                let hostingController = UIHostingController(rootView: importStatusView)
                let navigationController = UINavigationController(rootViewController: hostingController)
                viewController.present(navigationController, animated: true)
            }
        }))

        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil))
        actionSheet.preferredContentSize = CGSize(width: 300, height: 150)

        actionSheet.popoverPresentationController?.barButtonItem = sourceBarButtonItem
        if let sourceView = sourceView {
            actionSheet.popoverPresentationController?.sourceView = sourceView
            actionSheet.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        viewController.present(actionSheet, animated: true)
    }

    private func showServerActiveAlert(from viewController: UIViewController, sourceView: UIView?, barButtonItem: UIBarButtonItem?) {
        // Build the connection details message
        var message = "Connect to this device using a web browser to transfer files.\n\n"

        if let webURL = PVWebServer.shared.urlString,
           let webDavURL = PVWebServer.shared.webDavURLString {
            message += "Web Interface:\n"
            message += "\(webURL)\n\n"
            message += "WebDAV Access:\n"
            message += "\(webDavURL)\n\n"
            message += "Note: Both devices must be on the same network."
        } else {
            message += "Unable to determine server URLs. Please check your network connection."
        }

        let alert = UIAlertController(
            title: "Web Server Active",
            message: message,
            preferredStyle: .alert
        )
        alert.popoverPresentationController?.barButtonItem = barButtonItem
        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView?.bounds ?? UIScreen.main.bounds
        alert.preferredContentSize = CGSize(width: 300, height: 150)

        #if os(tvOS)
        // tvOS specific actions
        alert.addAction(UIAlertAction(title: "Hide", style: .default))

        alert.addAction(UIAlertAction(title: "Stop", style: .destructive) { _ in
            PVWebServer.shared.stopServers()
        })
        #else
        // Non-tvOS actions
        alert.addAction(UIAlertAction(title: "Stop", style: .cancel) { _ in
            PVWebServer.shared.stopServers()
        })

        // View action - not available on tvOS
        let viewAction = UIAlertAction(title: "View", style: .default) { _ in
            if let url = PVWebServer.shared.url {
                UIApplication.shared.open(url)
            }
        }
        alert.addAction(viewAction)
        alert.preferredAction = viewAction
        #endif

        viewController.present(alert, animated: true)
    }

    private func showWebServerErrorAlert(from viewController: UIViewController, sourceView: UIView?, barButtonItem: UIBarButtonItem?) {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS)
        let message = "Check your network connection or settings and free up ports: 8080, 8081."
#else
        let message = "Check your network connection or settings and free up ports: 80, 81."
#endif
        let alert = UIAlertController(
            title: "Unable to start web server!",
            message: message,
            preferredStyle: .alert
        )
        alert.preferredContentSize = CGSize(width: 300, height: 150)
        alert.popoverPresentationController?.barButtonItem = barButtonItem
        alert.popoverPresentationController?.sourceView = sourceView
        alert.popoverPresentationController?.sourceRect = sourceView?.bounds ?? UIScreen.main.bounds
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
}
