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
            // Create and add the skin view directly
            await addSkinView()

            // Hide the standard controls
            hideStandardControls()

            DLOG("Delta Skin enabled and loaded")
            DLOG("Game: \(game.title)")
            DLOG("System: \(game.system?.name ?? "Unknown")")
            if let identifier = game.system?.systemIdentifier {
                DLOG("System Identifier: \(identifier)")
            }

            // Set up rotation notification (this is a system notification, so it's appropriate)
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

    /// Add the skin view to the view hierarchy
    private func addSkinView() async {
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
        let inputHandler = DeltaSkinInputHandler(emulatorCore: core)

        // Create a simple loading view
        let loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        loadingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = loadingView.center
        activityIndicator.startAnimating()
        loadingView.addSubview(activityIndicator)

        let loadingLabel = UILabel()
        loadingLabel.text = "Loading skin..."
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.frame = CGRect(x: 0, y: activityIndicator.frame.maxY + 20, width: loadingView.bounds.width, height: 30)
        loadingLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
        loadingView.addSubview(loadingLabel)

        view.addSubview(loadingView)

        // Create a simple container view
        let containerView = UIView(frame: view.bounds)
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.backgroundColor = .clear
        containerView.isHidden = true // Hide until loaded

        // Add the container view to the view hierarchy
        view.insertSubview(containerView, aboveSubview: gameScreenView)

        // Set the z-position of the container view
        containerView.layer.zPosition = 20

        // Add a colored border for debugging
        containerView.layer.borderWidth = 2.0
        containerView.layer.borderColor = UIColor.blue.cgColor

        // Create a thread-safe copy of the game properties
        let gameId = game.id
        let gameTitle = game.title
        let systemName = game.system?.name
        let systemId = game.system?.systemIdentifier

        // Create the wrapper view with the thread-safe properties
        let wrapperView = EmulatorWrapperView(
            game: game, // Pass the original game object
            coreInstance: core,
            onSkinLoaded: { [weak self] in
                // This will be called when the skin is loaded
                DLOG("Skin loaded callback received")

                // Show the skin view
                containerView.isHidden = false

                // Remove the loading view
                loadingView.removeFromSuperview()

                // Force a redraw of the GPU view
                if let metalVC = self?.gpuViewController as? PVMetalViewController {
                    // Force a redraw after a short delay to ensure the skin is fully rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        metalVC.draw(in: metalVC.mtlView)

                        // Force another redraw after a longer delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            metalVC.draw(in: metalVC.mtlView)
                        }
                    }
                }
            },
            onRefreshRequested: { [weak self] in
                // Direct callback for refresh requests
                self?.refreshGPUView()
            },
            onMenuRequested: { [weak self] in
                // Direct callback for menu requests
                self?.showEmulatorMenu()
            },
            inputHandler: inputHandler
        )

        // Create the hosting controller
        let hostingController = UIHostingController(rootView: wrapperView)

        // Add the hosting controller as a child
        addChild(hostingController)

        // Configure the hosting controller's view
        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear

        // Make sure all subviews are transparent
        for subview in hostingController.view.subviews {
            subview.backgroundColor = .clear
        }

        // Add the hosting controller's view to the container
        containerView.addSubview(hostingController.view)

        // Finish adding the hosting controller
        hostingController.didMove(toParent: self)

        // Set a timeout to remove the loading view if the skin takes too long to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Remove the loading view if it's still there
            if loadingView.superview != nil {
                DLOG("Timeout waiting for skin to load, showing anyway")
                loadingView.removeFromSuperview()
                containerView.isHidden = false

                // Force a redraw of the GPU view
                if let metalVC = self.gpuViewController as? PVMetalViewController {
                    metalVC.draw(in: metalVC.mtlView)
                }
            }
        }

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

        // Force an initial draw of the GPU view
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Draw immediately
            metalVC.draw(in: metalVC.mtlView)

            // And again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                metalVC.draw(in: metalVC.mtlView)
            }
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

    /// Handle device rotation
    @objc private func handleDeviceRotation() {
        // Force the skin view to update by recreating it
        if UIDevice.current.orientation.isLandscape || UIDevice.current.orientation.isPortrait {
            print("Device rotated, recreating skin view")

            // Create a task to recreate the skin view
            Task {
                // First, force a redraw of the GPU view
                if let metalVC = gpuViewController as? PVMetalViewController {
                    metalVC.draw(in: metalVC.mtlView)
                }

                // Wait a moment before recreating the skin
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Recreate the skin view
                await addSkinView()

                // Refresh the GPU view after the skin is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.refreshGPUView()

                    // Force another refresh after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.refreshGPUView()
                    }
                }
            }
        }
    }

    /// Refresh the GPU view
    func refreshGPUView() {
        DLOG("Refreshing GPU view")

        // Ensure the GPU view is properly sized and positioned
        gpuViewController.view.frame = view.bounds
        gpuViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Make sure the GPU view is visible
        gpuViewController.view.isHidden = false
        gpuViewController.view.alpha = 1.0

        // Force layout
        gpuViewController.view.setNeedsLayout()
        gpuViewController.view.layoutIfNeeded()

        // Force the GPU view to redraw with a delay to prevent GPU overload
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            if let metalVC = self.gpuViewController as? PVMetalViewController {
                // Force a texture update
                do {
                    try metalVC.updateInputTexture()

                    // Add another delay before drawing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Force a redraw
                        metalVC.draw(in: metalVC.mtlView)

                        // Force another redraw after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            metalVC.draw(in: metalVC.mtlView)
                        }
                    }
                } catch {
                    ELOG("Error updating texture: \(error)")
                }
            }
        }
    }

    // Add this method to handle showing the menu
    @objc private func showEmulatorMenu() {
        DLOG("Showing emulator menu")

        // Call the existing method to show the menu
        showMenu(self)
    }
}
