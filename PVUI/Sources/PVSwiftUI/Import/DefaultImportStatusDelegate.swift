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
        // Use Task to handle the async call
        Task {
            await AppState.shared.gameImporter?.clearCompleted()
        }
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
        // Use Task to handle async operations
        Task {
            // Get the import queue asynchronously
            let importQueue = await GameImporter.shared.importQueue
            
            // Update the status of items
            importQueue.filter({$0.status.canBeRequeued}).forEach { item in
                item.requeue()
            }
            
            // Start processing
            GameImporter.shared.startProcessing()
        }
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
