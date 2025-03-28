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

            // Set up post-appearance GPU visibility enforcement
            setupPostAppearanceGPUEnforcement()

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

        // CRITICAL STEP 1: Remove GPU view from hierarchy to ensure clean addition
        if gameScreenView.superview != nil {
            gameScreenView.removeFromSuperview()
        }

        // CRITICAL STEP 2: Insert at index 0 to be at bottom of view stack
        view.insertSubview(gameScreenView, at: 0)
        DLOG("Added GPU view at index 0")

        // CRITICAL STEP 3: Configure with absolute positioning and full opacity
        gameScreenView.frame = view.bounds
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0
        gameScreenView.backgroundColor = .black
        gameScreenView.isOpaque = true

        // Debug border to see if it's visible
        gameScreenView.layer.borderColor = UIColor.magenta.cgColor
        gameScreenView.layer.borderWidth = 4.0

        DLOG("GPU view configured: \(gameScreenView.frame)")

        // CRITICAL STEP 4: Force immediate layout
        view.layoutIfNeeded()

        // CRITICAL STEP 5: Directly configure Metal view if present
        if let metalVC = gpuViewController as? PVMetalViewController,
           let metalView = metalVC.mtlView {
            metalView.isOpaque = true
            metalView.frame = view.bounds
            metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            metalView.isPaused = false // Ensure rendering is active
            metalView.enableSetNeedsDisplay = true

            // Force Metal view to be visible and render
            metalView.layer.isOpaque = true
            metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)

            DLOG("Metal view configured: \(metalView.frame)")

            // CRITICAL STEP 6: Force multiple draws with increasing delays
            try? metalVC.updateInputTexture()
            metalVC.draw(in: metalView)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                try? metalVC.updateInputTexture()
                metalVC.draw(in: metalView)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    try? metalVC.updateInputTexture()
                    metalVC.draw(in: metalView)
                }
            }
        }
    }

    /// Add the skin view to the view hierarchy
    private func addSkinView() async {
        // Create the input handler
        let inputHandler = DeltaSkinInputHandler(emulatorCore: core)

        // Create a container for the skin
        let containerView = DeltaSkinContainerView.create(
            game: game,
            core: core,
            inputHandler: inputHandler,
            onSkinLoaded: { [weak self] in
                // CRITICAL: When skin is loaded, ensure GPU view is at bottom and visible
                if let self = self, let gameScreenView = self.gpuViewController.view {
                    // Send to back to ensure it's behind the skin layer
                    self.view.sendSubviewToBack(gameScreenView)

                    // Make 100% sure it's visible
                    gameScreenView.isHidden = false
                    gameScreenView.alpha = 1.0

                    // Force layout update
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()

                    // Schedule multiple redraws to force video display
                    if let metalVC = self.gpuViewController as? PVMetalViewController,
                       let metalView = metalVC.mtlView {
                        // First draw immediately
                        try? metalVC.updateInputTexture()
                        metalVC.draw(in: metalView)

                        // Second draw after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            try? metalVC.updateInputTexture()
                            metalVC.draw(in: metalView)

                            // Third draw after longer delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                try? metalVC.updateInputTexture()
                                metalVC.draw(in: metalView)
                            }
                        }
                    }

                    // Log success
                    DLOG("Skin loaded, GPU view ensured visible")
                }
            },
            onRefreshRequested: { [weak self] in
                self?.refreshGPUView()
            },
            onMenuRequested: { [weak self] in
                self?.showEmulatorMenu()
            }
        )

        // Configure container
        containerView.frame = view.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add container ABOVE GPU view
        view.addSubview(containerView)
        DLOG("Added skin container")

        // Force a redraw of GPU view to make sure it's visible
        refreshGPUView()

        // Schedule another redraw after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refreshGPUView()
        }
    }

    /// Hide the standard controller buttons
    private func hideStandardControls() {
        // Find the controller view controller
        for childVC in children {
            if let controllerVC = childVC as? UIViewController,
               childVC != gpuViewController,
               type(of: childVC).description().contains("Controller") {
                controllerVC.view.isHidden = true
                DLOG("Hidden standard controller: \(type(of: childVC))")
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

            // Log view hierarchy after rotation
            logViewHierarchy("AFTER ROTATION")
        }
    }

    /// Simple refresh of the GPU view with maximum visibility enforcement
    func refreshGPUView() {
        DLOG("Refreshing GPU view with maximum visibility")

        // Make sure GPU view is at the bottom layer
        if let gameScreenView = gpuViewController.view {
            view.sendSubviewToBack(gameScreenView)

            // Ensure complete visibility
            gameScreenView.isHidden = false
            gameScreenView.alpha = 1.0
            gameScreenView.backgroundColor = .black
            gameScreenView.isOpaque = true

            // Update frame to fill view
            gameScreenView.frame = view.bounds
        }

        // Force immediate draw
        if let metalVC = gpuViewController as? PVMetalViewController {
            do {
                try metalVC.updateInputTexture()
                metalVC.draw(in: metalVC.mtlView)

                // Log buffer details for debugging
                if let emulatorCore = metalVC.emulatorCore {
                    DLOG("GPU buffer size: \(emulatorCore.bufferSize)")
                }

                // Force an additional draw after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    metalVC.draw(in: metalVC.mtlView)
                }
            } catch {
                ELOG("Failed to update texture: \(error)")
            }
        }
    }

    // Helper method to log the view hierarchy for debugging
    private func logViewHierarchy(_ label: String) {
        DLOG("--- VIEW HIERARCHY (\(label)) ---")
        for (index, subview) in view.subviews.enumerated() {
            let viewType = type(of: subview)
            let isGPUView = subview == gpuViewController.view
            DLOG("[\(index)] \(viewType)\(isGPUView ? " (GPU VIEW)" : "") - frame: \(subview.frame), alpha: \(subview.alpha), hidden: \(subview.isHidden)")
        }
        DLOG("--- END VIEW HIERARCHY ---")
    }

    // Add this method to handle showing the menu
    @objc private func showEmulatorMenu() {
        DLOG("Showing emulator menu")

        // Call the existing method to show the menu
        showMenu(self)
    }

    // Add an optimized forced refresh method
    private func forceRefreshGPUView() {
        guard let metalVC = gpuViewController as? PVMetalViewController else {
            return
        }

        if let metalView = metalVC.mtlView {
            // Clean previous texture
            try? metalVC.updateInputTexture()

            // Force immediate draw
            metalVC.draw(in: metalView)

            // Schedule additional draws to ensure visibility
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                try? metalVC.updateInputTexture()
                metalVC.draw(in: metalView)
            }
        }
    }

    /// Set up a notification to enforce GPU visibility after view appearance
    private func setupPostAppearanceGPUEnforcement() {
        // This approach preserves the existing viewDidAppear implementation
        // while still enforcing GPU visibility after the view appears
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enforceGPUVisibility),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        // Also add a delayed call to enforce visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.enforceGPUVisibility()
        }
    }

    /// Enforce GPU view visibility - can be called anytime
    @objc func enforceGPUVisibility() {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Make sure it's in the hierarchy
        if gameScreenView.superview == nil {
            view.insertSubview(gameScreenView, at: 0)
            DLOG("Enforced GPU view insertion")
        } else {
            // Just make sure it's at the bottom
            view.sendSubviewToBack(gameScreenView)
        }

        // Force visibility
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Forcibly redraw Metal content
        if let metalVC = gpuViewController as? PVMetalViewController {
            try? metalVC.updateInputTexture()
            metalVC.draw(in: metalVC.mtlView)
        }

        DLOG("Enforced GPU view visibility")
    }
}
