import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge
import PVUIBase

extension PVEmulatorViewController {

    /// Update GPU view position based on DeltaSkin screen information
    func updateGPUViewPositionForDeltaSkin() {
        guard gpuViewController.view != nil else { return }

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFrameUpdated), name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)

        // Also observe when skin is loaded to set currentSkin
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinLoaded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSkinLoaded), name: NSNotification.Name("DeltaSkinLoaded"), object: nil)

        setupDualScreenObservers()

        if isDeltaSkinEnabled, currentSkin != nil {
            applyViewportFromCurrentSkin()
        } else {
            resetGPUViewPosition()
        }
    }

    /// Handle skin loaded notification to set currentSkin
    @objc private func handleSkinLoaded(_ notification: Notification) {
        guard let skinId = notification.userInfo?["skinId"] as? String else { return }

        // Load the skin if we don't have it yet - use sync cache lookup like RetroArch
        if currentSkin == nil || currentSkin?.identifier != skinId {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded {
                if let skin = manager.loadedSkins.first(where: { $0.identifier == skinId }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Set currentSkin from notification: \(skin.name)")
                    // Re-apply viewport with new skin
                    applyViewportFromCurrentSkin()
                }
            }
        }
    }

    /// Handle frame update notification from skin
    @objc private func handleFrameUpdated(_ notification: Notification) {
        ILOG("🎮 SKIN: handleFrameUpdated called")

        // Skip handling for dual screen systems - let handleSkinFrameUpdated handle it
        if core.supportsDualScreens {
            DLOG("🎮 SKIN: Dual screen system detected, delegating to dual screen handler")
            return
        }

        // MUST be on main thread - apply synchronously like RetroArch cores
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in
                self?.handleFrameUpdated(notification)
            }
            return
        }

        guard let frameValue = notification.userInfo?["frame"] as? NSValue else {
            ELOG("🎮 SKIN: No frame in notification")
            return
        }

        let frame = frameValue.cgRectValue

        // Validate frame
        guard isValidFrame(frame) else {
            ELOG("🎮 SKIN: Invalid frame: \(frame)")
            return
        }

        // Check if frame has actually changed to prevent unnecessary updates
        if let currentFrame = currentTargetFrame,
           abs(currentFrame.origin.x - frame.origin.x) < 0.5 &&
           abs(currentFrame.origin.y - frame.origin.y) < 0.5 &&
           abs(currentFrame.width - frame.width) < 0.5 &&
           abs(currentFrame.height - frame.height) < 0.5 {
            DLOG("🎮 SKIN: Frame unchanged, skipping update: \(frame)")
            return
        }

        currentTargetFrame = frame
        DLOG("🎮 SKIN: Received frame: \(frame)")

        // Ensure skin is loaded - use sync cache lookup like RetroArch cores
        if currentSkin == nil, let systemId = game.system?.systemIdentifier {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded {
                let orientation: SkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
                if let selectedIdentifier = DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                    for: systemId,
                    gameId: game.id,
                    orientation: orientation
                ), let skin = manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found skin in cache for frame update: \(skin.name)")
                } else if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                          let skin = manager.loadedSkins.first(where: {
                              $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                          }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found default skin in cache for frame update: \(skin.name)")
                }
            }
        }

        // Apply frame synchronously - exactly like RetroArch cores do
        // No async, no delays, no waiting
        guard !isApplyingViewport else {
            DLOG("🎮 SKIN: Already applying viewport, skipping")
            return
        }
        applyFrameToGPUView(frame)
    }

    /// Validate frame
    private func isValidFrame(_ frame: CGRect) -> Bool {
        return frame.width > 0 && frame.height > 0 &&
               frame.width < 10000 && frame.height < 10000 &&
               frame.width.isFinite && frame.height.isFinite &&
               frame.origin.x.isFinite && frame.origin.y.isFinite
    }

    /// Apply viewport from current skin
    /// Synchronous like RetroArch cores - no async, no delays
    internal func applyViewportFromCurrentSkin() {
        ILOG("🎮 SKIN: applyViewportFromCurrentSkin called - view.bounds=\(view.bounds)")

        guard Thread.isMainThread else {
            ILOG("🎮 SKIN: Not on main thread, dispatching sync")
            DispatchQueue.main.sync { [weak self] in self?.applyViewportFromCurrentSkin() }
            return
        }

        // Prevent re-entrant calls that cause layout loops
        guard !isApplyingViewport else {
            ILOG("🎮 SKIN: Already applying viewport, skipping to prevent loop")
            return
        }

        isApplyingViewport = true
        defer { isApplyingViewport = false }

        // Skip if view bounds are invalid - will retry on next frame update
        // Don't force layout here - it causes call loops with viewDidLayoutSubviews
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            ILOG("🎮 SKIN: View bounds invalid: \(view.bounds), skipping (will retry)")
            return
        }

        ILOG("🎮 SKIN: View bounds valid, continuing - core.supportsDualScreens=\(core.supportsDualScreens)")

        // Z-order will be ensured after frame application to avoid redundant layout passes

        if core.supportsDualScreens {
            ILOG("🎮 SKIN: Dual screen system, calling applyDualScreenViewport")
            applyDualScreenViewport()
            return
        }

        // Use notification frame if available (most accurate)
        // For default skin, always prefer notification frame to avoid double adjustment during rotation
        ILOG("🎮 SKIN: Checking currentTargetFrame: \(String(describing: currentTargetFrame))")
        if let frame = currentTargetFrame, isValidFrame(frame) {
            ILOG("🎮 SKIN: Using notification frame: \(frame)")
            applyFrameToGPUView(frame)
            return
        }

        // If using default skin (no explicit skin), wait briefly for notification frame
        // This ensures rotation uses the same code path as initial boot (notification-based)
        let isDefaultSkin = currentSkin == nil || (currentSkin?.identifier == "default" || currentSkin?.name.lowercased().contains("default") == true)
        if isDefaultSkin {
            ILOG("🎮 SKIN: Default skin detected, waiting briefly for notification frame")
            // Give the ViewportUpdater a chance to send the notification (it fires immediately now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                guard let self = self else { return }
                // Check again for notification frame
                if let frame = self.currentTargetFrame, self.isValidFrame(frame) {
                    ILOG("🎮 SKIN: Using notification frame after brief wait: \(frame)")
                    self.applyFrameToGPUView(frame)
                    return
                }
                // If still no notification frame, proceed with calculation
                self.continueViewportCalculation()
            }
            return
        }

        ILOG("🎮 SKIN: No valid notification frame, will calculate")
        continueViewportCalculation()
    }

    /// Continue viewport calculation (extracted to avoid duplication)
    private func continueViewportCalculation() {

        // Calculate frame - works the same for RetroArch and non-RetroArch cores
        // Load skin from cache synchronously if available, otherwise proceed without skin
        ILOG("🎮 SKIN: currentSkin: \(String(describing: currentSkin?.name))")

        // Ensure view has been laid out before calculating viewport
        // This is critical on initial load when bounds might be incorrect
        view.layoutIfNeeded()

        // Validate view bounds before using them
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            ILOG("🎮 SKIN: View bounds invalid (\(view.bounds)), deferring viewport calculation")
            // Schedule retry after layout
            DispatchQueue.main.async { [weak self] in
                self?.applyViewportFromCurrentSkin()
            }
            return
        }

        // During rotation, use view bounds to determine orientation instead of currentOrientation
        // currentOrientation may be stale during rotation transitions
        let boundsIsLandscape = view.bounds.width > view.bounds.height
        let boundsIsPortrait = view.bounds.height > view.bounds.width

        // Only defer if bounds are clearly invalid (both dimensions equal or zero)
        // During rotation, bounds will update before currentOrientation, so use bounds directly
        guard boundsIsLandscape || boundsIsPortrait else {
            ILOG("🎮 SKIN: View bounds invalid during rotation - bounds: \(view.bounds), deferring")
            DispatchQueue.main.async { [weak self] in
                self?.applyViewportFromCurrentSkin()
            }
            return
        }

        if currentSkin == nil, let systemId = game.system?.systemIdentifier {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded {
                // Use view bounds to determine orientation (more reliable during rotation)
                let boundsIsLandscape = view.bounds.width > view.bounds.height
                let orientation: SkinOrientation = boundsIsLandscape ? .landscape : .portrait
                if let selectedIdentifier = DeltaSkinSelectionManager.shared.effectiveSkinIdentifier(
                    for: systemId,
                    gameId: game.id,
                    orientation: orientation
                ), let skin = manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found skin in cache: \(skin.name)")
                } else if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                          let skin = manager.loadedSkins.first(where: {
                              $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                          }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found default skin in cache: \(skin.name)")
                }
            } else {
                // Skin manager not loaded yet - defer viewport calculation until skin loads
                ILOG("🎮 SKIN: Skin manager not loaded yet, deferring viewport calculation")
                return
            }
        }

        // Try to calculate frame if we have a skin, otherwise use default positioning
        ILOG("🎮 SKIN: Attempting to calculate frame from skin")
        if let frame = currentSkinViewportFrame(), isValidFrame(frame) {
            ILOG("🎮 SKIN: Using calculated frame: \(frame)")
            currentTargetFrame = frame
            applyFrameToGPUView(frame)
        } else {
            ILOG("🎮 SKIN: No valid frame available (skin: \(currentSkin?.name ?? "nil")), using default positioning")
            resetGPUViewPosition()
        }
    }

    /// Calculate viewport frame (fallback, internal for dual screen support)
    internal func currentSkinViewportFrame() -> CGRect? {
        guard let skin = currentSkin else { return nil }

        // Ensure view has valid bounds before calculating viewport
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            DLOG("🎮 SKIN: View bounds invalid (\(view.bounds)) in currentSkinViewportFrame, returning nil")
            return nil
        }

        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        // Use view bounds to determine orientation during rotation (more reliable than currentOrientation)
        let boundsIsLandscape = view.bounds.width > view.bounds.height
        let orientation: DeltaSkinOrientation = boundsIsLandscape ? .landscape : .portrait
        let traits = DeltaSkinTraits(device: device, displayType: .standard, orientation: orientation)

        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        let viewSize = view.bounds.size
        let scale = min(viewSize.width / mappingSize.width, viewSize.height / mappingSize.height)
        let scaledWidth = mappingSize.width * scale
        let scaledHeight = mappingSize.height * scale
        let xOffset = (viewSize.width - scaledWidth) / 2
        let yOffset = (traits.device == .iphone && traits.orientation == .portrait) ?
            (viewSize.height - scaledHeight) : ((viewSize.height - scaledHeight) / 2)

        // Try to get screen frame from skin
        // Note: outputFrame from skin.screens() should already be normalized (0-1)
        if let screens = skin.screens(for: traits),
           let screen = screens.first,
           let outputFrame = screen.outputFrame {
            let layoutWidth = scaledWidth
            let layoutHeight = scaledHeight

            // outputFrame from DeltaSkinScreen could be normalized (0-1) or absolute pixels
            // Check if values exceed mappingSize or are clearly absolute (> 1.0 and < mappingSize)
            let normalizedFrame: CGRect
            let isAbsolutePixels = outputFrame.width > mappingSize.width || outputFrame.height > mappingSize.height ||
                                   (outputFrame.width > 1.0 && outputFrame.height > 1.0 &&
                                    outputFrame.width < mappingSize.width && outputFrame.height < mappingSize.height)

            if isAbsolutePixels || (outputFrame.width > 10.0 || outputFrame.height > 10.0) {
                // Values are absolute pixels - normalize by mappingSize
                if mappingSize.width > 0 && mappingSize.height > 0 {
                    normalizedFrame = CGRect(
                        x: outputFrame.minX / mappingSize.width,
                        y: outputFrame.minY / mappingSize.height,
                        width: outputFrame.width / mappingSize.width,
                        height: outputFrame.height / mappingSize.height
                    )
                    DLOG("🎮 SKIN: Normalized outputFrame from pixels: \(outputFrame) -> \(normalizedFrame), mappingSize: \(mappingSize)")
                } else {
                    DLOG("🎮 SKIN: Invalid mappingSize, treating outputFrame as normalized")
                    normalizedFrame = outputFrame
                }
            } else {
                // Values are normalized (0-1) - use as-is
                normalizedFrame = outputFrame
                DLOG("🎮 SKIN: Using outputFrame as normalized: \(outputFrame)")
            }

            // Scale normalized frame by layout dimensions and add offset
            let finalFrame = CGRect(
                x: xOffset + (normalizedFrame.minX * layoutWidth),
                y: yOffset + (normalizedFrame.minY * layoutHeight),
                width: normalizedFrame.width * layoutWidth,
                height: normalizedFrame.height * layoutHeight
            )

            // Don't clamp here - let RetroArch coordinate conversion handle it
            // Clamping at this stage can cause incorrect sizing for RetroArch cores

            DLOG("🎮 SKIN: Calculated frame from screens - outputFrame: \(outputFrame), normalized: \(normalizedFrame), layout: \(scaledWidth)x\(scaledHeight), final: \(finalFrame)")
            return finalFrame
        }

        // Default: center in available space
        return CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
    }

    /// Apply frame to GPU view (internal for dual screen support)
    internal func applyFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("🎮 SKIN: applyFrameToGPUView - gpuViewController.view is nil")
            return
        }

        ILOG("🎮 SKIN: applyFrameToGPUView called with frame=\(frame)")
        ILOG("🎮 SKIN:   gameScreenView=\(gameScreenView), frame=\(gameScreenView.frame)")
        ILOG("🎮 SKIN:   core.bridge is EmulatorCoreViewportPositioning? \(core.bridge is EmulatorCoreViewportPositioning)")

        // CRITICAL: Validate frame before applying
        guard isValidFrame(frame) else {
            ELOG("🎮 SKIN: Invalid frame passed to applyFrameToGPUView: \(frame)")
            return
        }

        // Ensure view has valid bounds before coordinate conversion
        // Don't force layout - it causes call loops
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            ELOG("🎮 SKIN: View bounds invalid: \(view.bounds), skipping (will retry)")
            return
        }

        // Check if frame has actually changed to prevent unnecessary updates
        let currentFrame = gameScreenView.frame
        if abs(currentFrame.origin.x - frame.origin.x) < 0.5 &&
           abs(currentFrame.origin.y - frame.origin.y) < 0.5 &&
           abs(currentFrame.width - frame.width) < 0.5 &&
           abs(currentFrame.height - frame.height) < 0.5 {
            DLOG("🎮 SKIN: GPU view frame unchanged, skipping update")
            return
        }

        // Handle cores that support viewport positioning (RetroArch, PPSSPP, etc.)
        if let viewport = core.bridge as? EmulatorCoreViewportPositioning {
            ILOG("🎮 SKIN: ========== applyFrameToGPUView START (EmulatorCoreViewportPositioning) ==========")
            ILOG("🎮 SKIN: Input frame (in self.view coords): \(frame)")
            ILOG("🎮 SKIN: self.view: \(view), frame: \(view.frame), bounds: \(view.bounds)")
            ILOG("🎮 SKIN: gameScreenView: \(gameScreenView), frame: \(gameScreenView.frame), bounds: \(gameScreenView.bounds)")
            ILOG("🎮 SKIN: gameScreenView.superview: \(gameScreenView.superview?.description ?? "nil")")
            if let superview = gameScreenView.superview {
                ILOG("🎮 SKIN: gameScreenView.superview.frame: \(superview.frame), bounds: \(superview.bounds)")
            }

            /// Determine the correct parent view to use
            /// Priority: 1) touchViewController.view, 2) gpuViewController.mtlView (for Metal/PPSSPP), 3) gpuViewController.view, 4) renderDelegate.view
            let parent: UIView?
            if let touchView = core.touchViewController?.view {
                parent = touchView
                ILOG("🎮 SKIN: Using touchViewController.view as parent: \(touchView), frame: \(touchView.frame), bounds: \(touchView.bounds)")
            } else if let metalVC = gpuViewController as? PVMetalViewController,
                      let mtlView = metalVC.mtlView {
                /// For PPSSPP with Metal, m_view is added to mtlView
                parent = mtlView
                ILOG("🎮 SKIN: Using gpuViewController.mtlView as parent: \(mtlView), frame: \(mtlView.frame), bounds: \(mtlView.bounds)")
            } else if let gpuView = gpuViewController.view {
                /// For PPSSPP, gpuViewController.view is reliable since it's always available
                parent = gpuView
                ILOG("🎮 SKIN: Using gpuViewController.view as parent: \(gpuView), frame: \(gpuView.frame), bounds: \(gpuView.bounds)")
            } else if let renderDelegate = core.renderDelegate as? UIViewController {
                /// renderDelegate is expected to be a UIViewController conforming to PVRenderDelegate
                parent = renderDelegate.view
                ILOG("🎮 SKIN: Using renderDelegate.view as parent: \(renderDelegate.view), frame: \(renderDelegate.view.frame), bounds: \(renderDelegate.view.bounds)")
            } else {
                parent = nil
                ILOG("🎮 SKIN: No parent view found")
            }

            guard let parent = parent else {
                /// For PPSSPP: if view hierarchy isn't ready, the Objective-C code will store the frame
                /// in pendingCustomFrame and apply it when setupView completes. We still call it so
                /// PPSSPP can handle the deferred application.
                /// For other cores (RetroArch), we should have a parent view by this point.
                let coreType = type(of: core).description()
                if coreType.contains("PPSSPP") {
                    DLOG("🎮 SKIN: PPSSPP view hierarchy not ready, delegating to Objective-C pendingCustomFrame mechanism")
                } else {
                    DLOG("🎮 SKIN: No parent view found, delegating to Objective-C fallback logic")
                }
                viewport.setUseCustomRenderViewLayout(true)
                viewport.applyRenderViewFrameInTouchView(frame)
                return
            }

            ILOG("🎮 SKIN: Parent view hierarchy:")
            ILOG("🎮 SKIN:   parent: \(parent), frame: \(parent.frame), bounds: \(parent.bounds)")
            ILOG("🎮 SKIN:   parent.superview: \(parent.superview?.description ?? "nil")")
            if let parentSuperview = parent.superview {
                ILOG("🎮 SKIN:   parent.superview.frame: \(parentSuperview.frame), bounds: \(parentSuperview.bounds)")
            }
            ILOG("🎮 SKIN:   view == parent? \(view == parent)")
            if view != parent {
                let viewOriginInParent = view.convert(CGPoint.zero, to: parent)
                ILOG("🎮 SKIN:   view origin in parent coords: \(viewOriginInParent)")
            }

            // Ensure parent has valid bounds
            // Don't force layout - it causes call loops
            guard parent.bounds.width > 0 && parent.bounds.height > 0 else {
                ELOG("🎮 SKIN: Parent bounds invalid: \(parent.bounds), skipping (will retry)")
                return
            }

            DLOG("🎮 SKIN: Calling setUseCustomRenderViewLayout(true) for RetroArch")
            viewport.setUseCustomRenderViewLayout(true)

            // For RetroArch/PPSSPP: Pass frame as-is in self.view coordinates
            // The core will handle coordinate conversion internally
            // This matches how other cores work and prevents double conversion
            let finalRect = frame

            // Validate frame
            guard isValidFrame(finalRect) else {
                ELOG("🎮 SKIN: Invalid frame: \(finalRect)")
                return
            }

            ILOG("🎮 SKIN: Calling viewport.applyRenderViewFrameInTouchView with frame: \(finalRect)")
            ILOG("🎮 SKIN:   Frame is in self.view coordinates: \(view)")
            ILOG("🎮 SKIN:   Parent view: \(parent)")
            viewport.setUseCustomRenderViewLayout(true)
            viewport.applyRenderViewFrameInTouchView(finalRect)
            ILOG("🎮 SKIN: Finished calling applyRenderViewFrameInTouchView")
            ILOG("🎮 SKIN: ========== applyFrameToGPUView END ==========")

            // Ensure GPU view is visible and below skin
            ensureGPUViewVisibilityAndZOrder()

            // Frame applied - no verification delay needed (blocks like RetroArch)
            return
        }


        // Apply to Metal view
        if let metalVC = gpuViewController as? PVMetalViewController {
            (metalVC as PVGPUViewController).useCustomPositioning = true
            (metalVC as PVGPUViewController).customFrame = frame
            metalVC.view.autoresizingMask = []
            metalVC.mtlView.autoresizingMask = []

            // Set frame without triggering unnecessary layouts
            // Only update if frame actually changed to prevent loops
            if abs(metalVC.view.frame.origin.x - frame.origin.x) > 0.5 ||
               abs(metalVC.view.frame.origin.y - frame.origin.y) > 0.5 ||
               abs(metalVC.view.frame.width - frame.width) > 0.5 ||
               abs(metalVC.view.frame.height - frame.height) > 0.5 {
                UIView.performWithoutAnimation {
                    metalVC.view.frame = frame
                    metalVC.mtlView.frame = metalVC.view.bounds
                }
            }

            // Verify frame was set correctly (log only, no retry delays)
            if metalVC.view.frame.width == 0 || metalVC.view.frame.height == 0 {
                ELOG("🎮 SKIN: WARNING - Metal view frame is 0x0 after setting! frame=\(frame), actual=\(metalVC.view.frame)")
            }

            // CRITICAL: Set drawable size to match viewport EXACTLY (no aspect ratio preservation)
            let scale = metalVC.renderSettings.nativeScaleEnabled ?
                (metalVC.view.window?.screen.scale ?? UIScreen.main.scale) : 1.0
            let drawableSize = CGSize(
                width: frame.width * scale,
                height: frame.height * scale
            )

            // Only update drawable size if it has changed significantly
            let currentDrawableSize = metalVC.mtlView.drawableSize
            if abs(currentDrawableSize.width - drawableSize.width) > 0.5 ||
               abs(currentDrawableSize.height - drawableSize.height) > 0.5 {
                DLOG("🎮 SKIN: Setting drawable size: \(drawableSize) (frame: \(frame), scale: \(scale))")
                metalVC.mtlView.drawableSize = drawableSize
                metalVC.mtlView.contentScaleFactor = scale
            } else {
                DLOG("🎮 SKIN: Drawable size unchanged, skipping update")
            }

            metalVC.view.isHidden = false
            metalVC.mtlView.isHidden = false

            // Drawable size set - no verification delay (blocks like RetroArch)
        } else {
            // Handle GL views (PVGLViewController)
            (gpuViewController as PVGPUViewController).useCustomPositioning = true
            (gpuViewController as PVGPUViewController).customFrame = frame
            gameScreenView.autoresizingMask = []

            // Set frame without triggering unnecessary layouts
            // Only update if frame actually changed to prevent loops
            if abs(gameScreenView.frame.origin.x - frame.origin.x) > 0.5 ||
               abs(gameScreenView.frame.origin.y - frame.origin.y) > 0.5 ||
               abs(gameScreenView.frame.width - frame.width) > 0.5 ||
               abs(gameScreenView.frame.height - frame.height) > 0.5 {
                UIView.performWithoutAnimation {
                    gameScreenView.frame = frame
                }
            }

            // Verify frame was set correctly (log only, no retry delays)
            if gameScreenView.frame.width == 0 || gameScreenView.frame.height == 0 {
                ELOG("🎮 SKIN: WARNING - GL view frame is 0x0 after setting! frame=\(frame), actual=\(gameScreenView.frame)")
            }

            gameScreenView.isHidden = false

            // For GL views, ensure the GL context is still current after frame change
            if let glVC = gpuViewController as? PVGLViewController {
                DLOG("🎮 SKIN: Applied frame to GL view: \(frame), actual: \(gameScreenView.frame)")
                // GL context management is handled by PVGLViewController
            }
        }

        ensureGPUViewVisibilityAndZOrder()
    }

    /// Ensure GPU view is visible and below skin
    internal func ensureGPUViewVisibilityAndZOrder() {
        guard let gameScreenView = gpuViewController.view else { return }

        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            // Only adjust z-order if not already directly below the skin container
            if let gameIndex = view.subviews.firstIndex(of: gameScreenView),
               let skinIndex = view.subviews.firstIndex(of: skinContainerView) {
                // We want game view to be immediately below skin (index just before skin)
                if !(gameIndex == skinIndex - 1) {
                    view.insertSubview(gameScreenView, belowSubview: skinContainerView)
                }
            } else {
                view.insertSubview(gameScreenView, belowSubview: skinContainerView)
            }
        }

        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            mtlView.isHidden = false
            mtlView.alpha = 1.0
        }
    }

    /// Reset GPU view to default position
    internal func resetGPUViewPosition() {
        guard let gameScreenView = gpuViewController.view else { return }

        // Ensure view has valid bounds before resetting
        view.layoutIfNeeded()
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            ILOG("🎮 SKIN: View bounds invalid (\(view.bounds)) in resetGPUViewPosition, deferring")
            DispatchQueue.main.async { [weak self] in
                self?.resetGPUViewPosition()
            }
            return
        }

        UIView.performWithoutAnimation {
            gameScreenView.frame = view.bounds
        }
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.contentMode = .scaleAspectFit
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        if let metalVC = gpuViewController as? PVMetalViewController {
            UIView.performWithoutAnimation {
                metalVC.mtlView.frame = view.bounds
            }
            metalVC.mtlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            metalVC.mtlView.contentMode = .scaleAspectFit
            (metalVC as PVGPUViewController).useCustomPositioning = false
        }


        ensureGPUViewVisibilityAndZOrder()
    }
}
