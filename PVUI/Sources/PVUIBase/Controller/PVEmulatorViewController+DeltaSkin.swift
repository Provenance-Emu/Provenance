import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVUIBase
import QuartzCore
import Combine

// MARK: - DeltaSkin Extension

/// Extension to add DeltaSkin support to the emulator view controller
extension PVEmulatorViewController {
  

    /// Set up the DeltaSkin view if enabled in settings
    @objc public func setupDeltaSkinView() async throws {
        // Check if DeltaSkins are enabled (hardcoded to true for now, but should use UserDefaults in production)
        let useDeltaSkins = true // UserDefaults.standard.bool(forKey: "useDeltaSkins")
        ILOG("Delta Skin setting: \(useDeltaSkins)")

        if useDeltaSkins {
            // CRITICAL: First add/configure the GPU view BEFORE creating skin
            configureGPUView()

            // Now create and add the skin view
            await addSkinView()

            // Hide the standard controls
            hideStandardControls()

            // Log skin setup info
            let skinInfo = """
            Delta Skin enabled and loaded
            Game: \(game.title)
            System: \(game.system?.name ?? "Unknown")
            Identifier: \(game.system?.systemIdentifier.rawValue ?? "Unknown")
            """
            DLOG(skinInfo)
            
            // Set up observation of app state changes
            observeAppStateChanges()

            // Scan for available skins in the background
            Task {
                await scanForAvailableSkins()
            }
            
            // Schedule a refresh to ensure rendering is correct
            scheduleInitialRefresh()
        } else {
            ELOG("Delta Skin not enabled in settings")
        }
    }
    
    /// Scan for available skins for the current system
    private func scanForAvailableSkins() async {
        do {
            if let systemId = game.system?.systemIdentifier {
                // Get skins for this system
                let systemSkins = try await DeltaSkinManager.shared.skins(for: systemId)
                DLOG("Found \(systemSkins.count) skins for \(systemId)")
                
                // If no skins found, try to use default skins
                if systemSkins.isEmpty {
                    DLOG("No custom skins found, using default skin if available")
                }
            }
        } catch {
            ELOG("Error scanning for skins: \(error)")
        }
    }
    
