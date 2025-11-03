import UIKit
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge

/// Extension to handle dual screen systems like 3DS with skin support
extension PVEmulatorViewController {


    /// Check if the current core supports dual screens
    private var isDualScreenSystem: Bool {
        return core.supportsDualScreens
    }

    /// Get the emuThreeDS bridge if available
    private var emuThreeBridge: Any? {
        guard isDualScreenSystem,
              let bridge = core.bridge as? (any NSObjectProtocol) else {
            return nil
        }
        return bridge
    }

    /// Get swap screen state from emuThreeDS core
    private var isScreenSwapped: Bool {
        guard let bridge = emuThreeBridge else { return false }
        // Access swapScreen property via runtime
        if let value = (bridge as AnyObject).value(forKey: "swapScreen") as? Bool {
            return value
        }
        return false
    }

    /// Compute viewport frame for dual screen systems using screen groups
    internal func currentDualScreenViewportFrame() -> CGRect? {
        guard isDualScreenSystem,
              isDeltaSkinEnabled,
              let skin = currentSkin else {
            return nil
        }

        let device: DeltaSkinDevice = {
            #if os(tvOS)
            return .tv
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #endif
        }()
        let orientation: DeltaSkinOrientation = (currentOrientation == .landscape) ? .landscape : .portrait
        let traits = DeltaSkinTraits(
            device: device,
            displayType: .standard,
            orientation: orientation
        )

        guard let mappingSize = skin.mappingSize(for: traits) else { return nil }

        // Get screen groups for dual screen systems
        guard let screenGroups = skin.screenGroups(for: traits),
              let mainGroup = screenGroups.first,
              mainGroup.screens.count >= 2 else {
            // Fall back to single screen positioning
            return currentSkinViewportFrame()
        }

        // Use the EXACT same scale calculation as DeltaSkinView.calculateLayout
        let viewSize = view.bounds.size
        var scale: CGFloat

        // Match DeltaSkinView's layout calculation exactly
        if traits.device == .iphone && traits.orientation == .portrait {
            // Start with width scale to fill screen
            scale = viewSize.width / mappingSize.width

            // Calculate resulting height
            let scaledHeight = mappingSize.height * scale

            // If height exceeds screen, scale down while maintaining aspect ratio
            if scaledHeight > viewSize.height {
                let heightScale = viewSize.height / mappingSize.height
                scale = min(scale, heightScale)
            }
        } else {
            // For landscape, use standard fit scaling
            scale = min(
                viewSize.width / mappingSize.width,
                viewSize.height / mappingSize.height
            )
        }

        let scaledWidth = mappingSize.width * scale
        let scaledHeight = mappingSize.height * scale

        // Center horizontally
        let xOffset = (viewSize.width - scaledWidth) / 2

        // Match DeltaSkinView's Y offset calculation exactly
        // For portrait mode on iPhone, position at bottom of screen
        // For landscape or iPad, center vertically
        let yOffset: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Position at bottom of screen
            yOffset = viewSize.height - scaledHeight
        } else {
            // Center vertically
            yOffset = (viewSize.height - scaledHeight) / 2
        }

        let offset = CGPoint(x: xOffset, y: yOffset)

        // Get both screens
        let screens = mainGroup.screens.sorted { screen1, screen2 in
            guard let frame1 = screen1.outputFrame, let frame2 = screen2.outputFrame else {
                return false
            }
            // Sort by Y position (top screen first)
            return frame1.minY < frame2.minY
        }

        guard screens.count >= 2,
              let topScreenFrame = screens[0].outputFrame,
              let bottomScreenFrame = screens[1].outputFrame else {
            return currentSkinViewportFrame()
        }

        // Determine which screen is which based on swap state
        let actualTopFrame = isScreenSwapped ? bottomScreenFrame : topScreenFrame
        let actualBottomFrame = isScreenSwapped ? topScreenFrame : bottomScreenFrame

        // Match DeltaSkinView.screenView calculation EXACTLY
        // In screenView: frame.minX * layout.width, frame.minY * layout.height
        // Then .position(x: scaledFrame.midX, y: scaledFrame.midY) centers it
        // So absolute frame origin = layout.xOffset + (scaledFrame.midX - scaledFrame.width/2)

