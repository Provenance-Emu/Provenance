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

    var isDeltaSkinEnabled: Bool {
        #if os(tvOS) || os(macOS) || targetEnvironment(macCatalyst)
        return false
        #else
        return Defaults[.skinMode] != .off && core.supportsSkins
        #endif
//        return true
    }

    /// Set up the DeltaSkin view if enabled in settings
    @objc public func setupDeltaSkinView() async throws {
        ILOG("skins: setupDeltaSkinView() called")

        // Check if DeltaSkin is enabled
        let useDeltaSkins = isDeltaSkinEnabled
        ILOG("skins: Delta Skin enabled: \(useDeltaSkins)")

        if useDeltaSkins {
            ILOG("skins: Setting up DeltaSkin view for game: \(game.title)")
            // CRITICAL: First add/configure the GPU view BEFORE creating skin
            configureGPUView()

            // Now create and add the skin view
            await addSkinView()

            // Hide the standard controls
             hideStandardControls()

            // Log skin setup info
            let skinInfo = """
            skins: Delta Skin enabled and loaded
            skins: Game: \(game.title)
            skins: System: \(game.system?.name ?? "Unknown")
            skins: Identifier: \(game.system?.systemIdentifier.rawValue ?? "Unknown")
            """
            ILOG(skinInfo)

            // Set up observation of app state changes
            observeAppStateChanges()
        } else {
            ILOG("skins: Delta Skin not enabled in settings, skipping setup")
        }
    }

    /// Scan for available skins for the current system
    private func scanForAvailableSkins() async {
        ILOG("skins: scanForAvailableSkins() called")
        do {
            if let systemId = game.system?.systemIdentifier {
                // Get skins for this system
                let systemSkins = try await DeltaSkinManager.shared.skins(for: systemId)
                ILOG("skins: Found \(systemSkins.count) skins for system \(systemId.rawValue)")

                // If no skins found, try to use default skins
                if systemSkins.isEmpty {
                    WLOG("skins: No custom skins found for system \(systemId.rawValue), using default skin if available")
                }
            } else {
                WLOG("skins: No system identifier available for skin scanning")
            }
        } catch {
            ELOG("skins: Error scanning for skins: \(error)")
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
        applyViewportFromCurrentSkin()
    }

    /// Handle app going to background
    @objc private func handleAppDidEnterBackground() {
        DLOG("App entering background")
        // Any cleanup needed when going to background
    }

    /// Pause emulation temporarily and then resume after a delay
    private func pauseEmulationTemporarily() {
        // Pause emulation
        DLOG("Pausing emulation temporarily after skin load")
        core.setPauseEmulation(true)

        // Resume after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Only resume if we're not showing a menu
            if !self.isShowingMenu {
                DLOG("Resuming emulation after temporary pause")
                self.core.setPauseEmulation(false)
            } else {
                DLOG("Not resuming emulation because menu is showing")
            }
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
            ILOG("skins: Added GPU view to view hierarchy")
        }

        // Configure basic properties of the GPU view
        // For GL views, don't override opacity/background as it can interfere with GL context
        if gpuViewController is PVMetalViewController {
            gameScreenView.backgroundColor = .black
            gameScreenView.isOpaque = true
        } else {
            // For GL views, preserve existing settings set by PVGLViewController
            // Only ensure visibility
        }
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Position the GPU view based on the DeltaSkin screen information
        updateGPUViewPositionForDeltaSkin()
    }

    /// Add the skin view to the view hierarchy
    private func addSkinView() async {
        guard isDeltaSkinEnabled else {
            ILOG("skins: Skipping addSkinView() - DeltaSkin not enabled")
            return
        }

        // Log on main thread if needed, but don't block
        if Thread.isMainThread {
            ILOG("skins: Starting to add skin view")
        } else {
            await MainActor.run {
                ILOG("skins: Starting to add skin view")
            }
        }

        // Get the GPU view from the gpuViewController
        guard let gameScreenView = gpuViewController.view else {
            ELOG("skins: GPU view not found when adding skin view")
            return
        }

        // Create the input handler for both core-level and controller-level input

        // Add debug logging for the controller view controller
        if let controller = controllerViewController {
            DLOG("Found controller view controller: \(controller) of type \(type(of: controller))")
        } else {
            DLOG("No controller view controller found")
        }

        // Log emulator controller availability
        DLOG("Using self as emulator controller for special commands (quicksave/quickload)")

        // Pass the controller view controller and emulator controller (self) to the input handler
        let inputHandler = DeltaSkinInputHandler(emulatorCore: core,
                                               controllerVC: controllerViewController,
                                               emulatorController: self)

        // CRITICAL: Store this input handler in the shared property so it can be accessed
        // throughout the emulator controller, especially for skin changes
        self.sharedInputHandler = inputHandler
        DLOG("Stored input handler in sharedInputHandler property")

        // Set up the menu button handler to show the emulator menu
        inputHandler.menuButtonHandler = { [weak self] in
            DLOG("Menu button pressed from skin, showing emulator menu")
            self?.showEmulatorMenu()
        }

        let preselectedSkinIdentifier: String? = await MainActor.run { [weak self] in
            guard let self, let sid = self.game.system?.systemIdentifier else { return nil }
            let orient = self.currentOrientation
            let gid = self.game.id
            if !gid.isEmpty {
                return DeltaSkinSelectionManager.shared.effectiveGameSkinIdentifier(for: sid, gameId: gid, orientation: orient)
            }
            return DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(for: sid, gameId: nil, orientation: orient)
        }

        // Create a container for the skin
        let containerView = DeltaSkinContainerView.create(
            game: game,
            core: core,
            inputHandler: inputHandler,
            preselectedSkinIdentifier: preselectedSkinIdentifier,
            onSkinLoaded: { [weak self] in
                guard let self = self else { return }

                // Wait a bit for the color bars notification to arrive with the correct frame
                // The notification frame is more accurate than the calculated one
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }

                    // CRITICAL: Ensure skin container stays visible after delay
                    // This prevents the container from disappearing on iPad
                    if let skinContainer = self.skinContainerView {
                        skinContainer.isHidden = false
                        skinContainer.alpha = 1.0
                        skinContainer.frame = self.view.bounds
                        // Ensure hosting controller's view is also visible
                        if let hostView = skinContainer.subviews.first {
                            hostView.isHidden = false
                            hostView.alpha = 1.0
                            hostView.frame = skinContainer.bounds
                        }
                        // Ensure z-order is correct
                        if let gpuView = self.gpuViewController.view {
                            self.view.insertSubview(gpuView, belowSubview: skinContainer)
                        }
                        self.view.bringSubviewToFront(skinContainer)
                    }

                    // For non-RetroArch cores, ensure we have a frame even if notification didn't arrive
                    if self.core.coreIdentifier?.contains("libretro") != true {
                        // If no frame received, calculate one as fallback
                        if self.currentTargetFrame == nil {
                            DLOG("🎮 SKIN: No frame notification received for non-RetroArch core, calculating fallback")
                            if let calculatedFrame = self.currentSkinViewportFrame() {
                                self.currentTargetFrame = calculatedFrame
                                DLOG("🎮 SKIN: Using calculated fallback frame: \(calculatedFrame)")
                            }
                        }
                    }

                    // Apply viewport when skin is loaded
                    // Don't force layout here - applyViewportFromCurrentSkin handles layout naturally
                    self.applyViewportFromCurrentSkin()

                    // Note: screen filters are applied via the DeltaSkinLoaded notification handler
                    // (handleSkinLoaded) where currentSkin is set — calling here would apply the
                    // filter a second time redundantly.

                    // Pause emulation for 1 second after skin is loaded to ensure smooth startup
                    self.pauseEmulationTemporarily()
                }
            },
            onRefreshRequested: { [weak self] in
                // Re-apply viewport on explicit refresh
                // Don't force layout here - applyViewportFromCurrentSkin handles layout naturally
                self?.applyViewportFromCurrentSkin()
            },
            virtualInputState: {
                #if !os(tvOS)
                return virtualInputState
                #else
                return nil
                #endif
            }()
        )

        // Configure the container
        containerView.frame = view.bounds
        // Use flexible autoresizing to automatically resize with view bounds changes
        // This ensures the container stays aligned with view.bounds during fullscreen transitions
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.translatesAutoresizingMaskIntoConstraints = true
        containerView.isOpaque = false  // Ensure it's not opaque
        containerView.backgroundColor = UIColor.clear  // Clear background

        // CRITICAL: Ensure GPU view exists and is visible before adding skin
        guard let gameScreenView = gpuViewController.view else {
            ELOG("skins: GPU view not found when adding skin")
            return
        }

        // Ensure GPU view is visible
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Add the Metal view to the main view first (bottom layer) if it exists separately
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            // Make sure Metal view is in the view hierarchy
            if mtlView.superview == nil {
                view.addSubview(mtlView)
            }

            // IMPORTANT: Don't override the frame here, let DeltaSkinScreen handle it
            // Just ensure it's visible
            mtlView.isHidden = false
            mtlView.alpha = 1.0

            // Log that we're not setting the frame here
            DLOG("MTLView added to hierarchy but not positioning it here - DeltaSkinScreen will handle that")
        }

        // For GL views, ensure the view is properly set up
        // GL views use GLKView which is the main view, no separate subview needed
        if gpuViewController is PVGLViewController {
            DLOG("GL view controller detected - ensuring proper setup")
            // GL view setup is handled by PVGLViewController itself
            // Just ensure it's visible and in the hierarchy
        }

        // Store reference to skin container view for z-order management
        self.skinContainerView = containerView
        ILOG("skins: Stored reference to skin container view")

        // CRITICAL: Ensure container view is visible before adding
        containerView.isHidden = false
        containerView.alpha = 1.0

        // Now add the skin container on top
        view.addSubview(containerView)
        ILOG("skins: Added skin container view to view hierarchy")

        // CRITICAL: Ensure correct z-order - GPU view must be below skin
        // Use insertSubview instead of bringSubviewToFront for more reliable ordering
        view.insertSubview(gameScreenView, belowSubview: containerView)
        ILOG("skins: Set z-order - GPU view below skin container")

        // CRITICAL: Ensure container stays visible after adding
        // Force layout to ensure hosting controller's view is properly sized
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()

        // Double-check visibility after layout
        containerView.isHidden = false
        containerView.alpha = 1.0
        if let hostView = (containerView as? DeltaSkinContainerView)?.subviews.first {
            hostView.isHidden = false
            hostView.alpha = 1.0
        }

        // Also ensure Metal view is below skin if it exists separately
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView,
           mtlView.superview == view {
            view.insertSubview(mtlView, belowSubview: containerView)
            ILOG("skins: Set z-order - Metal view below skin container")
        }

        if let menuButton = menuButton {
            view.bringSubviewToFront(menuButton)
        }
        #if !os(tvOS)
        // Add debug overlay toggle gesture
        let debugTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleDebugOverlay))
        debugTapGesture.numberOfTapsRequired = 3
        debugTapGesture.numberOfTouchesRequired = 3
        view.addGestureRecognizer(debugTapGesture)
        #endif
        // Apply viewport - works the same for all cores
        ILOG("skins: Applying viewport from current skin")
        applyViewportFromCurrentSkin()

        ILOG("skins: Skin view setup complete, printing view hierarchy")
        printViewHierarchy()
    }

    /// Hide the standard controller buttons
    private func hideStandardControls() {
        // Find the controller view controller
        for childVC in children {
            if let controllerVC = childVC as? any ControllerVC {
                // Hide the entire controller view
                controllerVC.view.isHidden = true
                ILOG("Hidden standard controller view")
            }
        }
    }

    // MARK: - Rotation Handling

    /// Update view frames on rotation
    private func updateViewFramesForCurrentBounds() {
        let bounds = view.bounds

        // Update skin container
        skinContainerView?.frame = bounds

        // Re-apply viewport (will recalculate from skin)
        applyViewportFromCurrentSkin()

        // Ensure z-order
        if let skinView = skinContainerView,
           let gameScreenView = gpuViewController.view {
            view.insertSubview(gameScreenView, belowSubview: skinView)
        }
    }

    /// Simple refresh of the GPU view
    func refreshGPUView() {
        DLOG("Refreshing GPU view")

        applyViewportFromCurrentSkin()

        // Make sure the GPU view is visible
        if let gameScreenView = gpuViewController.view {
            gameScreenView.isHidden = false
            gameScreenView.alpha = 1.0
        }

        // Ensure Metal view visible
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            mtlView.isHidden = false
            mtlView.alpha = 1.0
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
        let overlay = UIView(frame: CGRect(x: 10, y: 50, width: 300, height: 400)) // Increased height for buttons
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

        // Add debug buttons section
        let buttonsSectionLabel = UILabel(frame: CGRect(x: 10, y: 300, width: 280, height: 20))
        buttonsSectionLabel.text = "Screen Positioning Controls"
        buttonsSectionLabel.textColor = .cyan
        buttonsSectionLabel.font = UIFont.boldSystemFont(ofSize: 12)
        buttonsSectionLabel.textAlignment = .center
        overlay.addSubview(buttonsSectionLabel)

        // Now that the debug overlay is active, create the frame overlay if we have a stored frame
        if let storedFrame = currentTargetFrame {
            DLOG("Creating frame overlay with stored frame: \(storedFrame)")
            createDebugFrameOverlay(frame: storedFrame)
        }

        // Add buttons for different positioning approaches
        let tryFrameButton = createDebugButton(title: "Try Frame", frame: CGRect(x: 20, y: 330, width: 120, height: 30))
        tryFrameButton.addTarget(self, action: #selector(tryFramePositioning), for: .touchUpInside)
        overlay.addSubview(tryFrameButton)

        let resetButton = createDebugButton(title: "Reset Position", frame: CGRect(x: 160, y: 330, width: 120, height: 30))
        resetButton.addTarget(self, action: #selector(resetPositioning), for: .touchUpInside)
        overlay.addSubview(resetButton)

        // Add a button to reset to the calculated position from the skin
        let resetToCalculatedButton = createDebugButton(title: "Reset to Calculated", frame: CGRect(x: 20, y: 370, width: 260, height: 30))
        resetToCalculatedButton.addTarget(self, action: #selector(resetToCalculatedPosition), for: .touchUpInside)
        resetToCalculatedButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        overlay.addSubview(resetToCalculatedButton)

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

        // Add a debug frame overlay if we have a current target frame
        if let currentFrame = currentTargetFrame {
            createDebugFrameOverlay(frame: currentFrame)
        }
    }

    /// Remove the debug overlay
    @objc private func removeDebugOverlay() {
        debugUpdateTimer?.invalidate()

        // Also remove any debug frame overlays
        view.subviews.forEach { subview in
            if subview.tag == 9999 {
                subview.removeFromSuperview()
            }
        }
        debugUpdateTimer = nil

        debugOverlayView?.removeFromSuperview()
        debugOverlayView = nil
        debugInfoLabel = nil

        // We keep the currentTargetFrame for when the debug overlay is shown again
    }

    /// Handle dragging the debug overlay
    /// Create a debug button with the given title and frame
    private func createDebugButton(title: String, frame: CGRect) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = frame
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.cyan.cgColor
        return button
    }

    /// Create a debug frame overlay to visualize where the GPU view should be
    internal func createDebugFrameOverlay(frame: CGRect) {
        // Store the original calculated frame for reset functionality
        if originalCalculatedFrame == nil {
            originalCalculatedFrame = frame
        }

        // Store the current target frame
        currentTargetFrame = frame

        // Remove any existing debug frame overlays
        view.subviews.forEach { subview in
            if subview.tag == 9999 {
                subview.removeFromSuperview()
            }
        }

        // Create a debug overlay view
        let debugOverlay = UIView(frame: frame)
        debugOverlay.tag = 9999 // Use a tag to identify it later
        debugOverlay.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        debugOverlay.layer.borderColor = UIColor.yellow.cgColor
        debugOverlay.layer.borderWidth = 2.0

        // Add a visual handle to indicate draggability
        let handleSize: CGFloat = 30
        let handle = UIView(frame: CGRect(x: frame.width - handleSize - 5, y: 5, width: handleSize, height: handleSize))
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        handle.layer.cornerRadius = handleSize / 2
        handle.layer.borderWidth = 2
        handle.layer.borderColor = UIColor.black.cgColor

        // Add drag icon to handle
        let iconSize: CGFloat = 15
        let icon = UIImageView(frame: CGRect(x: (handleSize - iconSize) / 2, y: (handleSize - iconSize) / 2, width: iconSize, height: iconSize))
        if let moveImage = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right") {
            icon.image = moveImage
            icon.tintColor = UIColor.black
            icon.contentMode = .scaleAspectFit
            handle.addSubview(icon)
        }
        debugOverlay.addSubview(handle)

        // Add resize handle in the bottom right corner
        let resizeHandle = UIView(frame: CGRect(x: frame.width - handleSize - 5,
                                              y: frame.height - handleSize - 5,
                                              width: handleSize,
                                              height: handleSize))
        resizeHandle.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        resizeHandle.layer.cornerRadius = handleSize / 2
        resizeHandle.layer.borderWidth = 2
        resizeHandle.layer.borderColor = UIColor.black.cgColor

        // Add resize icon
        let resizeIcon = UIImageView(frame: CGRect(x: (handleSize - iconSize) / 2,
                                                 y: (handleSize - iconSize) / 2,
                                                 width: iconSize,
                                                 height: iconSize))
        if let resizeImage = UIImage(systemName: "arrow.up.left.and.arrow.down.right") {
            resizeIcon.image = resizeImage
            resizeIcon.tintColor = UIColor.black
            resizeIcon.contentMode = .scaleAspectFit
            resizeHandle.addSubview(resizeIcon)
        }
        debugOverlay.addSubview(resizeHandle)

        // Add a label to show the frame
        let labelWidth = frame.width - 20
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: labelWidth, height: 80))
        label.text = "Expected GPU View\nFrame: \(frame)\n(Drag to move, pinch to resize)"
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.numberOfLines = 3
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)
        debugOverlay.addSubview(label)

        // Add gesture recognizers
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDebugFrameOverlayPan(_:)))
        debugOverlay.addGestureRecognizer(panGesture)

        #if !os(tvOS)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleDebugFrameOverlayPinch(_:)))
        debugOverlay.addGestureRecognizer(pinchGesture)
        #endif
        debugOverlay.isUserInteractionEnabled = true

        // Add the debug overlay to the view
        view.addSubview(debugOverlay)

        // Make sure it's above everything else but below the debug info overlay
        view.insertSubview(debugOverlay, belowSubview: debugOverlayView ?? view)

        // Log the current GPU view frame for comparison
        if let gameScreenView = gpuViewController.view {
            DLOG("Current GPU view frame: \(gameScreenView.frame)")

            if let metalVC = gpuViewController as? PVMetalViewController {
                DLOG("Current MTLView frame: \(metalVC.mtlView.frame)")
            }
        }
    }

    @objc private func handleDebugOverlayPan(_ gesture: UIPanGestureRecognizer) {
        guard let overlay = debugOverlayView else { return }

        let translation = gesture.translation(in: view)

        // Calculate new center position
        let newCenter = CGPoint(x: overlay.center.x + translation.x, y: overlay.center.y + translation.y)

        // Ensure the overlay stays within the parent view bounds
        let halfWidth = overlay.bounds.width / 2
        let halfHeight = overlay.bounds.height / 2

        let minX = halfWidth
        let maxX = view.bounds.width - halfWidth
        let minY = halfHeight
        let maxY = view.bounds.height - halfHeight

        let boundedX = min(maxX, max(minX, newCenter.x))
        let boundedY = min(maxY, max(minY, newCenter.y))

        overlay.center = CGPoint(x: boundedX, y: boundedY)
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handleDebugFrameOverlayPan(_ gesture: UIPanGestureRecognizer) {
        guard let frameOverlay = gesture.view else { return }

        switch gesture.state {
        case .began, .changed:
            let translation = gesture.translation(in: view)

            // Calculate new center position
            let newCenter = CGPoint(x: frameOverlay.center.x + translation.x,
                                    y: frameOverlay.center.y + translation.y)

            // Ensure the overlay stays within the parent view bounds
            let halfWidth = frameOverlay.bounds.width / 2
            let halfHeight = frameOverlay.bounds.height / 2

            let minX = halfWidth
            let maxX = view.bounds.width - halfWidth
            let minY = halfHeight
            let maxY = view.bounds.height - halfHeight

            let boundedX = min(maxX, max(minX, newCenter.x))
            let boundedY = min(maxY, max(minY, newCenter.y))

            frameOverlay.center = CGPoint(x: boundedX, y: boundedY)
            gesture.setTranslation(.zero, in: view)

            // Update the label with the new frame
            if let label = frameOverlay.subviews.first(where: { $0 is UILabel }) as? UILabel {
                label.text = "Expected GPU View\nFrame: \(frameOverlay.frame)\n(Drag to move, pinch to resize)"
            }

            // Update the current target frame
            currentTargetFrame = frameOverlay.frame

        case .ended:
            // When dragging ends, update the current target frame
            currentTargetFrame = frameOverlay.frame
            DLOG("Debug frame overlay repositioned to: \(frameOverlay.frame)")

        default:
            break
        }
    }

#if !os(tvOS)
    @objc private func handleDebugFrameOverlayPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let frameOverlay = gesture.view else { return }

        switch gesture.state {
        case .began:
            // Store the initial frame when pinch begins
            frameOverlay.layer.setValue(frameOverlay.frame, forKey: "initialFrame")

        case .changed:
            // Get the initial frame and scale it
            if let initialFrame = frameOverlay.layer.value(forKey: "initialFrame") as? CGRect {
                let scale = gesture.scale

                // Calculate new size while maintaining aspect ratio
                let newWidth = initialFrame.width * scale
                let newHeight = initialFrame.height * scale

                // Ensure minimum size
                let minSize: CGFloat = 100
                let finalWidth = max(minSize, newWidth)
                let finalHeight = max(minSize, newHeight)

                // Ensure it doesn't exceed screen bounds
                let maxWidth = view.bounds.width * 0.95
                let maxHeight = view.bounds.height * 0.95

                let boundedWidth = min(maxWidth, finalWidth)
                let boundedHeight = min(maxHeight, finalHeight)

                // Calculate new origin to keep the center point the same
                let newX = frameOverlay.center.x - boundedWidth / 2
                let newY = frameOverlay.center.y - boundedHeight / 2

                // Apply the new frame
                let newFrame = CGRect(x: newX, y: newY, width: boundedWidth, height: boundedHeight)
                frameOverlay.frame = newFrame

                // Update the label with the new frame
                if let label = frameOverlay.subviews.first(where: { $0 is UILabel }) as? UILabel {
                    // Adjust label width based on new frame width
                    let labelWidth = newFrame.width - 20
                    label.frame = CGRect(x: 10, y: 10, width: labelWidth, height: 80)
                    label.text = "Expected GPU View\nFrame: \(newFrame)\n(Drag to move, pinch to resize)"
                }

                // Update handle positions
                if let handle = frameOverlay.subviews.first(where: { $0.frame.origin.x > newFrame.width / 2 && $0.frame.origin.y < newFrame.height / 2 }) {
                    // Top-right handle
                    handle.frame.origin = CGPoint(x: newFrame.width - handle.frame.width - 5, y: 5)
                }

                if let resizeHandle = frameOverlay.subviews.first(where: { $0.frame.origin.x > newFrame.width / 2 && $0.frame.origin.y > newFrame.height / 2 }) {
                    // Bottom-right resize handle
                    resizeHandle.frame.origin = CGPoint(x: newFrame.width - resizeHandle.frame.width - 5,
                                                      y: newFrame.height - resizeHandle.frame.height - 5)
                }

                // Update the current target frame
                currentTargetFrame = newFrame
            }

        case .ended:
            // When pinch ends, update the current target frame
            currentTargetFrame = frameOverlay.frame
            DLOG("Debug frame overlay resized to: \(frameOverlay.frame)")

        default:
            break
        }
    }
