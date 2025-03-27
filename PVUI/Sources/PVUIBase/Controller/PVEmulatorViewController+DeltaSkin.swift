import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
// Make sure this import is correct if needed
// import PVUIBase.SwiftUI.DeltaSkins.Views

extension PVEmulatorViewController {

    /// Set up the DeltaSkin view if enabled in settings
    @objc public func setupDeltaSkinView() {
        // Check if DeltaSkins are enabled
        let useDeltaSkins = UserDefaults.standard.bool(forKey: "useDeltaSkins")

        if useDeltaSkins {
            // Create and add DeltaSkin view
            createSkinView()

            // Hide the standard controls
            hideStandardControls()

            print("Delta Skin enabled and loaded")
            print("Game: \(game.title)")
            print("System: \(game.system?.name ?? "Unknown")")
            if let identifier = game.system?.systemIdentifier {
                print("System Identifier: \(identifier)")
            }
        } else {
            print("Delta Skin not enabled in settings")
        }
    }

    /// Create the skin view
    private func createSkinView() {
        // Remove any existing skin views
        for subview in view.subviews {
            if let hostingController = subview.next as? UIHostingController<EmulatorWithSkinView> {
                hostingController.willMove(toParent: nil)
                subview.removeFromSuperview()
                hostingController.removeFromParent()
            }
        }

        // Create the skin view
        let skinView = UIHostingController(
            rootView: EmulatorWithSkinView(game: game, coreInstance: core)
                .ignoresSafeArea(.all)
        )

        // Add the skin view as a child view controller
        addChild(skinView)
        skinView.view.frame = view.bounds
        skinView.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add the view to the hierarchy - make sure it's below the game screen
        if let gameScreenView = view.subviews.first {
            view.insertSubview(skinView.view, belowSubview: gameScreenView)
        } else {
            view.addSubview(skinView.view)
        }

        skinView.didMove(toParent: self)

        print("Added skin view to view hierarchy")
    }

    /// Hide the standard controller buttons
    private func hideStandardControls() {
        // Find the controller view controller
        for childVC in children {
            if let controllerVC = childVC as? UIViewController {
                // Hide all buttons and controls
                let buttons = controllerVC.view.subviews.filter { $0 is UIButton || $0 is UIControl }
                buttons.forEach { $0.isHidden = true }

                print("Hidden standard controls: \(buttons.count) buttons")
            }
        }
    }
}
