import UIKit

public protocol PVImportOptionsPresenter {
    func showImportOptions(
        from viewController: UIViewController,
        updatesController: PVGameLibraryUpdatesController,
        sourceBarButtonItem: UIBarButtonItem?,
        sourceView: UIView?
    )
}