#endif

    /// Update the debug info display
    /// Try to position the GPU view using the current target frame
    @objc private func tryFramePositioning() {
        guard let frame = currentTargetFrame else {
            DLOG("No target frame available")
            return
        }

        DLOG("Trying to position GPU view with frame: \(frame)")
        applyFrameToGPUView(frame)

        // Update the debug overlay with success message
        if let frameOverlay = view.subviews.first(where: { $0.tag == 9999 }),
           let label = frameOverlay.subviews.first(where: { $0 is UILabel }) as? UILabel {
            let originalText = label.text ?? ""
            label.text = originalText + "\n✅ Applied!"

            // Flash the overlay to indicate success
            UIView.animate(withDuration: 0.3, animations: {
                frameOverlay.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                    frameOverlay.backgroundColor = UIColor.red.withAlphaComponent(0.3)
                }) { _ in
                    // Reset the label after animation completes
                    if let currentText = label.text, currentText.contains("✅ Applied!") {
                        label.text = originalText
                    }
                }
            }
        }
    }
    /// Reset the GPU view position to default
    @objc private func resetPositioning() {
        DLOG("Resetting GPU view position")

        // Disable custom positioning first
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Explicitly reference properties from PVGPUViewController
            (metalVC as PVGPUViewController).useCustomPositioning = false
        }

        // Reset to default position
        resetGPUViewPosition()
    }

    /// Reset to the originally calculated position from the skin
    @objc private func resetToCalculatedPosition() {
        guard let calculatedFrame = originalCalculatedFrame else {
            DLOG("No calculated frame available")
            return
        }

        DLOG("Resetting to calculated position: \(calculatedFrame)")

        // Update the current target frame
        currentTargetFrame = calculatedFrame

        // Recreate the debug frame overlay with the original calculated frame
        createDebugFrameOverlay(frame: calculatedFrame)

        // Apply the frame to the GPU view
        applyFrameToGPUView(calculatedFrame)

        // Show success message
        if let frameOverlay = view.subviews.first(where: { $0.tag == 9999 }) {
            // Flash the overlay to indicate success
            UIView.animate(withDuration: 0.3, animations: {
                frameOverlay.backgroundColor = UIColor.green.withAlphaComponent(0.5)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                    frameOverlay.backgroundColor = UIColor.red.withAlphaComponent(0.3)
                })
            }
        }
    }


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
#if !os(tvOS)
        let orientation = UIDevice.current.orientation
        let orientationStr = orientation.isPortrait ? "Portrait" : (orientation.isLandscape ? "Landscape" : "Other")
