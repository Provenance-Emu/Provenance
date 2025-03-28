import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary

/// A simple container view for Delta skins
class DeltaSkinContainerView: UIView {

    /// Create a container view with the emulator skin
    static func create(game: PVGame, core: PVEmulatorCore, inputHandler: DeltaSkinInputHandler, onSkinLoaded: @escaping () -> Void, onRefreshRequested: @escaping () -> Void, onMenuRequested: @escaping () -> Void) -> DeltaSkinContainerView {
        // Create the container view
        let containerView = DeltaSkinContainerView(frame: .zero)

        // Create the wrapper view
        let wrapperView = EmulatorWrapperView(
            game: game,
            coreInstance: core,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            onMenuRequested: onMenuRequested,
            inputHandler: inputHandler
        )

        // Create the hosting controller
        let hostingController = UIHostingController(rootView: wrapperView)

        // Configure the hosting controller's view
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear

        // Add the hosting controller's view as a subview
        containerView.addSubview(hostingController.view)

        // Store the hosting controller to prevent it from being deallocated
        containerView.hostingController = hostingController

        return containerView
    }

    // Store the hosting controller to prevent it from being deallocated
    private var hostingController: UIViewController?
}
