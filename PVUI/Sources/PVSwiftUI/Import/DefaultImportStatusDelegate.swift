import PVUIBase
import UIKit

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
}
