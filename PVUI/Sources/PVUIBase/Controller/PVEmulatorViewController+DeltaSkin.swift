import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
// Make sure we import our custom views
import PVUIBase
// Make sure this import is correct if needed
// import PVUIBase.SwiftUI.DeltaSkins.Views

extension PVEmulatorViewController {

    /// Set up the DeltaSkin view if enabled in settings
    @objc public func setupDeltaSkinView() async throws {
        // Check if DeltaSkins are enabled
        let useDeltaSkins = true // UserDefaults.standard.bool(forKey: "useDeltaSkins")
        ILOG("Delta Skin setting: \(useDeltaSkins)")

        if useDeltaSkins {
            // CRITICAL: First add/configure the GPU view BEFORE creating skin
            configureGPUView()

            // Now create and add the skin view
            await addSkinView()

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

            // Only scan for skins once at startup
            Task {
                do {
                    if let systemId = game.system?.systemIdentifier {
                        // Just log the skin count
                        let systemSkins = try await DeltaSkinManager.shared.skins(for: systemId)
                        DLOG("Found \(systemSkins.count) skins for \(systemId)")
                    }
                } catch {
                    ELOG("Error getting skins: \(error)")
                }
            }
        } else {
            ELOG("Delta Skin not enabled in settings")
        }
    }

    /// Configure the GPU view properly
    private func configureGPUView() {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Ensure the GPU view is in the hierarchy FIRST
        if gameScreenView.superview == nil {
            view.addSubview(gameScreenView)
            DLOG("Added GPU view to view hierarchy")
        }

        // Configure the GPU view
        gameScreenView.frame = view.bounds
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0
        gameScreenView.backgroundColor = .black // Black background for the game screen
        gameScreenView.isOpaque = true // GPU view should be opaque

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // Force a draw to make sure content is visible
        if let metalVC = gpuViewController as? PVMetalViewController {
            DLOG("Forcing initial draw of GPU view")
            metalVC.draw(in: metalVC.mtlView)
        }
    }

    /// Add the skin view to the view hierarchy
    private func addSkinView() async {
        // Get the GPU view from the gpuViewController
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Create the input handler
        let inputHandler = DeltaSkinInputHandler(emulatorCore: core)

        // Create a container for the skin
        let containerView = DeltaSkinContainerView.create(
            game: game,
            core: core,
            inputHandler: inputHandler,
            onSkinLoaded: { [weak self] in
                // Force a redraw when skin is loaded
                if let metalVC = self?.gpuViewController as? PVMetalViewController {
                    DLOG("Skin loaded, forcing GPU redraw")
                    metalVC.draw(in: metalVC.mtlView)
                }
            },
            onRefreshRequested: { [weak self] in
                self?.refreshGPUView()
            },
            onMenuRequested: { [weak self] in
                self?.showEmulatorMenu()
            }
        )

        // Configure the container
        containerView.frame = view.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add the container AFTER the GPU view
        view.addSubview(containerView)

        // Force a redraw of GPU view to make sure it's visible
        refreshGPUView()

        // Schedule another redraw after a delay for safety
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.refreshGPUView()
        }
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
        // This is a system notification, so it's appropriate to use NotificationCenter
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceRotation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    /// Handle device rotation with a simple, reliable approach
    @objc private func handleDeviceRotation() {
        // Only respond to actual orientation changes
        if UIDevice.current.orientation.isLandscape || UIDevice.current.orientation.isPortrait {
            DLOG("Device rotated, updating views")

            // First update the GPU view's frame
            if let gameScreenView = gpuViewController.view {
                gameScreenView.frame = view.bounds
            }

            // Refresh all skin views
            for subview in view.subviews {
                if subview != gpuViewController.view {
                    subview.frame = view.bounds
                }
            }

            // Force a redraw
            refreshGPUView()
        }
    }

    /// Simple refresh of the GPU view
    func refreshGPUView() {
        DLOG("Refreshing GPU view")

        // Update frame
        if let gameScreenView = gpuViewController.view {
            gameScreenView.frame = view.bounds
        }

        // Force redraw
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Try to update the texture first
            do {
                try metalVC.updateInputTexture()
            } catch {
                ELOG("Error updating texture: \(error)")
            }

            // Force a redraw
            metalVC.draw(in: metalVC.mtlView)
        }
    }

    // Add this method to handle showing the menu
    @objc private func showEmulatorMenu() {
        DLOG("Showing emulator menu")

        // Call the existing method to show the menu
        showMenu(self)
    }
}
