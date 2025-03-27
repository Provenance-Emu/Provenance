import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary

extension PVEmulatorViewController {
    /// Initialize with skin support option
    public convenience init(game: PVGame, core: PVEmulatorCore, useSkin: Bool = false) {
        self.init(game: game, core: core)

        if useSkin {
            // Replace the default view with our skin-enabled view
            setupSkinView(game: game, core: core)
        }
    }

    /// Set up the skin view
    private func setupSkinView(game: PVGame, core: PVEmulatorCore) {
        // Create the skin view
        let skinView = UIHostingController(
            rootView: EmulatorWithSkinView(game: game, coreInstance: core)
                .ignoresSafeArea(.all)
        )

        // Add the skin view as a child view controller
        addChild(skinView)
        skinView.view.frame = view.bounds
        skinView.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skinView.view)
        skinView.didMove(toParent: self)

        // Store a reference to the hosting controller
        objc_setAssociatedObject(
            self,
            &AssociatedKeys.skinHostingController,
            skinView,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

// Associated keys for storing references
private struct AssociatedKeys {
    static var skinHostingController = "skinHostingController"
}
