import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary

/// A simple container view for Delta skins
class DeltaSkinContainerView: UIView {

    /// Create a container view with the emulator skin
    static func create(
        game: PVGame,
        core: PVEmulatorCore,
        inputHandler: DeltaSkinInputHandler,
        preselectedSkinIdentifier: String? = nil,
        onInitialSkinResolutionComplete: (() -> Void)? = nil,
        onSkinLoaded: @escaping () -> Void,
        onRefreshRequested: @escaping () -> Void,
        virtualInputState: VirtualInputState? = nil
    ) -> DeltaSkinContainerView {
        // Create the container view
        let containerView = DeltaSkinContainerView(frame: .zero)

        // CRITICAL: Configure view for transparency
        containerView.backgroundColor = UIColor.clear
        containerView.isOpaque = false

        // Create the wrapper view
        let wrapperView = EmulatorWrapperView(
            game: game,
            coreInstance: core,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            preselectedSkinIdentifier: preselectedSkinIdentifier,
            onInitialSkinResolutionComplete: onInitialSkinResolutionComplete,
            inputHandler: inputHandler,
            virtualInputState: virtualInputState
        )

        // Create the hosting controller
        let hostingController = UIHostingController(rootView: wrapperView)

        // Configure the hosting controller's view
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.isOpaque = false

        // Add the hosting controller's view as a subview
        containerView.addSubview(hostingController.view)

        // Store the hosting controller to prevent it from being deallocated
        containerView.hostingController = hostingController

        // Log successful creation
        print("Created DeltaSkinContainerView with transparent background")

        return containerView
    }

    // Store the hosting controller to prevent it from being deallocated
    private var hostingController: UIViewController?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        // Ensure transparency is maintained after move
        self.backgroundColor = UIColor.clear
        self.isOpaque = false

        if let hostView = hostingController?.view {
            hostView.backgroundColor = UIColor.clear
            hostView.isOpaque = false
            // CRITICAL: Update hosting controller's view frame when container moves to superview
            // This ensures the SwiftUI view is properly sized
            hostView.frame = self.bounds
            hostView.isHidden = false
            hostView.alpha = 1.0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // CRITICAL: Update hosting controller's view frame whenever container layout changes
        // This ensures the SwiftUI view stays properly sized, especially on iPad
        if let hostView = hostingController?.view {
            hostView.frame = self.bounds
            hostView.isHidden = false
            hostView.alpha = 1.0
        }
    }
}
