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
        ILOG("Delta Skin setting: \(useDeltaSkins)")

        if useDeltaSkins {
            // Create and add DeltaSkin view
            createSkinView()

            // Hide the standard controls
            hideStandardControls()

            DLOG("Delta Skin enabled and loaded")
            DLOG("Game: \(game.title)")
            DLOG("System: \(game.system?.name ?? "Unknown")")
            if let identifier = game.system?.systemIdentifier {
                DLOG("System Identifier: \(identifier)")
            }

            // Set up rotation notification
            setupRotationNotification()

            // Print available skins
            if let systemId = game.system?.systemIdentifier {
                // Get all available skins synchronously
                let allSkins = try! await DeltaSkinManager.shared.availableSkins()
                DLOG("Available skins (sync): \(allSkins.count) total")

                // Get skins for this system synchronously
                let systemSkins = await DeltaSkinManager.shared.availableSkinsSync(for: systemId)
                DLOG("Skins for \(systemId) (sync): \(systemSkins.count)")

                // Print the system skins
                for skin in systemSkins {
                    DLOG("  - \(skin.name) (for \(systemId))")
                }

                // Start an async task to get more skin info
                Task {
                    do {
                        let asyncSkins = try await DeltaSkinManager.shared.skins(for: systemId)
                        DLOG("Async skins for \(systemId): \(asyncSkins.count)")

                        if let skinToUse = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                            DLOG("Skin to use: \(skinToUse.identifier)")
                        } else {
                            DLOG("No skin to use for \(systemId)")
                        }
                    } catch {
                        ELOG("Error getting skins: \(error)")
                    }
                }
            }
        } else {
            ELOG("Delta Skin not enabled in settings")
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
                DLOG("Removed existing skin view")
            }
        }

        // Get the GPU view from the gpuViewController
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Ensure the GPU view is properly sized and positioned
        gameScreenView.frame = view.bounds
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Make sure the GPU view is visible
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Set the z-position to ensure it's below the skin but visible
        gameScreenView.layer.zPosition = 10

        // Add a colored border to the game screen view for debugging
        gameScreenView.layer.borderWidth = 4.0
        gameScreenView.layer.borderColor = UIColor.red.cgColor

        // Create the input handler
        let inputHandler = DeltaSkinInputHandler()

        // Create the skin view
        let skinView = UIHostingController(
            rootView: EmulatorWithSkinView(game: game, coreInstance: core)
                .environmentObject(inputHandler)
                .ignoresSafeArea(.all)
        )

        // Make the background transparent
        skinView.view.backgroundColor = .clear

        // Add the skin view as a child view controller
        addChild(skinView)
        skinView.view.frame = view.bounds
        skinView.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add a colored border to the skin view for debugging
        skinView.view.layer.borderWidth = 2.0
        skinView.view.layer.borderColor = UIColor.blue.cgColor

        // Add the skin view above the game screen
        view.insertSubview(skinView.view, aboveSubview: gameScreenView)
        ILOG("Added skin view above game screen")

        // Set the z-position of the skin view
        skinView.view.layer.zPosition = 20

        // Make sure the skin view is visible
        skinView.view.isHidden = false
        skinView.view.alpha = 1.0

        // Make sure user interaction is enabled
        skinView.view.isUserInteractionEnabled = true

        // Make sure the skin view doesn't block the game screen
        for subview in skinView.view.subviews {
            subview.backgroundColor = .clear

            // Add a colored border to each subview for debugging
            subview.layer.borderWidth = 1.0
            subview.layer.borderColor = UIColor.green.cgColor
        }

        skinView.didMove(toParent: self)

        DLOG("Added skin view to view hierarchy")

        // Add a colored border to the main view for debugging
        view.layer.borderWidth = 6.0
        view.layer.borderColor = UIColor.yellow.cgColor

        // Ensure the GPU view is properly initialized
        gpuViewController.view.setNeedsLayout()
        gpuViewController.view.layoutIfNeeded()

        // Add debug logging
        DLOG("GPU View Controller: \(type(of: gpuViewController))")
        DLOG("GPU View: \(type(of: gpuViewController.view))")
        DLOG("GPU View Frame: \(gpuViewController.view.frame)")
        DLOG("GPU View Bounds: \(gpuViewController.view.bounds)")
        DLOG("Emulator Core Buffer Size: \(core.bufferSize)")
        DLOG("Emulator Core Screen Rect: \(core.screenRect)")

        // Force a redraw of the GPU view
        if let metalVC = gpuViewController as? PVMetalViewController {
            metalVC.draw(in: metalVC.mtlView)
        }

        // Post a notification that the emulator core has initialized
        NotificationCenter.default.post(name: Notification.Name("EmulatorCoreDidInitialize"), object: nil)
    }

    /// Hide the standard controller buttons
    private func hideStandardControls() {
        // Find the controller view controller
        for childVC in children {
            if let controllerVC = childVC as? UIViewController {
                // Hide the entire controller view
                controllerVC.view.isHidden = true
                print("Hidden standard controller view")
            }
        }
    }

    /// Set up rotation notification
    private func setupRotationNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceRotation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        // Add observer for GPU view refresh
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshGPUView),
            name: Notification.Name("RefreshGPUView"),
            object: nil
        )
    }

    /// Handle device rotation
    @objc private func handleDeviceRotation() {
        // Force the skin view to update by recreating it
        if UIDevice.current.orientation.isLandscape || UIDevice.current.orientation.isPortrait {
            print("Device rotated, recreating skin view")
            createSkinView()
        }
    }

    /// Refresh the GPU view
    @objc private func refreshGPUView() {
        print("Refreshing GPU view")

        // Ensure the GPU view is properly sized and positioned
        gpuViewController.view.frame = view.bounds
        gpuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Make sure the GPU view is visible
        gpuViewController.view.isHidden = false
        gpuViewController.view.alpha = 1.0

        // Force layout
        gpuViewController.view.setNeedsLayout()
        gpuViewController.view.layoutIfNeeded()

        // Post a notification that the emulator core has initialized
        NotificationCenter.default.post(name: Notification.Name("EmulatorCoreDidInitialize"), object: nil)

        // Force the GPU view to redraw
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Force a texture update
            do {
                try metalVC.updateInputTexture()

                // Dump texture info for debugging
                metalVC.dumpTextureInfo()
            } catch {
                ELOG("Error updating texture: \(error)")
            }

            // Force a redraw
            metalVC.draw(in: metalVC.mtlView)
        }
    }
}
