import UIKit
import SwiftUI
import PVUIBase
#if canImport(FreemiumKit)
import FreemiumKit
#endif

public class SwiftUISettingsViewControllerFactory: PVSettingsViewControllerFactory {
    public init() {}

    @MainActor
    public func makeSettingsViewController(
        conflictsController: PVGameLibraryUpdatesController,
        menuDelegate: PVMenuDelegate,
        dismissAction: @escaping () -> Void
    ) -> UIViewController {
        let settingsView = PVSettingsView(
            conflictsController: conflictsController,
            menuDelegate: menuDelegate,
            dismissAction: dismissAction
        )
//        .environmentObject(AppState.shared.libraryUpdatesController!)
        #if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
        #endif
        return UIHostingController(rootView: settingsView)
    }
}
