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

        guard let frameValue = notification.userInfo?["frame"] as? NSValue else { return }

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
                if let selectedIdentifier = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: systemId),
                   let skin = manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) {
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
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in self?.applyViewportFromCurrentSkin() }
            return
        }

        // Prevent re-entrant calls that cause layout loops
        guard !isApplyingViewport else {
            DLOG("🎮 SKIN: Already applying viewport, skipping to prevent loop")
            return
        }

        isApplyingViewport = true
        defer { isApplyingViewport = false }

        // Skip if view bounds are invalid - will retry on next frame update
        // Don't force layout here - it causes call loops with viewDidLayoutSubviews
        guard view.bounds.width > 0 && view.bounds.height > 0 else {
            DLOG("🎮 SKIN: View bounds invalid: \(view.bounds), skipping (will retry)")
            return
        }

        // Z-order will be ensured after frame application to avoid redundant layout passes

        if core.supportsDualScreens {
            applyDualScreenViewport()
            return
        }

        // Use notification frame if available (most accurate)
        if let frame = currentTargetFrame, isValidFrame(frame) {
            DLOG("🎮 SKIN: Using notification frame: \(frame)")
            applyFrameToGPUView(frame)
            return
        }

        // Calculate frame - works the same for RetroArch and non-RetroArch cores
        // Load skin from cache synchronously if available, otherwise proceed without skin
        if currentSkin == nil, let systemId = game.system?.systemIdentifier {
            let manager = DeltaSkinManager.shared
            if manager.skinsAreLoaded {
                if let selectedIdentifier = DeltaSkinPreferences.shared.selectedSkinIdentifier(for: systemId),
                   let skin = manager.loadedSkins.first(where: { $0.identifier == selectedIdentifier }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found skin in cache: \(skin.name)")
                } else if let gameType = DeltaSkinGameType(systemIdentifier: systemId),
                          let skin = manager.loadedSkins.first(where: {
                              $0.gameType == gameType || (systemId == .GB && $0.gameType == .gbc)
                          }) {
                    currentSkin = skin
                    DLOG("🎮 SKIN: Found default skin in cache: \(skin.name)")
                }
            }
        }

        // Try to calculate frame if we have a skin, otherwise use default positioning
        if let frame = currentSkinViewportFrame(), isValidFrame(frame) {
            DLOG("🎮 SKIN: Using calculated frame: \(frame)")
            currentTargetFrame = frame
            applyFrameToGPUView(frame)
        } else {
            DLOG("🎮 SKIN: No valid frame available (skin: \(currentSkin?.name ?? "nil")), using default positioning")
            resetGPUViewPosition()
        }
    }

    /// Calculate viewport frame (fallback, internal for dual screen support)
    internal func currentSkinViewportFrame() -> CGRect? {
        guard let skin = currentSkin else { return nil }

        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        let orientation: DeltaSkinOrientation = (currentOrientation == .landscape) ? .landscape : .portrait
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

            // outputFrame from DeltaSkinScreen should typically be normalized (0-1)
            // However, some skins might provide absolute pixel coordinates
            // Use a conservative threshold (> 10.0) to detect absolute pixels vs normalized
            let normalizedFrame: CGRect
            if outputFrame.width > 10.0 || outputFrame.height > 10.0 {
                // Values are large, likely absolute pixels - normalize by mappingSize
                if mappingSize.width > 0 && mappingSize.height > 0 {
                    normalizedFrame = CGRect(
                        x: outputFrame.minX / mappingSize.width,
                        y: outputFrame.minY / mappingSize.height,
                        width: outputFrame.width / mappingSize.width,
                        height: outputFrame.height / mappingSize.height
                    )
                    DLOG("🎮 SKIN: Normalized outputFrame from pixels: \(outputFrame) -> \(normalizedFrame)")
                } else {
                    DLOG("🎮 SKIN: Invalid mappingSize, treating outputFrame as normalized")
                    normalizedFrame = outputFrame
                }
            } else {
                // Values are small, assume already normalized (0-1) - use as-is
                normalizedFrame = outputFrame
            }

            // Scale normalized frame by layout dimensions and add offset
            var finalFrame = CGRect(
                x: xOffset + (normalizedFrame.minX * layoutWidth),
                y: yOffset + (normalizedFrame.minY * layoutHeight),
                width: normalizedFrame.width * layoutWidth,
                height: normalizedFrame.height * layoutHeight
            )

            // Clamp frame to viewport bounds to prevent extending outside
            finalFrame.origin.x = max(0, min(finalFrame.origin.x, viewSize.width - finalFrame.width))
            finalFrame.origin.y = max(0, min(finalFrame.origin.y, viewSize.height - finalFrame.height))
            finalFrame.size.width = min(finalFrame.width, viewSize.width)
            finalFrame.size.height = min(finalFrame.height, viewSize.height)

            DLOG("🎮 SKIN: Calculated frame from screens - outputFrame: \(outputFrame), normalized: \(normalizedFrame), layout: \(scaledWidth)x\(scaledHeight), final: \(finalFrame)")
            return finalFrame
        }

        // Default: center in available space
        return CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
    }

    /// Apply frame to GPU view (internal for dual screen support)
    internal func applyFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else { return }

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
        if let viewport = core.bridge as? EmulatorCoreViewportPositioning,
           let parent = core.touchViewController?.view {
            // Ensure parent has valid bounds
            // Don't force layout - it causes call loops
            guard parent.bounds.width > 0 && parent.bounds.height > 0 else {
                ELOG("🎮 SKIN: Parent bounds invalid: \(parent.bounds), skipping (will retry)")
                return
            }

            viewport.setUseCustomRenderViewLayout(true)

            // Convert coordinates from self.view to parent coordinate system
            // Don't force layout here - it causes call loops
            // Layout will happen naturally when frame is applied
            let rectInParent = view.convert(frame, to: parent)

            // Validate converted rect
            guard isValidFrame(rectInParent) else {
                ELOG("🎮 SKIN: Invalid converted rect: \(rectInParent) from frame: \(frame)")
                return
            }

            // Clamp to parent bounds for both portrait and landscape
            let orientation: SkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait

            // Clamp to parent bounds - ensure frame stays within valid bounds
            // For portrait mode, the frame calculation should already account for skin positioning
            // but we need to ensure the converted coordinates are correct
            let clampedRect = CGRect(
                x: max(0, min(rectInParent.origin.x, parent.bounds.width - rectInParent.width)),
                y: max(0, min(rectInParent.origin.y, parent.bounds.height - rectInParent.height)),
                width: min(rectInParent.width, parent.bounds.width),
                height: min(rectInParent.height, parent.bounds.height)
            )

            // Debug logging for portrait mode to help diagnose positioning issues
            if orientation == .portrait {
                let parentOrigin = view.convert(CGRect.zero, to: parent)
                DLOG("🎮 SKIN: Portrait conversion - frame: \(frame), rectInParent: \(rectInParent), parentOrigin: \(parentOrigin), parent.bounds: \(parent.bounds), clamped: \(clampedRect)")
            }

            // Validate clamped rect
            guard isValidFrame(clampedRect) else {
                ELOG("🎮 SKIN: Invalid clamped rect: \(clampedRect)")
                return
            }

            DLOG("🎮 SKIN: RetroArch viewport (\(orientation == .landscape ? "landscape" : "portrait")): original=\(rectInParent), clamped=\(clampedRect), parent.bounds=\(parent.bounds), view.bounds=\(view.bounds)")
            viewport.applyRenderViewFrameInTouchView(clampedRect)

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