    /// Schedule initial refresh with appropriate timing
    private func scheduleInitialRefresh() {
        // Initial gentle refresh after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.gentleRefreshMetalView()
        }
    }
    
    /// Observe app state changes to handle background/foreground transitions
    private func observeAppStateChanges() {
        // Remove any existing observers
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Add observers for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    /// Handle app coming to foreground
    @objc private func handleAppWillEnterForeground() {
        DLOG("App entering foreground, refreshing Metal view")
        gentleRefreshMetalView()
    }
    
    /// Handle app going to background
    @objc private func handleAppDidEnterBackground() {
        DLOG("App entering background")
        // Any cleanup needed when going to background
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
        
        // Make sure GPU view is in front
        view.bringSubviewToFront(gameScreenView)
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
        
        // Set up the menu button handler to show the emulator menu
        inputHandler.menuButtonHandler = { [weak self] in
            DLOG("Menu button pressed from skin, showing emulator menu")
            self?.showEmulatorMenu()
        }

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
                // This is called from SwiftUI controls, not from skin button presses
                self?.showEmulatorMenu()
            }
        )

        // Configure the container
        containerView.frame = view.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.isOpaque = false  // Ensure it's not opaque
        containerView.backgroundColor = .clear  // Clear background

        // Add the container to the view hierarchy
        view.addSubview(containerView)
        
        // Store reference to the skin container view
        self.skinContainerView = containerView
        
        // Make sure the skin view is above the GPU view
        view.bringSubviewToFront(containerView)
        
        // Add debug overlay toggle gesture
        let debugTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleDebugOverlay))
        debugTapGesture.numberOfTapsRequired = 3
        debugTapGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(debugTapGesture)

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

    // MARK: - Rotation Handling
    
    /// Handle rotation properly using UIKit's standard view transition method
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Log rotation for debugging
        DLOG("View transitioning to size: \(size)")
        
        // Always call super first
        super.viewWillTransition(to: size, with: coordinator)
        
        // Use the coordinator to animate alongside the rotation
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            
            // Update frames during the rotation animation
            self.updateViewFramesForCurrentBounds()
            
        }, completion: { [weak self] _ in
            // After rotation is complete, do a gentle refresh
            self?.gentleRefreshMetalView()
        })
    }
    
    /// Update all view frames to match current bounds
    private func updateViewFramesForCurrentBounds() {
        let currentBounds = view.bounds
        
        // Update GPU view frame
        if let gameScreenView = gpuViewController.view {
            gameScreenView.frame = currentBounds
        }
        
        // Update Metal view if available
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            mtlView.frame = currentBounds
        }
        
        // Update skin view if available
        if let skinView = self.skinContainerView {
            skinView.frame = currentBounds
            
            // Ensure skin view is always on top
            if let superview = skinView.superview {
                superview.bringSubviewToFront(skinView)
            }
        }
    }

    /// Simple refresh of the GPU view
    func refreshGPUView() {
        DLOG("Refreshing GPU view")

        // Update frame
        if let gameScreenView = gpuViewController.view {
            gameScreenView.frame = view.bounds
            gameScreenView.isHidden = false
            gameScreenView.alpha = 1.0
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
            
            // Make sure Metal view is visible
            if let mtlView = metalVC.mtlView {
                mtlView.isHidden = false
                mtlView.alpha = 1.0
            }
        }
    }
    
    /// A more gentle refresh of the Metal view that won't freeze the UI
    func gentleRefreshMetalView() {
        guard let metalVC = gpuViewController as? PVMetalViewController,
              let mtlView = metalVC.mtlView else {
            ELOG("Metal view not available")
            return
        }
        
        // Capture initial state for logging
        let initialState = "superview=\(mtlView.superview != nil ? "exists" : "nil"), hidden=\(mtlView.isHidden), alpha=\(mtlView.alpha)"
        let initialFrame = mtlView.frame
        
        // Perform all updates on the main thread to avoid UI issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Only make minimal changes to ensure visibility
            if mtlView.isHidden {
                mtlView.isHidden = false
            }
            
            if mtlView.alpha < 1.0 {
                mtlView.alpha = 1.0
            }
            
            // Only add to view hierarchy if absolutely necessary
            if mtlView.superview == nil {
                DLOG("Metal view has no superview, adding to view hierarchy")
                self.view.addSubview(mtlView)
            }
            
            // Ensure frame is correct
            if mtlView.frame != self.view.bounds {
                mtlView.frame = self.view.bounds
            }
            
            // Ensure proper z-order with skin view
            if let skinView = self.skinContainerView, let superview = skinView.superview {
                superview.bringSubviewToFront(skinView)
            }
            
            // Request a redraw but don't force it
            try? metalVC.updateInputTexture()
            
            // Log the changes made
            let finalState = "superview=\(mtlView.superview != nil ? "exists" : "nil"), hidden=\(mtlView.isHidden), alpha=\(mtlView.alpha)"
            let finalFrame = mtlView.frame
            
            if initialState != finalState || initialFrame != finalFrame {
                DLOG("""
                🔧 METAL VIEW UPDATED:
                - Initial: \(initialState), frame=\(initialFrame)
                - Final: \(finalState), frame=\(finalFrame)
                """)
            }
        }
    }

    // Add this method to handle showing the menu
    @objc private func showEmulatorMenu() {
        DLOG("Showing emulator menu")

        // Call the existing method to show the menu
        showMenu(self)
    }
    
    // Add a method to handle showing the menu with a sender
    @objc private func showEmulatorMenu(sender: AnyObject? = nil) {
        DLOG("Showing emulator menu with sender: \(String(describing: sender))")
        
        // Call the existing method to show the menu
        showMenu(sender ?? self)
    }
    
    // MARK: - Debug Overlay
    
    /// Toggle the debug overlay with a triple tap (3 taps with 2 fingers)
    @objc private func toggleDebugOverlay() {
        if debugOverlayView != nil {
            removeDebugOverlay()
        } else {
            showDebugOverlay()
        }
    }
    
    /// Show a debug overlay with useful information
    private func showDebugOverlay() {
        // Create overlay view
        let overlay = UIView(frame: CGRect(x: 10, y: 50, width: 300, height: 300))
        overlay.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        overlay.layer.cornerRadius = 10
        overlay.layer.borderWidth = 1
        overlay.layer.borderColor = UIColor.cyan.cgColor
        
        // Add a title
        let titleLabel = UILabel(frame: CGRect(x: 10, y: 5, width: 280, height: 30))
        titleLabel.text = "Debug Info"
        titleLabel.textColor = .cyan
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .center
        overlay.addSubview(titleLabel)
        
        // Add info label
        let infoLabel = UILabel(frame: CGRect(x: 10, y: 40, width: 280, height: 250))
        infoLabel.textColor = .white
        infoLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        infoLabel.numberOfLines = 0
        overlay.addSubview(infoLabel)
        self.debugInfoLabel = infoLabel
        
        // Add close button
        let closeButton = UIButton(frame: CGRect(x: 260, y: 5, width: 30, height: 30))
        closeButton.setTitle("×", for: .normal)
        closeButton.setTitleColor(.cyan, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        closeButton.addTarget(self, action: #selector(removeDebugOverlay), for: .touchUpInside)
        overlay.addSubview(closeButton)
        
        // Make overlay draggable
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDebugOverlayPan(_:)))
        overlay.addGestureRecognizer(panGesture)
        
        // Add to view
        view.addSubview(overlay)
        self.debugOverlayView = overlay
        
        // Start update timer
        updateDebugInfo()
        debugUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDebugInfo()
        }
    }
    
    /// Remove the debug overlay
    @objc private func removeDebugOverlay() {
        debugUpdateTimer?.invalidate()
        debugUpdateTimer = nil
        
        debugOverlayView?.removeFromSuperview()
        debugOverlayView = nil
        debugInfoLabel = nil
    }
    
    /// Handle dragging the debug overlay
    @objc private func handleDebugOverlayPan(_ gesture: UIPanGestureRecognizer) {
        guard let overlay = debugOverlayView else { return }
        
        let translation = gesture.translation(in: view)
        overlay.center = CGPoint(x: overlay.center.x + translation.x, y: overlay.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
    }
    
    /// Update the debug info display
    private func updateDebugInfo() {
        guard let infoLabel = debugInfoLabel else { return }
        
        // Get GPU view info
        var gpuInfo = "No GPU view"
        if let gameScreenView = gpuViewController.view {
            gpuInfo = "Frame: \(gameScreenView.frame.size.width)×\(gameScreenView.frame.size.height)\nHidden: \(gameScreenView.isHidden)\nAlpha: \(gameScreenView.alpha)"
        }
        
        // Get Metal view info
        var metalInfo = "No Metal view"
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            metalInfo = "Frame: \(mtlView.frame.size.width)×\(mtlView.frame.size.height)\nHidden: \(mtlView.isHidden)\nAlpha: \(mtlView.alpha)\nDrawable: \(mtlView.drawableSize.width)×\(mtlView.drawableSize.height)"
        }
        
        // Get skin view info
        var skinInfo = "No skin view"
        if let skinView = skinContainerView {
            skinInfo = "Frame: \(skinView.frame.size.width)×\(skinView.frame.size.height)\nHidden: \(skinView.isHidden)\nAlpha: \(skinView.alpha)"
        }
        
        // Get device orientation
        let orientation = UIDevice.current.orientation
        let orientationStr = orientation.isPortrait ? "Portrait" : (orientation.isLandscape ? "Landscape" : "Other")
        
        // Get FPS if available
        var fpsInfo = "FPS: N/A"
        if let metalVC = gpuViewController as? PVMetalViewController {
            let fps = metalVC.framesPerSecond
            fpsInfo = "FPS: \(Int(fps))"
        }
        
        // Combine all info
        let infoText = """
        📱 Device: \(orientationStr)
        ⏱ \(fpsInfo)
        
        🖥 GPU View:
        \(gpuInfo)
        
        🔲 Metal View:
        \(metalInfo)
        
        🎮 Skin View:
        \(skinInfo)
        """
        
        infoLabel.text = infoText
    }
    
    /// Print a detailed view hierarchy - for debugging
    func printViewHierarchy() {
        var logOutput = ""
        logOutput += "🔍 ===== FULL VIEW HIERARCHY =====\n"
        
        // Build the view hierarchy string
        var hierarchyOutput = ""
        buildViewHierarchyString(for: view, level: 0, output: &hierarchyOutput)
        logOutput += hierarchyOutput
        
        logOutput += "🔍 ===== END VIEW HIERARCHY =====\n"
        
        // Add GPU view info
        if let gameScreenView = gpuViewController.view {
            logOutput += "🔍 GPU View: frame=\(gameScreenView.frame), hidden=\(gameScreenView.isHidden), alpha=\(gameScreenView.alpha), tag=\(gameScreenView.tag)\n"
            logOutput += "🔍 GPU View superview: \(String(describing: gameScreenView.superview))\n"
            
            if let metalVC = gpuViewController as? PVMetalViewController,
               let mtlView = metalVC.mtlView {
                logOutput += "🔍 Metal View: frame=\(mtlView.frame), hidden=\(mtlView.isHidden) alpha=\(mtlView.alpha), opaque=\(mtlView.isOpaque)\n"
                logOutput += "🔍 Metal View drawable size: \(mtlView.drawableSize)\n"
            }
        }
        
        // Log the entire output as a single call
        DLOG(logOutput)
    }
    
    /// Helper to build a view hierarchy string with indentation
    private func buildViewHierarchyString(for view: UIView, level: Int, output: inout String) {
        let indent = String(repeating: "  ", count: level)
        output += "\(indent)🔍 \(type(of: view)): frame=\(view.frame), hidden=\(view.isHidden), alpha=\(view.alpha), tag=\(view.tag)\n"
        
        for (index, subview) in view.subviews.enumerated() {
            output += "\(indent)  🔹 Subview [\(index)]:\n"
            buildViewHierarchyString(for: subview, level: level + 1, output: &output)
        }
    }
}
