import UIKit

public protocol PVSettingsViewControllerFactory {
    func makeSettingsViewController(
        conflictsController: PVGameLibraryUpdatesController,
        menuDelegate: PVMenuDelegate,
        dismissAction: @escaping () -> Void
    ) -> UIViewController
}