        // Calculate frames in layout coordinate space (using scaledWidth/scaledHeight)
        let topScaledInLayout = CGRect(
            x: actualTopFrame.minX * scaledWidth,
            y: actualTopFrame.minY * scaledHeight,
            width: actualTopFrame.width * scaledWidth,
            height: actualTopFrame.height * scaledHeight
        )

        let bottomScaledInLayout = CGRect(
            x: actualBottomFrame.minX * scaledWidth,
            y: actualBottomFrame.minY * scaledHeight,
            width: actualBottomFrame.width * scaledWidth,
            height: actualBottomFrame.height * scaledHeight
        )

        // Convert to absolute view coordinates
        // .position() centers views, so frame origin = offset + center - size/2
        let topScaled = CGRect(
            x: xOffset + topScaledInLayout.midX - (topScaledInLayout.width / 2),
            y: yOffset + topScaledInLayout.midY - (topScaledInLayout.height / 2),
            width: topScaledInLayout.width,
            height: topScaledInLayout.height
        )

        let bottomScaled = CGRect(
            x: xOffset + bottomScaledInLayout.midX - (bottomScaledInLayout.width / 2),
            y: yOffset + bottomScaledInLayout.midY - (bottomScaledInLayout.height / 2),
            width: bottomScaledInLayout.width,
            height: bottomScaledInLayout.height
        )

        let combinedRect = topScaled.union(bottomScaled)

        DLOG("🎮 Dual screen viewport calculation:")
        DLOG("🎮   View size: \(viewSize)")
        DLOG("🎮   Mapping size: \(mappingSize)")
        DLOG("🎮   Scale: \(scale)")
        DLOG("🎮   Offset: \(offset)")
        DLOG("🎮   Scaled width: \(scaledWidth), height: \(scaledHeight)")
        DLOG("🎮   Top screen (original): \(topScreenFrame)")
        DLOG("🎮   Bottom screen (original): \(bottomScreenFrame)")
        DLOG("🎮   Swap state: \(isScreenSwapped)")
        DLOG("🎮   Top screen (scaled): \(topScaled)")
        DLOG("🎮   Bottom screen (scaled): \(bottomScaled)")
        DLOG("🎮   Combined rect: \(combinedRect)")
        DLOG("🎮   View bounds: \(view.bounds)")

