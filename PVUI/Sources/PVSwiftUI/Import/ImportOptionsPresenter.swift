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
                                    gameImporter.clearCompleted()
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
                        gameImporter.clearCompleted()
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
        // Implementation of server active alert
    }

    private func showWebServerErrorAlert(from viewController: UIViewController, sourceView: UIView?, barButtonItem: UIBarButtonItem?) {
        // Implementation of web server error alert
    }
}