#else
        let orientationStr = "Landspace"
#endif
        // Get FPS if available
        var fpsInfo = "FPS: N/A"
        #if USE_METAL
        if let metalVC = gpuViewController as? PVMetalViewController {
            let fps = metalVC.framesPerSecond
            fpsInfo = "FPS: \(Int(fps))"
        }
        #else
        if let glVC = gpuViewController as? PVGLViewController {
            let fps = glVC.calculatedFramesPerSecond
            fpsInfo = "FPS: \(Int(fps))"
        }
        #endif

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

    // MARK: - Screen Filter Wiring

    /// Reads the current skin's first-screen filter info and applies it to the Metal rendering
    /// pipeline.  When the skin defines no filters the existing filter (if any) is cleared so we
    /// don't bleed a previous skin's effect into the new one.
    ///
    /// Must be called on the main thread; dispatches there automatically if invoked from a
    /// background thread.
    internal func applyScreenFiltersFromCurrentSkin() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.applyScreenFiltersFromCurrentSkin() }
            return
        }

        guard let skin = currentSkin else {
            // No skin active — clear any lingering filter
            applyScreenFilter(nil)
            return
        }

        #if !os(tvOS)
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #else
        let device: DeltaSkinDevice = .tv
        #endif
        let orientation: DeltaSkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait

        // Probe display types in preference order to match the skin that was actually loaded,
        // mirroring the pattern used elsewhere (e.g. applyViewportFromCurrentSkin).
        let displayTypes: [DeltaSkinDisplayType] = [.standard, .edgeToEdge]
        var filterInfo: DeltaSkin.FilterInfo?
        for displayType in displayTypes {
            let traits = DeltaSkinTraits(device: device, displayType: displayType, orientation: orientation)
            if let info = skin.representation(for: traits)?.screens?.first?.filters?.first {
                filterInfo = info
                break
            }
        }

        guard let filterInfo else {
            ILOG("skins: Skin '\(skin.name)' has no screen filters — clearing any previous filter")
            applyScreenFilter(nil)
            return
        }

        // If the user has explicitly selected a filter (not "None"), it takes precedence over
        // skin-defined filters so both effects are not stacked on top of each other.
        // Mirror the pattern used in RetroMenuView: guard against an empty gameId so we don't
        // read/write a shared "ScreenFilter_Game_" key when md5Hash and crc are both empty.
        let md5 = game.md5Hash
        let crc = game.crc
        let gameId: String
        if !md5.isEmpty {
            gameId = md5
        } else if !crc.isEmpty {
            gameId = crc
        } else {
            gameId = ""
        }
        let systemKey = game.system.map { "ScreenFilter_System_\($0.systemIdentifier.rawValue)" }
        let userFilterName: String?
        if gameId.isEmpty {
            // No game identifier — only consult the system-scoped key.
            userFilterName = systemKey.flatMap { UserDefaults.standard.string(forKey: $0) }
        } else {
            let gameKey = "ScreenFilter_Game_\(gameId)"
            userFilterName = UserDefaults.standard.string(forKey: gameKey)
                ?? systemKey.flatMap { UserDefaults.standard.string(forKey: $0) }
        }
        if let name = userFilterName, name != "None" {
            ILOG("skins: User filter '\(name)' is active — clearing skin filter to prevent stacking")
            // Clear any previously applied skin filter so the user filter is the only effect.
            applyScreenFilter(nil)
            return
        }

        // Construct DeltaSkinScreenFilter directly from FilterInfo so that filter-specific
        // configuration (e.g. CIGaussianBlur radius stored on the wrapper) is preserved.
        if let screenFilter = DeltaSkinScreenFilter(filterInfo: filterInfo) {
            ILOG("skins: Applying skin screen filter '\(filterInfo.name)' from skin '\(skin.name)'")
            applyScreenFilter(screenFilter)
        } else {
            ELOG("skins: Failed to create DeltaSkinScreenFilter for '\(filterInfo.name)'")
            applyScreenFilter(nil)
        }
    }
}
