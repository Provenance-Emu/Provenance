import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
// Make sure this import is correct if needed
// import PVUIBase.SwiftUI.DeltaSkins.Views

extension PVEmulatorViewController {

    /// Set up the DeltaSkin view if enabled in settings
    @objc public func setupDeltaSkinView() async throws {
        // Check if DeltaSkins are enabled
        let useDeltaSkins = true // UserDefaults.standard.bool(forKey: "useDeltaSkins")
        print("Delta Skin setting: \(useDeltaSkins)")

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

            // Print available skins
            if let systemId = game.system?.systemIdentifier {
                // Get all available skins synchronously
                let allSkins = try! await DeltaSkinManager.shared.availableSkins()
                print("Available skins (sync): \(allSkins.count) total")

                // Get skins for this system synchronously
                let systemSkins = await DeltaSkinManager.shared.availableSkinsSync(for: systemId)
                print("Skins for \(systemId) (sync): \(systemSkins.count)")

                // Print the system skins
                for skin in systemSkins {
                    print("  - \(skin.name) (for \(systemId))")
                }

                // Start an async task to get more skin info
                Task {
                    do {
                        let asyncSkins = try await DeltaSkinManager.shared.skins(for: systemId)
                        print("Async skins for \(systemId): \(asyncSkins.count)")

                        if let skinToUse = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                            print("Skin to use: \(skinToUse.identifier)")
                        } else {
                            print("No skin to use for \(systemId)")
                        }
                    } catch {
                        print("Error getting skins: \(error)")
                    }
                }
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
                print("Removed existing skin view")
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
            print("Added skin view below game screen")
        } else {
            view.addSubview(skinView.view)
            print("Added skin view (no game screen found)")
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
