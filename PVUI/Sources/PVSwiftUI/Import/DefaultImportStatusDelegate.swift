import PVUIBase
import UIKit
import PVSystems

@MainActor
class DefaultImportStatusDelegate: ImportStatusDelegate {
    private weak var viewController: UIViewController?
    private var updatesController: PVGameLibraryUpdatesController

    init(from viewController: UIViewController?, updatesController: PVGameLibraryUpdatesController) {
        self.viewController = viewController
        self.updatesController = updatesController
    }

    func dismissAction() {
        // Default implementation
        AppState.shared.gameImporter?.clearCompleted()
    }

    func addImportsAction() {
        guard let viewController = viewController else { return }

        // Create and show import options
        let presenter = SwiftUIImportOptionsPresenter()
        presenter.showImportOptions(
            from: viewController,
            updatesController: updatesController,
            sourceBarButtonItem: nil,
            sourceView: viewController.view
        )
    }

    func forceImportsAction() {
        // Default implementation
        GameImporter.shared.importQueue.forEach { item in
            if (item.status == .failure || item.status == .conflict || item.status == .partial) {
                item.status = .queued
            }
        }

        GameImporter.shared.startProcessing()
    }

    // Add method to handle system selection
    func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem) {
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