        return combinedRect
    }

    /// Scale a frame using the EXACT same method as DeltaSkinScreenPositionWrapper
    private func scaledFrame(
        _ frame: CGRect,
        mappingSize: CGSize,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGRect {
        // Match DeltaSkinScreenPositionWrapper.scaledFrame exactly
        return CGRect(
            x: (frame.origin.x * scale) + offset.x,
            y: (frame.origin.y * scale) + offset.y,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )
    }

    /// Apply dual screen positioning for emuThreeDS
    internal func applyDualScreenViewport() {
        guard isDualScreenSystem else {
            // Fall back to single screen positioning
            applyViewportFromCurrentSkin()
            return
        }

        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.applyDualScreenViewport() }
            return
        }

        // Ensure GPU view is visible and properly layered before positioning
        ensureGPUViewVisibilityAndZOrder()

        // For emuThreeDS, check if GPU view exists and is ready
        guard let gpuView = gpuViewController.view else {
            DLOG("🎮 GPU view not ready for dual screen positioning, deferring...")
            // Defer positioning until view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.applyDualScreenViewport()
            }
            return
        }

        // Prefer notification-based positioning if we have received frames
        // This uses the exact frames calculated by the skin system
        if !receivedScreenFrames.isEmpty {
            let combinedRect = receivedScreenFrames.values.reduce(receivedScreenFrames.values.first!) { result, rect in
                result.union(rect)
            }

            if lastAppliedViewportFrame != combinedRect {
                DLOG("🎮 Using notification-based dual screen frame: \(combinedRect)")
                if core.coreIdentifier?.contains("emuThree") == true || core.coreIdentifier?.contains("3DS") == true {
                    applyDualScreenViewportForEmuThree(frame: combinedRect)
                } else {
                    applyExactFrameToGPUView(combinedRect)
                }
                currentTargetFrame = combinedRect
                lastAppliedViewportFrame = combinedRect
            }
            return
        }

        // Fall back to calculated positioning if no notifications received
        guard let frame = currentDualScreenViewportFrame() else {
            DLOG("🎮 No dual screen frame calculated, skipping positioning for emuThreeDS")
            // For emuThreeDS, if we can't calculate dual screen frame, don't position at all
            // Let the core use its default full-screen layout
            // This prevents black screen issues
            return
        }

        // Additional safety check: ensure we have a valid skin with screen groups
        guard let skin = currentSkin else {
            DLOG("🎮 No skin available for dual screen positioning")
            return
        }

        let device: DeltaSkinDevice = {
            #if os(tvOS)
            return .tv
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #endif
        }()
        let orientation: DeltaSkinOrientation = (currentOrientation == .landscape) ? .landscape : .portrait
        let traits = DeltaSkinTraits(
            device: device,
            displayType: .standard,
            orientation: orientation
        )

        guard let screenGroups = skin.screenGroups(for: traits),
              let mainGroup = screenGroups.first,
              mainGroup.screens.count >= 2 else {
            DLOG("🎮 Skin doesn't have dual screen groups, skipping positioning")
            return
        }

        // Validate frame is within reasonable bounds
        guard frame.width > 0 && frame.height > 0,
              frame.width <= view.bounds.width * 2 && frame.height <= view.bounds.height * 2 else {
            DLOG("🎮 Invalid dual screen frame: \(frame), skipping positioning")
            return
        }

        if lastAppliedViewportFrame != frame {
            // Special handling for emuThreeDS - it uses touchViewController directly
            if core.coreIdentifier?.contains("emuThree") == true || core.coreIdentifier?.contains("3DS") == true {
                applyDualScreenViewportForEmuThree(frame: frame)
            } else {
                applyExactFrameToGPUView(frame)
            }

            currentTargetFrame = frame
            lastAppliedViewportFrame = frame

            DLOG("🎮 Applied dual screen viewport: \(frame)")
        }
    }

    /// Special handling for emuThreeDS dual screen positioning
    private func applyDualScreenViewportForEmuThree(frame: CGRect) {
        // emuThreeDS adds its view to touchViewController.view
        // We need to position the view relative to touchViewController.view, not self.view
        guard let touchView = core.touchViewController?.view else {
            DLOG("🎮 emuThreeDS: touchViewController.view not found")
            return
        }

        DLOG("🎮 emuThreeDS positioning:")
        DLOG("🎮   Frame in view coords: \(frame)")
        DLOG("🎮   View bounds: \(view.bounds)")
        DLOG("🎮   TouchView bounds: \(touchView.bounds)")

        // Convert frame from self.view coordinates to touchViewController.view coordinates
        let frameInTouchView = view.convert(frame, to: touchView)

        DLOG("🎮   Frame in touchView coords: \(frameInTouchView)")

        // Find the emuThreeDS view (should be a subview of touchView)
        // emuThreeDS adds its view with tag or we can find it by type
        var emuThreeView: UIView? = nil
        for subview in touchView.subviews {
            // Look for EmuThreeVulkanViewController's view or EmuThreeOGLViewController's view
            if type(of: subview).description().contains("EmuThree") ||
               subview.classForCoder.description().contains("EmuThree") {
                emuThreeView = subview
                break
            }
        }

        // Fallback: use gpuViewController.view if it's in the touchView hierarchy
        if emuThreeView == nil, let gpuView = gpuViewController.view, gpuView.isDescendant(of: touchView) {
            emuThreeView = gpuView
        }

        guard let viewToPosition = emuThreeView else {
            DLOG("🎮 emuThreeDS: Could not find view to position, using gpuViewController.view")
            // Fallback to standard positioning
            applyExactFrameToGPUView(frame)
            return
        }

        DLOG("🎮 emuThreeDS: Positioning view at \(frameInTouchView) in touchView bounds: \(touchView.bounds)")

        // Ensure view is visible
        viewToPosition.isHidden = false
        viewToPosition.alpha = 1.0

        // Remove constraints that might conflict
        viewToPosition.translatesAutoresizingMaskIntoConstraints = true

        // Remove existing constraints from superview that might conflict
        if let superview = viewToPosition.superview {
            NSLayoutConstraint.deactivate(superview.constraints.filter { constraint in
                constraint.firstItem === viewToPosition || constraint.secondItem === viewToPosition
            })
        }

        // Apply frame
        UIView.performWithoutAnimation {
            viewToPosition.frame = frameInTouchView
        }

        viewToPosition.setNeedsLayout()
        viewToPosition.layoutIfNeeded()

        // Verify the view is still visible after positioning
        if viewToPosition.isHidden || viewToPosition.alpha == 0 {
            DLOG("🎮 WARNING: emuThreeDS view became hidden after positioning!")
            viewToPosition.isHidden = false
            viewToPosition.alpha = 1.0
        }

        // Ensure z-order is maintained - GPU view must be below skin
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }),
           let gpuView = gpuViewController.view {
            view.insertSubview(gpuView, belowSubview: skinContainerView)
        }
    }

    /// Handle swap screen action - reposition screens when swap is toggled
    @objc private func handleSwapScreenChanged(_ notification: Notification) {
        guard isDualScreenSystem else { return }

        guard let userInfo = notification.userInfo else { return }

        // Check if "Swap Screen" option was updated
        // The notification userInfo contains option names as keys
        guard userInfo["Swap Screen"] != nil else { return }

        DLOG("🎮 Swap screen changed, clearing cached frames and repositioning")

        // Clear cached frames since swap changes which screen is which
        receivedScreenFrames.removeAll()

        // Reposition after a short delay to ensure swap state is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyDualScreenViewport()
        }
    }

    /// Clear received screen frames (called when skin changes)
    internal func clearReceivedScreenFrames() {
        receivedScreenFrames.removeAll()
    }

    /// Set up observers for dual screen systems
    internal func setupDualScreenObservers() {
        guard isDualScreenSystem else { return }

        // Observe swap screen changes via OptionUpdated notification
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("OptionUpdated"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwapScreenChanged(_:)),
            name: NSNotification.Name("OptionUpdated"),
            object: nil
        )

        // Also listen for frame updates from the skin system
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSkinFrameUpdated(_:)),
            name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
            object: nil
        )
    }

    /// Handle frame updates from skin system for dual screens
    @objc private func handleSkinFrameUpdated(_ notification: Notification) {
        guard isDualScreenSystem, isDeltaSkinEnabled else { return }

        guard let userInfo = notification.userInfo,
              let frameValue = userInfo["frame"] as? NSValue else {
            return
        }

        let frame = frameValue.cgRectValue
        let screenId = userInfo["screenId"] as? String ?? "default"

        // Store the frame for this screen
        receivedScreenFrames[screenId] = frame

        // If we have both screens, combine them
        if receivedScreenFrames.count >= 2 {
            let combinedRect = receivedScreenFrames.values.reduce(receivedScreenFrames.values.first!) { result, rect in
                result.union(rect)
            }

            DLOG("🎮 Combined dual screen frames from notifications: \(combinedRect)")

            // Apply the combined frame
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.core.coreIdentifier?.contains("emuThree") == true || self.core.coreIdentifier?.contains("3DS") == true {
                    self.applyDualScreenViewportForEmuThree(frame: combinedRect)
                } else {
                    self.applyExactFrameToGPUView(combinedRect)
                }
                self.currentTargetFrame = combinedRect
                self.lastAppliedViewportFrame = combinedRect
            }
        } else if receivedScreenFrames.count == 1 {
            // Single screen or first screen received - apply it
            DLOG("🎮 Received single screen frame from notification: \(frame)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.core.coreIdentifier?.contains("emuThree") == true || self.core.coreIdentifier?.contains("3DS") == true {
                    self.applyDualScreenViewportForEmuThree(frame: frame)
                } else {
                    self.applyExactFrameToGPUView(frame)
                }
                self.currentTargetFrame = frame
                self.lastAppliedViewportFrame = frame
            }
        }
    }
}
