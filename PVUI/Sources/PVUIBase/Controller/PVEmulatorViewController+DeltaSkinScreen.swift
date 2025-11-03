import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVCoreBridge

// MARK: - DeltaSkin Screen Integration
extension PVEmulatorViewController {

    /// Update the GPU view position based on the DeltaSkin screen information
    func updateGPUViewPositionForDeltaSkin() {
        guard gpuViewController.view != nil else {
            ELOG("GPU view not found")
            return
        }

        // Keep observers that matter for external frame updates (debug tools)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinLoaded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSkinLoaded), name: NSNotification.Name("DeltaSkinLoaded"), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleColorBarsFrameUpdated), name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)

        // Set up dual screen observers if needed
        setupDualScreenObservers()

        // Apply immediately from current skin if available
        if isDeltaSkinEnabled, currentSkin != nil {
            applyViewportFromCurrentSkin()
        } else {
            resetGPUViewPosition()
        }
    }

    /// Calculate screen height based on width and aspect ratio
    private func screenHeight(for width: CGFloat) -> CGFloat {
        // Default to 4:3 aspect ratio for most retro systems
        return width * (3.0 / 4.0)
    }

    @objc private func handleSkinLoaded(_ notification: Notification) {
        DLOG("🎮 Received skin loaded notification")

        // Fetch and set the current skin so applyViewportFromCurrentSkin can use it
        Task {
            guard let systemId = game.system?.systemIdentifier else {
                DLOG("🎮 No system identifier available for skin loading")
                return
            }

            do {
                if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                    await MainActor.run {
                        self.currentSkin = skin
                        DLOG("🎮 Set currentSkin: \(skin.name) (\(skin.identifier))")
                        // Now apply viewport with the skin set
                        self.applyViewportFromCurrentSkin()
                    }
                } else {
                    DLOG("🎮 No skin available for system: \(systemId)")
                    await MainActor.run {
                        self.currentSkin = nil
                        self.resetGPUViewPosition()
                    }
                }
            } catch {
                ELOG("🎮 Error loading skin: \(error)")
                await MainActor.run {
                    self.currentSkin = nil
                    self.resetGPUViewPosition()
                }
            }
        }
    }

    /// Handle the color bars frame updated notification
    @objc private func handleColorBarsFrameUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frameValue = userInfo["frame"] as? NSValue else {
            DLOG("🔴 Invalid notification data for color bars frame")
            return
        }

        // Extract the frame from the notification
        let colorBarsFrame = frameValue.cgRectValue

        // Store the frame for debugging
        currentTargetFrame = colorBarsFrame

        // Log all the information we received
        DLOG("🔴 Received color bars frame notification:")
        DLOG("🔴   Frame: \(colorBarsFrame)")

        if let outputFrameValue = userInfo["outputFrame"] as? NSValue {
            DLOG("🔴   Original outputFrame: \(outputFrameValue.cgRectValue)")
        }

        if let mappingSizeValue = userInfo["mappingSize"] as? NSValue {
            DLOG("🔴   Mapping Size: \(mappingSizeValue.cgSizeValue)")
        }

        if let scale = userInfo["scale"] as? CGFloat {
            DLOG("🔴   Scale: \(scale)")
        }

        if let offsetValue = userInfo["offset"] as? NSValue {
            DLOG("🔴   Offset: \(offsetValue.cgPointValue)")
        }

        if let screenId = userInfo["screenId"] as? String {
            DLOG("🔴   Screen ID: \(screenId)")
        }

        // Ensure currentSkin is set if not already set
        // This ensures applyViewportFromCurrentSkin can work correctly
        if currentSkin == nil, let systemId = game.system?.systemIdentifier {
            Task {
                do {
                    if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                        await MainActor.run {
                            self.currentSkin = skin
                            DLOG("🔴 Set currentSkin from color bars notification: \(skin.name)")
                        }
                    }
                } catch {
                    DLOG("🔴 Error loading skin in color bars handler: \(error)")
                }
            }
        }

        // Apply the exact same frame to the GPU view
        // Use the same method as applyViewportFromCurrentSkin to ensure consistency
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // For dual-screen systems, let applyDualScreenViewport handle it
            if self.core.supportsDualScreens {
                // Dual-screen systems handle notifications in applyDualScreenViewport
                return
            }

            // Validate frame before applying
            guard colorBarsFrame.width > 0 && colorBarsFrame.height > 0 else {
                DLOG("🔴 Invalid frame dimensions from notification, skipping")
                return
            }

            // Ensure view is laid out before applying frame
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()

            // CRITICAL: Validate view bounds are valid
            let viewBounds = self.view.bounds
            guard viewBounds.width > 0 && viewBounds.height > 0,
                  viewBounds.width < 10000 && viewBounds.height < 10000 else {
                ELOG("🔴 CRITICAL: Invalid view bounds: \(viewBounds), refusing to apply notification frame: \(colorBarsFrame)")
                return
            }

            // Metal maximum texture size is 16384 - prevent crashes
            let maxMetalDimension: CGFloat = 16384
            let isValidFrame = colorBarsFrame.width > 0 && colorBarsFrame.height > 0 &&
                               colorBarsFrame.width <= maxMetalDimension &&
                               colorBarsFrame.height <= maxMetalDimension &&
                               colorBarsFrame.width.isFinite && colorBarsFrame.height.isFinite &&
                               colorBarsFrame.origin.x.isFinite && colorBarsFrame.origin.y.isFinite &&
                               colorBarsFrame.width <= viewBounds.width * 2 &&
                               colorBarsFrame.height <= viewBounds.height * 2 &&
                               colorBarsFrame.minX >= -viewBounds.width &&
                               colorBarsFrame.minY >= -viewBounds.height &&
                               colorBarsFrame.maxX <= viewBounds.width * 2 &&
                               colorBarsFrame.maxY <= viewBounds.height * 2

            if !isValidFrame {
                DLOG("🔴 Frame from notification seems invalid (out of reasonable bounds): \(colorBarsFrame), view.bounds: \(viewBounds)")
                DLOG("🔴 Falling back to calculated frame")
                // Fall back to calculated frame
                self.applyViewportFromCurrentSkin()
                return
            }

            // Only apply if this is a different frame to avoid unnecessary updates
            if self.lastAppliedViewportFrame != colorBarsFrame {
                // Create a debug overlay to show the frame
                self.createDebugOverlay(frame: colorBarsFrame)

                DLOG("🔴 Applying notification frame: \(colorBarsFrame), view.bounds: \(viewBounds)")

                // Apply the frame to the GPU view - DIRECTLY without any modifications
                // This is the exact frame calculated by the skin system
                self.applyExactFrameToGPUView(colorBarsFrame)

                // Update tracking
                self.lastAppliedViewportFrame = colorBarsFrame

                // Verify the frame was applied correctly
                if let gpuView = self.gpuViewController.view {
                    DLOG("🔴 GPU view frame after applying: \(gpuView.frame)")
                }
            }
        }
    }

    private func tryPositionGPUView() {
        applyViewportFromCurrentSkin()
    }

    /// Position the GPU view based on the skin's screen information
    private func positionGPUViewWithSkin(_ skin: DeltaSkinProtocol) {
        currentSkin = skin
        applyViewportFromCurrentSkin()

    }

    /// Scale a frame using the same method as DeltaSkinScreenLayer
    private func scaledFrame(
        _ frame: CGRect,
        mappingSize: CGSize,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGRect {
        // EXACTLY match the implementation in DeltaSkinScreenLayer
        return CGRect(
            x: frame.minX * scale + offset.x,
            y: frame.minY * scale + offset.y,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }

    /// Compute the active viewport frame for the game screen based on the current skin and traits
    internal func currentSkinViewportFrame() -> CGRect? {
        guard isDeltaSkinEnabled, let skin = currentSkin else { return nil }

        // CRITICAL: Ensure view is laid out and has valid bounds before calculating frame
        let viewBounds = view.bounds
        guard viewBounds.width > 0 && viewBounds.height > 0,
              viewBounds.width < 10000 && viewBounds.height < 10000 else {
            DLOG("🔴 ERROR: Invalid view bounds for viewport calculation: \(viewBounds)")
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

        // Validate mapping size is reasonable
        guard mappingSize.width > 0 && mappingSize.height > 0,
              mappingSize.width < 10000 && mappingSize.height < 10000 else {
            DLOG("🔴 ERROR: Invalid mapping size: \(mappingSize)")
            return nil
        }

        let viewSize = viewBounds.size

        // Use the same scale calculation as DeltaSkinScreenPositionWrapper for consistency
        var scale: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Start with width scale to fill screen
            guard mappingSize.width > 0 else {
                DLOG("🔴 ERROR: mappingSize.width is zero")
                return nil
            }
            scale = viewSize.width / mappingSize.width

            // Validate scale is reasonable
            guard scale.isFinite && scale > 0 && scale < 1000 else {
                DLOG("🔴 ERROR: Invalid scale calculated: \(scale), viewSize: \(viewSize), mappingSize: \(mappingSize)")
                return nil
            }

            // Calculate resulting height
            let scaledHeight = mappingSize.height * scale

            // If height exceeds screen, scale down while maintaining aspect ratio
            if scaledHeight > viewSize.height {
                guard mappingSize.height > 0 else {
                    DLOG("🔴 ERROR: mappingSize.height is zero")
                    return nil
                }
                let heightScale = viewSize.height / mappingSize.height
                scale = min(scale, heightScale)
            }
        } else {
            // For landscape or iPad, use standard fit scaling
            guard mappingSize.width > 0 && mappingSize.height > 0 else {
                DLOG("🔴 ERROR: mappingSize has zero dimensions: \(mappingSize)")
                return nil
            }
            scale = min(
                viewSize.width / mappingSize.width,
                viewSize.height / mappingSize.height
            )
        }

        // Final validation of scale
        guard scale.isFinite && scale > 0 && scale < 1000 else {
            DLOG("🔴 ERROR: Invalid scale after calculation: \(scale)")
            return nil
        }

        let scaledWidth = mappingSize.width * scale
        let scaledHeight = mappingSize.height * scale

        // Validate scaled dimensions are reasonable (Metal max is 16384, but we'll be more conservative)
        guard scaledWidth > 0 && scaledHeight > 0,
              scaledWidth < 16384 && scaledHeight < 16384 else {
            DLOG("🔴 ERROR: Scaled dimensions too large: \(scaledWidth)x\(scaledHeight)")
            return nil
        }

        // Calculate offset with same logic as DeltaSkinScreenPositionWrapper
        let xOffset = (viewSize.width - scaledWidth) / 2
        let yOffset: CGFloat
        if traits.device == .iphone && traits.orientation == .portrait {
            // Position at bottom of screen for iPhone portrait
            yOffset = viewSize.height - scaledHeight
        } else {
            // Center vertically for landscape or iPad
            yOffset = (viewSize.height - scaledHeight) / 2
        }

        let offset = CGPoint(x: xOffset, y: yOffset)
        // Calculate layout dimensions (scaled mappingSize)
        let layoutWidth = mappingSize.width * scale
        let layoutHeight = mappingSize.height * scale

        if let screens = skin.screens(for: traits) {
            let gameScreens = screens.filter { $0.placement == DeltaSkinScreenPlacement.app }
            if let first = gameScreens.first, let output = first.outputFrame {
                // outputFrame is normalized (0.0-1.0), scale using layout dimensions to match DeltaSkinScreenPositionWrapper
                let scaledInLayout = CGRect(
                    x: output.minX * layoutWidth,
                    y: output.minY * layoutHeight,
                    width: output.width * layoutWidth,
                    height: output.height * layoutHeight
                )
                let result = CGRect(
                    x: xOffset + scaledInLayout.minX,
                    y: yOffset + scaledInLayout.minY,
                    width: scaledInLayout.width,
                    height: scaledInLayout.height
                )
                return validateFrame(result)
            }
            if let first = screens.first, let output = first.outputFrame {
                // outputFrame is normalized (0.0-1.0), scale using layout dimensions to match DeltaSkinScreenPositionWrapper
                let scaledInLayout = CGRect(
                    x: output.minX * layoutWidth,
                    y: output.minY * layoutHeight,
                    width: output.width * layoutWidth,
                    height: output.height * layoutHeight
                )
                let result = CGRect(
                    x: xOffset + scaledInLayout.minX,
                    y: yOffset + scaledInLayout.minY,
                    width: scaledInLayout.width,
                    height: scaledInLayout.height
                )
                return validateFrame(result)
            }
        }
        if let buttons = skin.buttons(for: traits), !buttons.isEmpty,
           let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
            let defaultFrame = CGRect(x: 0, y: 0, width: mappingSize.width, height: topButton.frame.minY * 0.95)
            let result = scaledFrame(defaultFrame, mappingSize: mappingSize, scale: scale, offset: offset)
            return validateFrame(result)
        }
        let defaultFrame = CGRect(x: 0, y: 0, width: mappingSize.width, height: mappingSize.height * 0.5)
        let result = scaledFrame(defaultFrame, mappingSize: mappingSize, scale: scale, offset: offset)
        return validateFrame(result)
    }

    /// Validate that a frame is reasonable and safe for Metal
    private func validateFrame(_ frame: CGRect) -> CGRect? {
        // Metal maximum texture size is 16384, but we'll be more conservative
        let maxDimension: CGFloat = 16384

        guard frame.width > 0 && frame.height > 0,
              frame.width <= maxDimension && frame.height <= maxDimension,
              frame.width.isFinite && frame.height.isFinite,
              frame.origin.x.isFinite && frame.origin.y.isFinite else {
            DLOG("🔴 ERROR: Invalid frame for Metal: \(frame)")
            return nil
        }

        return frame
    }

    /// Compute and apply viewport from the current skin once
    internal func applyViewportFromCurrentSkin() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.applyViewportFromCurrentSkin() }
            return
        }

        // CRITICAL: Ensure view is laid out and has valid bounds before calculating/applying viewport
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // Validate view bounds are reasonable before proceeding
        let viewBounds = view.bounds
        guard viewBounds.width > 0 && viewBounds.height > 0,
              viewBounds.width < 10000 && viewBounds.height < 10000,
              viewBounds.width.isFinite && viewBounds.height.isFinite else {
            DLOG("🔴 ERROR: Invalid view bounds, cannot apply viewport: \(viewBounds)")
            // Don't apply viewport if view isn't ready - this prevents Metal crashes
            return
        }

        // Ensure GPU view is visible and properly layered before positioning
        ensureGPUViewVisibilityAndZOrder()

        // Check if this core supports dual screens and use dual screen positioning
        if core.supportsDualScreens {
            applyDualScreenViewport()
            return
        }

        // For skins with explicit viewports, prefer the notification-based frame
        // (from color bars) as it's the authoritative source calculated by the skin system
        if let notificationFrame = currentTargetFrame,
           let skin = currentSkin {
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

            // If skin has explicit viewport and we have a notification frame, use it
            // Always prefer notification frames as they're calculated by the skin system with correct layout
            if hasScreenPosition(skin: skin, traits: traits) {
                // Validate frame before applying
                if notificationFrame.width > 0 && notificationFrame.height > 0 {
                    // Verify frame is reasonable for current view size and Metal limits
                    let viewBounds = view.bounds
                    let maxMetalDimension: CGFloat = 16384
                    // More lenient validation - allow frames slightly outside view bounds as they may be positioned correctly
                    let frameIsValid = notificationFrame.width > 0 && notificationFrame.height > 0 &&
                                       notificationFrame.width <= maxMetalDimension &&
                                       notificationFrame.height <= maxMetalDimension &&
                                       notificationFrame.width.isFinite && notificationFrame.height.isFinite &&
                                       notificationFrame.origin.x.isFinite && notificationFrame.origin.y.isFinite &&
                                       notificationFrame.width <= viewBounds.width * 3 &&
                                       notificationFrame.height <= viewBounds.height * 3 &&
                                       notificationFrame.minX >= -viewBounds.width &&
                                       notificationFrame.minY >= -viewBounds.height * 2 &&
                                       notificationFrame.maxX <= viewBounds.width * 2 &&
                                       notificationFrame.maxY <= viewBounds.height * 2

                    if frameIsValid {
                        DLOG("🔴 Using notification-based frame for explicit viewport: \(notificationFrame), view.bounds: \(viewBounds)")
                        if lastAppliedViewportFrame != notificationFrame {
                            applyExactFrameToGPUView(notificationFrame)
                            lastAppliedViewportFrame = notificationFrame
                        }
                        return
                    } else {
                        ELOG("🔴 CRITICAL: Notification frame invalid for Metal or view size: \(notificationFrame), view.bounds: \(viewBounds)")
                        ELOG("🔴 Falling back to calculated frame to prevent crash")
                        // Fall through to calculated frame
                    }
                } else {
                    DLOG("🔴 Invalid notification frame dimensions, falling back to calculated frame")
                    // Fall through to calculated frame
                }
            } else {
                // Even if skin doesn't have explicit viewport, prefer notification frame if available
                // It's still calculated by the skin system and likely more accurate
                if notificationFrame.width > 0 && notificationFrame.height > 0 {
                    let viewBounds = view.bounds
                    let maxMetalDimension: CGFloat = 16384
                    let frameIsValid = notificationFrame.width > 0 && notificationFrame.height > 0 &&
                                       notificationFrame.width <= maxMetalDimension &&
                                       notificationFrame.height <= maxMetalDimension &&
                                       notificationFrame.width.isFinite && notificationFrame.height.isFinite &&
                                       notificationFrame.origin.x.isFinite && notificationFrame.origin.y.isFinite &&
                                       notificationFrame.width <= viewBounds.width * 3 &&
                                       notificationFrame.height <= viewBounds.height * 3

                    if frameIsValid {
                        DLOG("🔴 Using notification frame for skin without explicit viewport: \(notificationFrame)")
                        if lastAppliedViewportFrame != notificationFrame {
                            applyExactFrameToGPUView(notificationFrame)
                            lastAppliedViewportFrame = notificationFrame
                        }
                        return
                    }
                }
            }
        }

        // Fall back to calculated frame if no notification frame or skin doesn't have explicit viewport
        guard let frame = currentSkinViewportFrame() else {
            // If we have a currentTargetFrame from notifications, use it as fallback
            if let fallbackFrame = currentTargetFrame,
               fallbackFrame.width > 0 && fallbackFrame.height > 0 {
                DLOG("🔴 Using fallback notification frame: \(fallbackFrame)")
                if lastAppliedViewportFrame != fallbackFrame {
                    applyExactFrameToGPUView(fallbackFrame)
                    lastAppliedViewportFrame = fallbackFrame
                }
                return
            }
            resetGPUViewPosition()
            return
        }

        // Validate frame before applying
        guard frame.width > 0 && frame.height > 0 else {
            DLOG("🔴 Invalid frame calculated, resetting GPU view position")
            resetGPUViewPosition()
            return
        }

        if lastAppliedViewportFrame != frame {
            applyExactFrameToGPUView(frame)
            currentTargetFrame = frame
            lastAppliedViewportFrame = frame
        }
    }

    /// Ensure GPU view is visible and has correct z-order (below skin)
    internal func ensureGPUViewVisibilityAndZOrder() {
        guard let gameScreenView = gpuViewController.view else {
            return
        }

        // Ensure GPU view is visible
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Ensure GPU view is below skin container
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }

        // Also ensure Metal view is visible if present
        if let metalVC = gpuViewController as? PVMetalViewController,
           let mtlView = metalVC.mtlView {
            mtlView.isHidden = false
            mtlView.alpha = 1.0
        }
    }

    /// Check if a skin has explicit screen position information
    private func hasScreenPosition(skin: DeltaSkinProtocol, traits: DeltaSkinTraits) -> Bool {
        // Check if skin has screens with output frames
        if let screens = skin.screens(for: traits), !screens.isEmpty,
           let firstScreen = screens.first, firstScreen.outputFrame != nil {
            return true
        }

        // Check if representation has gameScreenFrame in raw dictionary
        let jsonDict = skin.jsonRepresentation
        if let representations = jsonDict["representations"] as? [String: Any],
           let deviceRep = representations[traits.device.rawValue] as? [String: Any],
           let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
           let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
           orientationRep["gameScreenFrame"] != nil {
            return true
        }

        return false
    }

    /// Try to get gameScreenFrame from raw dictionary for older skin formats
    private func getGameScreenFrameFromRawDictionary(skin: DeltaSkinProtocol, traits: DeltaSkinTraits) -> CGRect? {
        // Access the raw dictionary through jsonRepresentation
        let jsonDict = skin.jsonRepresentation

        // Navigate through the representation hierarchy
        guard let representations = jsonDict["representations"] as? [String: Any],
              let deviceRep = representations[traits.device.rawValue] as? [String: Any],
              let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
              let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any] else {
            return nil
        }

        // Try to get gameScreenFrame
        if let gameScreenFrameDict = orientationRep["gameScreenFrame"] as? [String: Any],
           let x = gameScreenFrameDict["x"] as? CGFloat,
           let y = gameScreenFrameDict["y"] as? CGFloat,
           let width = gameScreenFrameDict["width"] as? CGFloat,
           let height = gameScreenFrameDict["height"] as? CGFloat {
            return CGRect(x: x, y: y, width: width, height: height)
        }

        return nil
    }

    /// Calculate frame for skins without explicit screen position
    private func calculateFrameWithoutExplicitPosition(skin: DeltaSkinProtocol, traits: DeltaSkinTraits, viewSize: CGSize) -> CGRect {
        // Get the buttons to determine where the controls are
        guard let buttons = skin.buttons(for: traits),
              let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) else {
            // If no buttons, use a default centered frame
            let width = viewSize.width * 0.8
            let height = width * 0.75 // Assuming 4:3 aspect ratio
            let x = (viewSize.width - width) / 2
            let y = (viewSize.height - height) / 2
            return CGRect(x: x, y: y, width: width, height: height)
        }

        // Get the skin layout information
        guard let mappingSize = skin.mappingSize(for: traits) else {
            // If no mapping size, use a default centered frame
            let width = viewSize.width * 0.8
            let height = width * 0.75 // Assuming 4:3 aspect ratio
            let x = (viewSize.width - width) / 2
            let y = (viewSize.height - height) / 2
            return CGRect(x: x, y: y, width: width, height: height)
        }

        // Calculate scale for buttons
        let scale = min(
            viewSize.width / mappingSize.width,
            viewSize.height / mappingSize.height
        )

        // Calculate offset for centering
        let xOffset = (viewSize.width - (mappingSize.width * scale)) / 2
        let yOffset = (viewSize.height - (mappingSize.height * scale)) / 2

        // Calculate layout dimensions - EXACTLY matching DeltaSkinScreenLayer
        let layoutWidth = mappingSize.width * scale
        let layoutHeight = mappingSize.height * scale

        // Get the scaled top button position
        let skinTopY = topButton.frame.minY * scale + yOffset

        // Calculate available space above skin - EXACTLY matching DeltaSkinScreenLayer
        let availableSpace = skinTopY

        // Use full width of skin for screen width
        let screenWidth = layoutWidth

        // Calculate height based on aspect ratio (default to 4:3)
        let aspectRatio = 4.0/3.0 // Default aspect ratio
        let screenHeight = screenWidth / aspectRatio

        // Center in available space above skin - EXACTLY matching DeltaSkinScreenLayer
        let screenX = (viewSize.width - screenWidth) / 2
        let screenY = (availableSpace - screenHeight) / 2

        DLOG("🔴 Calculated frame without explicit position:")
        DLOG("🔴   View size: \(viewSize)")
        DLOG("🔴   Layout dimensions: width=\(layoutWidth), height=\(layoutHeight)")
        DLOG("🔴   Top button Y: \(topButton.frame.minY), Scaled: \(skinTopY)")
        DLOG("🔴   Available space: \(availableSpace)")
        DLOG("🔴   Screen dimensions: width=\(screenWidth), height=\(screenHeight), x=\(screenX), y=\(screenY)")

        return CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
    }

    /// Apply the calculated frame to the GPU view
    private func applyFrame(_ frame: CGRect, to gameScreenView: UIView) {
        // Log the calculated frame for debugging
        DLOG("""
        Applying frame to GPU view:
        - Frame: \(frame)
        - Origin: (\(frame.origin.x), \(frame.origin.y))
        - Size: \(frame.width) x \(frame.height)
        - Current frame: \(gameScreenView.frame)
        """)

        // DEBUG: Print current transform and constraints
        DLOG("GPU VIEW BEFORE POSITIONING:")
        DLOG("  Current frame: \(gameScreenView.frame)")
        DLOG("  Transform: \(gameScreenView.transform)")
        DLOG("  AutoresizingMask: \(gameScreenView.autoresizingMask.rawValue)")
        DLOG("  ContentMode: \(gameScreenView.contentMode.rawValue)")

        // Apply the calculated frame to the GPU view
        UIView.performWithoutAnimation {
            gameScreenView.frame = frame
        }

        // Remove autoresizing mask to prevent automatic resizing
        gameScreenView.autoresizingMask = []

        // Set content mode to scale to fill
        gameScreenView.contentMode = .scaleToFill

        // Make sure the GPU view is visible
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // IMPORTANT: Set the MTLView layer frame directly
        if let metalVC = gpuViewController as? PVMetalViewController {
            DLOG("Sizing MTLView to GPU view bounds: \(frame)")
            UIView.performWithoutAnimation {
                metalVC.view.frame = frame
                metalVC.mtlView.frame = metalVC.view.bounds
            }
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
        }

        // DEBUG: Print after positioning
        DLOG("GPU VIEW AFTER POSITIONING:")
        DLOG("  New frame: \(gameScreenView.frame)")
        DLOG("  Transform: \(gameScreenView.transform)")
        DLOG("  AutoresizingMask: \(gameScreenView.autoresizingMask.rawValue)")
        DLOG("  ContentMode: \(gameScreenView.contentMode.rawValue)")

        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }
    }

    /// Reset the GPU view to its default position (full screen)
    internal func resetGPUViewPosition() {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Set the GPU view to fill the entire screen
        UIView.performWithoutAnimation {
            gameScreenView.frame = view.bounds
        }
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.contentMode = .scaleAspectFit
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // Set the MTLView layer frame as well
        if let metalVC = gpuViewController as? PVMetalViewController {
            UIView.performWithoutAnimation {
                metalVC.mtlView.frame = view.bounds
                metalVC.mtlView.layer.frame = view.bounds
            }
            metalVC.mtlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            metalVC.mtlView.contentMode = .scaleAspectFit

            // Force redraw
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
        }

        // Ensure z-order is maintained
        ensureGPUViewVisibilityAndZOrder()
    }

    /// Manually set the GPU view to a specific position and size
    private func manuallyPositionGPUView(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        let frame = CGRect(x: x, y: y, width: width, height: height)
        DLOG("MANUALLY POSITIONING GPU VIEW: \(frame)")

        // Apply the frame
        UIView.performWithoutAnimation {
            gameScreenView.frame = frame
        }
        gameScreenView.autoresizingMask = []
        gameScreenView.contentMode = .scaleToFill
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // IMPORTANT: Set the MTLView layer frame directly
        if let metalVC = gpuViewController as? PVMetalViewController {
            DLOG("Sizing MTLView to GPU view bounds: \(frame)")
            UIView.performWithoutAnimation {
                metalVC.view.frame = frame
                metalVC.mtlView.frame = metalVC.view.bounds
            }
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()

            // Schedule another check to make sure the frame sticks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak metalVC] in
                guard let metalVC = metalVC else { return }

                DLOG("DELAYED CHECK - MTLView frame: \(metalVC.mtlView.frame)")

                // If the frame changed, reapply it
                if metalVC.view.frame != frame {
                    DLOG("Frame changed after positioning, reapplying...")
                    UIView.performWithoutAnimation {
                        metalVC.view.frame = frame
                        metalVC.mtlView.frame = metalVC.view.bounds
                    }
                    metalVC.mtlView.setNeedsLayout()
                    metalVC.mtlView.layoutIfNeeded()
                }
            }
        }

        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }
    }

    /// Add a debug overlay to show where the GPU view should be positioned
    private func forceGPUViewPosition() {

        // Remove any existing debug overlays
        view.subviews.forEach { subview in
            if subview.tag == 9999 {
                subview.removeFromSuperview()
            }
        }

        // Create a default frame as a fallback
        let bounds = view.bounds
        let defaultWidth = bounds.width * 0.8
        let defaultHeight = defaultWidth * 0.75 // Assuming 4:3 aspect ratio
        let defaultX = (bounds.width - defaultWidth) / 2
        let defaultY = (bounds.height - defaultHeight) / 3 // Position about 1/3 down from top
        let defaultFrame = CGRect(x: defaultX, y: defaultY, width: defaultWidth, height: defaultHeight)

        // Create and add the debug overlay with the default frame immediately
        createDebugOverlay(frame: defaultFrame)
        return
        // Get the current system identifier
        guard let systemId = game.system?.systemIdentifier else {
            ELOG("System identifier not found")
            return
        }

        // Try to use the same method that works for color bars
        Task {
            do {
                // Try to get the selected skin for this system
                if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                    // Create traits based on the current device and orientation
                    #if os(tvOS)
                    let currentDevice: DeltaSkinDevice = .tv
                    let currentOrientation: DeltaSkinOrientation = .landscape
                    #else
                    let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
                    let currentOrientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
                    #endif

                    let traits = DeltaSkinTraits(
                        device: currentDevice,
                        displayType: .standard,
                        orientation: currentOrientation
                    )

                    // Get the skin's mapping size for scaling calculations
                    guard let mappingSize = skin.mappingSize(for: traits) else {
                        ELOG("No mapping size available for skin")
                        return
                    }

                    // Calculate the view size and scale - EXACTLY matching the DeltaSkinScreenLayer
                    let viewSize = bounds.size
                    let scale = min(
                        viewSize.width / mappingSize.width,
                        viewSize.height / mappingSize.height
                    )

                    // Calculate the offset for centering the skin in the view
                    let xOffset = (viewSize.width - (mappingSize.width * scale)) / 2
                    let yOffset = (viewSize.height - (mappingSize.height * scale)) / 2
                    let offset = CGPoint(x: xOffset, y: yOffset)

                    // First, try to find explicit screen position in the screens array
                    // This is the most reliable source for screen position
                    if let screens = skin.screens(for: traits),
                       let firstScreen = screens.first,
                       let outputFrame = firstScreen.outputFrame {

                        // Use the explicit frame from the skin's screens array
                        // EXACTLY match how DeltaSkinScreenLayer calculates the frame
                        // This is the key to making all skins work correctly

                        // Calculate the scale based on the view size and mapping size
                        // This is exactly how DeltaSkinScreenLayer does it
                        let scale = min(
                            viewSize.width / mappingSize.width,
                            viewSize.height / mappingSize.height
                        )

                        // Calculate the offset for centering the skin in the view
                        // This is exactly how DeltaSkinScreenLayer does it
                        let xOffset = (viewSize.width - (mappingSize.width * scale)) / 2
                        let yOffset = (viewSize.height - (mappingSize.height * scale)) / 2
                        let offset = CGPoint(x: xOffset, y: yOffset)

                        // Calculate the frame using the exact same method as DeltaSkinScreenLayer
                        let calculatedFrame = CGRect(
                            x: outputFrame.minX * scale + offset.x,
                            y: outputFrame.minY * scale + offset.y,
                            width: outputFrame.width * scale,
                            height: outputFrame.height * scale
                        )

                        DLOG("🔴 EXACTLY matching DeltaSkinScreenLayer calculation:")
                        DLOG("🔴   Original OutputFrame: \(outputFrame)")
                        DLOG("🔴   View Size: \(viewSize)")
                        DLOG("🔴   Mapping Size: \(mappingSize)")
                        DLOG("🔴   Scale: \(scale)")
                        DLOG("🔴   Offset: \(offset)")
                        DLOG("🔴   Calculated Frame: \(calculatedFrame)")

                        DLOG("🔴 Using explicit screen frame from screens array:")
                        DLOG("🔴   Original OutputFrame: \(outputFrame)")
                        DLOG("🔴   Scaled Frame: \(calculatedFrame)")
                        DLOG("🔴   MappingSize: \(mappingSize), Scale: \(scale), Offset: \(offset)")

                        await MainActor.run {
                            createDebugOverlay(frame: calculatedFrame)
                            applyFrameToGPUView(calculatedFrame)
                        }
                        return
                    }

                    // Next, try to get screen position from gameScreenFrame in the raw dictionary
                    // This is for older skin formats
                    let jsonDict = skin.jsonRepresentation
                    if let representations = jsonDict["representations"] as? [String: Any],
                       let deviceRep = representations[traits.device.rawValue] as? [String: Any],
                       let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
                       let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
                       let gameScreenFrameDict = orientationRep["gameScreenFrame"] as? [String: Any],
                       let x = gameScreenFrameDict["x"] as? CGFloat,
                       let y = gameScreenFrameDict["y"] as? CGFloat,
                       let width = gameScreenFrameDict["width"] as? CGFloat,
                       let height = gameScreenFrameDict["height"] as? CGFloat {

                        let gameScreenFrame = CGRect(x: x, y: y, width: width, height: height)
                        let calculatedFrame = scaledFrame(
                            gameScreenFrame,
                            mappingSize: mappingSize,
                            scale: scale,
                            offset: offset
                        )

                        DLOG("🔴 Using gameScreenFrame from raw dictionary:")
                        DLOG("🔴   Original Frame: \(gameScreenFrame)")
                        DLOG("🔴   Scaled Frame: \(calculatedFrame)")

                        await MainActor.run {
                            createDebugOverlay(frame: calculatedFrame)
                            applyFrameToGPUView(calculatedFrame)
                        }
                        return
                    }

                    // Check if this skin has explicit screen positions by other means
                    let hasExplicitScreenPosition = hasScreenPosition(skin: skin, traits: traits)
                    DLOG("🔴 Skin has explicit screen position: \(hasExplicitScreenPosition)")

                    var calculatedFrame: CGRect

                    if !hasExplicitScreenPosition {
                        // CASE 1: Skin does NOT have explicit screen position
                        // Calculate screen position based on available space above skin
                        calculatedFrame = calculateFrameWithoutExplicitPosition(skin: skin, traits: traits, viewSize: viewSize)
                        DLOG("🔴 Using calculated frame for skin without explicit position: \(calculatedFrame)")
                    } else {
                        // Use default screen frame as fallback
                        let defaultFrame = DeltaSkinDefaults.defaultScreenFrame(
                            for: skin.gameType,
                            in: mappingSize,
                            buttons: skin.buttons(for: traits),
                            isPreview: false
                        )
                        calculatedFrame = scaledFrame(
                            defaultFrame,
                            mappingSize: mappingSize,
                            scale: scale,
                            offset: offset
                        )
                        DLOG("🔴 Using default screen frame: \(defaultFrame) → \(calculatedFrame)")
                    }

                    await MainActor.run {
                        createDebugOverlay(frame: calculatedFrame)
                        applyFrameToGPUView(calculatedFrame)
                    }
                }
            } catch {
                ELOG("Error getting skin: \(error)")
            }
        }

    }

    /// Store the frame for debug overlay without creating the visual overlay
    private func createDebugOverlay(frame: CGRect) {
        // Store the current target frame for positioning in the DeltaSkin extension
        self.currentTargetFrame = frame

        // Log the frame information
        DLOG("""
            Storing debug frame at: \(frame)
            View bounds: \(view.bounds)
            """ )

        // Don't create the visual overlay until the debug overlay is shown
        // The frame will be used when the debug overlay is toggled on
    }

    // Debug buttons have been moved to PVEmulatorViewController+DeltaSkin.swift

    // Method moved to PVEmulatorViewController+DeltaSkin.swift

    /// Apply a frame directly to the GPU view
    /// For skins with explicit viewports, uses the exact frame
    /// For skins without explicit viewports, may apply optimizations
    private func applyFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            DLOG("🔴 ERROR: GPU view not found")
            return
        }

        // Check if the current skin has explicit screen position
        // If it does, use the exact frame without modifications
        let hasExplicitViewport: Bool
        if let skin = currentSkin {
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
            hasExplicitViewport = hasScreenPosition(skin: skin, traits: traits)
        } else {
            // If no skin, assume no explicit viewport
            hasExplicitViewport = false
        }

        // For skins with explicit viewports, use the exact frame
        if hasExplicitViewport {
            DLOG("🔴 Skin has explicit viewport, using exact frame: \(frame)")
            applyExactFrameToGPUView(frame)
            return
        }

        // For skins without explicit viewports, apply positioning optimizations
        // If this is a RetroArch core, size its internal renderView directly
        if core.coreIdentifier?.contains("libretro") == true,
           let bridge = core.bridge as? (any NSObjectProtocol) {
            if let viewportBridge = bridge as? EmulatorCoreViewportPositioning {
                // Ensure RA uses custom layout and apply frame in touchView space
                viewportBridge.setUseCustomRenderViewLayout(true)
                // Frame passed is already in self.view coordinates; convert to touchViewController.view
                if let parent = core.touchViewController?.view {
                    // Force layout update on parent view first to ensure correct coordinate system
                    parent.setNeedsLayout()
                    parent.layoutIfNeeded()

                    // Now convert coordinates
                    let rectInParent = view.convert(frame, to: parent)

                    // For landscape, ensure conversion is correct and clamp to parent bounds
                    let orientation: SkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
                    if orientation == .landscape {
                        let clampedRect = CGRect(
                            x: max(0, min(rectInParent.origin.x, parent.bounds.width - rectInParent.width)),
                            y: max(0, min(rectInParent.origin.y, parent.bounds.height - rectInParent.height)),
                            width: min(rectInParent.width, parent.bounds.width),
                            height: min(rectInParent.height, parent.bounds.height)
                        )
                        DLOG("🔴 Landscape RA viewport (applyFrameToGPUView): original=\(rectInParent), clamped=\(clampedRect), parent.bounds=\(parent.bounds)")
                        viewportBridge.applyRenderViewFrameInTouchView(clampedRect)
                    } else {
                        viewportBridge.applyRenderViewFrameInTouchView(rectInParent)
                    }
                    DLOG("🔴 Applied frame to RA renderView: \(rectInParent)")
                    return
                }
            }
        }

        // Get the available space in the view
        let viewBounds = view.bounds

        // Calculate the optimal frame position
        // For portrait orientation, position in the upper third of the screen
        // For landscape, center vertically
        let isPortrait = viewBounds.height > viewBounds.width

        // Create a frame that preserves the aspect ratio but positions it better
        let optimizedFrame: CGRect

        if isPortrait {
            // In portrait mode, position the screen in the upper portion
            let yPosition = viewBounds.height * 0.15 // 15% from the top
            optimizedFrame = CGRect(
                x: (viewBounds.width - frame.width) / 2, // Center horizontally
                y: yPosition,
                width: frame.width,
                height: frame.height
            )
        } else {
            // In landscape mode, center both horizontally and vertically
            optimizedFrame = CGRect(
                x: (viewBounds.width - frame.width) / 2,
                y: (viewBounds.height - frame.height) / 2,
                width: frame.width,
                height: frame.height
            )
        }

        // Just log the frame for debugging
        DLOG("🔴 Using optimized frame: \(optimizedFrame)")

        DLOG("🔴 Applying frame to GPU view: \(optimizedFrame)")
        DLOG("🔴 Current GPU view frame before: \(gameScreenView.frame)")

        // Apply the frame to the GPU view
        applyExactFrameToGPUView(optimizedFrame)
    }

    /// Apply an exact frame to the GPU view without any modifications
    internal func applyExactFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            DLOG("🔴 ERROR: GPU view not found")
            return
        }

        // Ensure view is fully laid out before applying frame
        view.setNeedsLayout()
        view.layoutIfNeeded()

        // CRITICAL: Validate view bounds are valid before processing frame
        let viewBounds = view.bounds
        guard viewBounds.width > 0 && viewBounds.height > 0,
              viewBounds.width < 10000 && viewBounds.height < 10000 else {
            DLOG("🔴 ERROR: Invalid view bounds: \(viewBounds), refusing to apply frame: \(frame)")
            return
        }

        // Validate the frame - ensure it has valid dimensions and is reasonable
        // Metal maximum texture size is 16384, so we must prevent frames larger than that
        let maxMetalDimension: CGFloat = 16384
        guard frame.width > 0 && frame.height > 0,
              frame.width <= maxMetalDimension && frame.height <= maxMetalDimension,
              frame.width.isFinite && frame.height.isFinite,
              frame.origin.x.isFinite && frame.origin.y.isFinite else {
            ELOG("🔴 CRITICAL ERROR: Invalid frame dimensions for Metal - would crash! Frame: \(frame)")
            ELOG("🔴 View bounds: \(viewBounds)")
            // Reset to safe default instead of crashing
            resetGPUViewPosition()
            return
        }

        // Clamp frame to view bounds to prevent it from being positioned incorrectly
        let clampedFrame = CGRect(
            x: max(0, min(frame.origin.x, viewBounds.width - frame.width)),
            y: max(0, min(frame.origin.y, viewBounds.height - frame.height)),
            width: min(frame.width, viewBounds.width),
            height: min(frame.height, viewBounds.height)
        )

        // Only clamp if the original frame was significantly out of bounds
        let frameToApply: CGRect
        if abs(frame.origin.x - clampedFrame.origin.x) > 1 ||
           abs(frame.origin.y - clampedFrame.origin.y) > 1 ||
           abs(frame.width - clampedFrame.width) > 1 ||
           abs(frame.height - clampedFrame.height) > 1 {
            DLOG("🔴 Frame was out of bounds, clamping: original=\(frame), clamped=\(clampedFrame), view.bounds=\(viewBounds)")
            frameToApply = clampedFrame
        } else {
            frameToApply = frame
        }

        // If this is a RetroArch core, size its internal renderView directly
        if core.coreIdentifier?.contains("libretro") == true,
           let bridge = core.bridge as? (any NSObjectProtocol) {
            if let viewportBridge = bridge as? EmulatorCoreViewportPositioning {
                // Ensure RA uses custom layout and apply frame in touchView space
                viewportBridge.setUseCustomRenderViewLayout(true)
                // Frame passed is already in self.view coordinates; convert to touchViewController.view
                if let parent = core.touchViewController?.view {
                    // Force layout update on parent view first to ensure correct coordinate system
                    parent.setNeedsLayout()
                    parent.layoutIfNeeded()

                    // Now convert coordinates
                    let rectInParent = view.convert(frameToApply, to: parent)

                    // For landscape, ensure conversion is correct and clamp to parent bounds
                    let orientation: SkinOrientation = view.bounds.width > view.bounds.height ? .landscape : .portrait
                    if orientation == .landscape {
                        let clampedRect = CGRect(
                            x: max(0, min(rectInParent.origin.x, parent.bounds.width - rectInParent.width)),
                            y: max(0, min(rectInParent.origin.y, parent.bounds.height - rectInParent.height)),
                            width: min(rectInParent.width, parent.bounds.width),
                            height: min(rectInParent.height, parent.bounds.height)
                        )
                        DLOG("🔴 Landscape RA exact viewport (applyExactFrameToGPUView): original=\(rectInParent), clamped=\(clampedRect)")
                        viewportBridge.applyRenderViewFrameInTouchView(clampedRect)
                    } else {
                        viewportBridge.applyRenderViewFrameInTouchView(rectInParent)
                    }
                    DLOG("🔴 Applied frame to RA renderView: \(rectInParent)")
                    return
                }
            }
        }

        DLOG("🔴 Applying EXACT frame to GPU view: \(frameToApply)")
        DLOG("🔴 Original frame: \(frame), view.bounds: \(viewBounds)")
        DLOG("🔴 Current GPU view frame before: \(gameScreenView.frame)")

        // Apply the frame - ONLY set the frame, nothing else
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Enable custom positioning - explicitly reference properties from PVGPUViewController
            (metalVC as PVGPUViewController).useCustomPositioning = true
            (metalVC as PVGPUViewController).customFrame = frameToApply

            // Apply the frame to the Metal container view; let mtlView fill its bounds
            UIView.performWithoutAnimation {
                metalVC.view.frame = frameToApply
                metalVC.mtlView.frame = metalVC.view.bounds
            }
            metalVC.view.isHidden = false
            metalVC.mtlView.isHidden = false
            metalVC.view.setNeedsLayout()
            metalVC.view.layoutIfNeeded()
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
            DLOG("🔴 Applied EXACT frame to Metal view: \(metalVC.view.frame)")
            DLOG("🔴 Applied size to MTLView: \(metalVC.mtlView.frame)")
            DLOG("🔴 Enabled custom positioning with EXACT frame: \(frameToApply)")
        } else {
            // For non-Metal views
            UIView.performWithoutAnimation {
                gameScreenView.frame = frameToApply
            }
            (gpuViewController as PVGPUViewController).useCustomPositioning = true
            (gpuViewController as PVGPUViewController).customFrame = frameToApply

            // Make sure the view is visible
            gameScreenView.isHidden = false

            DLOG("🔴 Applied EXACT frame to non-Metal view: \(gameScreenView.frame)")
        }

        // Force layout update
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // CRITICAL: Ensure GPU view is always behind the skin view
        // This must happen after frame is set to maintain correct z-order
        ensureGPUViewVisibilityAndZOrder()

        // Log the result
        DLOG("🔴 After applying frame:")
        DLOG("🔴   GPU view frame: \(gameScreenView.frame)")
        DLOG("🔴   View bounds: \(view.bounds)")
    }

    // Method moved to PVEmulatorViewController+DeltaSkin.swift


}
