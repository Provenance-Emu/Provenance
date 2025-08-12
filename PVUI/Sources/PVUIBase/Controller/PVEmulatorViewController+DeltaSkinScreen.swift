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
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Get the current system identifier
        guard let systemId = game.system?.systemIdentifier else {
            ELOG("System identifier not found")
            return
        }

        // Set up a notification observer to catch when the skin is loaded
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinLoaded"), object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSkinLoaded),
            name: NSNotification.Name("DeltaSkinLoaded"),
            object: nil
        )

        // Set up a notification observer to catch when the color bars frame is updated
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"), object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleColorBarsFrameUpdated),
            name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
            object: nil
        )

        // Try to position immediately in case the skin is already loaded
        Task {
            do {
                // Try to get the selected skin for this system
                let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId)

                // If we have a skin, position the GPU view based on its screen information
                if let skin = skin {
                    await MainActor.run {
                        // Try the standard positioning first
                        positionGPUViewWithSkin(skin)

                        // As a fallback, try manual positioning based on the view size
                        // This is a temporary solution until we get the debug output
                        let viewSize = view.bounds.size
                        let screenWidth = viewSize.width * 0.8  // 80% of view width
                        let screenHeight = screenHeight(for: screenWidth)
                        let x = (viewSize.width - screenWidth) / 2
                        let y = (viewSize.height - screenHeight) / 2

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.manuallyPositionGPUView(x: x, y: y, width: screenWidth, height: screenHeight)
                        }

                        // IMPORTANT: Force position with a hardcoded frame as a last resort
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//                            self?.forceGPUViewPosition()
//                        }
                    }
                } else {
                    DLOG("No skin found for \(systemId), using default GPU view position")
                    // If no skin is found, use the default position (full screen)
                    await MainActor.run {
                        resetGPUViewPosition()

                        // IMPORTANT: Force position with a hardcoded frame as a last resort
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//                            self?.forceGPUViewPosition()
//                        }
                    }
                }
            } catch {
                ELOG("Error loading skin: \(error)")
                // If there's an error, use the default position
                await MainActor.run {
                    resetGPUViewPosition()

                    // IMPORTANT: Force position with a hardcoded frame as a last resort
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//                        self?.forceGPUViewPosition()
//                    }
                }
            }
        }

        // Also schedule delayed positioning attempts to catch any race conditions
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            self?.tryPositionGPUView()
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
//            self?.tryPositionGPUView()
//
//            // IMPORTANT: Force position with a hardcoded frame as a final attempt
//            self?.forceGPUViewPosition()
//        }
    }

    /// Calculate screen height based on width and aspect ratio
    private func screenHeight(for width: CGFloat) -> CGFloat {
        // Default to 4:3 aspect ratio for most retro systems
        return width * (3.0 / 4.0)
    }

    @objc private func handleSkinLoaded(_ notification: Notification) {
        DLOG("🎮 Received skin loaded notification")
        tryPositionGPUView()
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

        // Apply the exact same frame to the GPU view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Create a debug overlay to show the frame
            self.createDebugOverlay(frame: colorBarsFrame)

            // Apply the frame to the GPU view - DIRECTLY without any modifications
            self.applyExactFrameToGPUView(colorBarsFrame)
        }
    }

    private func tryPositionGPUView() {
        guard let systemId = game.system?.systemIdentifier else { return }

        Task {
            do {
                if let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId) {
                    await MainActor.run {
                        positionGPUViewWithSkin(skin)
                    }
                }
            } catch {
                ELOG("Error in delayed positioning: \(error)")
            }
        }
    }

    /// Position the GPU view based on the skin's screen information
    private func positionGPUViewWithSkin(_ skin: DeltaSkinProtocol) {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Create traits based on the current device and orientation
        let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #if os(tvOS)
        let currentOrientation: DeltaSkinOrientation = .landscape
        #else
        let currentOrientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        #endif

        let traits = DeltaSkinTraits(
            device: currentDevice,
            displayType: .standard,
            orientation: currentOrientation
        )

        // Get the skin's mapping size for scaling calculations
        guard let mappingSize = skin.mappingSize(for: traits) else {
            DLOG("Skin has no mapping size, using default position")
            resetGPUViewPosition()
            return
        }

        // Calculate the view size and scale - EXACTLY matching the DeltaSkinScreenLayer
        let viewSize = view.bounds.size
        let scale = min(
            viewSize.width / mappingSize.width,
            viewSize.height / mappingSize.height
        )

        // Calculate the offset for centering the skin in the view - EXACTLY matching the DeltaSkinScreenLayer
        let xOffset = (viewSize.width - (mappingSize.width * scale)) / 2
        let yOffset = (viewSize.height - (mappingSize.height * scale)) / 2
        let offset = CGPoint(x: xOffset, y: yOffset)

        DLOG("GPU View Positioning - View Size: \(viewSize), Scale: \(scale), Offset: \(offset)")

        // Get the screen information from the skin
        if let screens = skin.screens(for: traits) {
            // Find the game screens (screens with placement = .app)
            let gameScreens = screens.filter { $0.placement == DeltaSkinScreenPlacement.app }

            if !gameScreens.isEmpty {
                // Log the found screens for debugging
                DLOG("Found \(gameScreens.count) game screens in the skin")
                for (index, screen) in gameScreens.enumerated() {
                    DLOG("Game screen \(index + 1): ID=\(screen.id), OutputFrame=\(screen.outputFrame?.debugDescription ?? "nil")")
                }

                // Use the first game screen for positioning
                if let firstScreen = gameScreens.first, let outputFrame = firstScreen.outputFrame {
                    // Calculate the frame using the EXACT SAME method as DeltaSkinScreenLayer
                    let finalFrame = scaledFrame(
                        outputFrame,
                        mappingSize: mappingSize,
                        scale: scale,
                        offset: offset
                    )

                    // DEBUG: Print the exact frame being used for GPU view
                    DLOG("GPU VIEW FRAME: \(finalFrame) for screen \(firstScreen.id)")
                    DLOG("  Original OutputFrame: \(outputFrame)")
                    DLOG("  MappingSize: \(mappingSize), Scale: \(scale), Offset: \(offset)")
                    DLOG("  View Bounds: \(view.bounds)")

                    DLOG("Positioning GPU view using explicit screen: \(finalFrame)")
                    applyFrame(finalFrame, to: gameScreenView)
                    return
                }
            } else {
                // If no app screens found, try to use any screen
                if let firstScreen = screens.first, let outputFrame = firstScreen.outputFrame {
                    // Calculate the frame using the EXACT SAME method as DeltaSkinScreenLayer
                    let finalFrame = scaledFrame(
                        outputFrame,
                        mappingSize: mappingSize,
                        scale: scale,
                        offset: offset
                    )

                    DLOG("Positioning GPU view using non-app screen: \(finalFrame)")
                    applyFrame(finalFrame, to: gameScreenView)
                    return
                }
            }
        }

        // If no explicit screens found, try to use a default screen position based on buttons
        if let buttons = skin.buttons(for: traits), !buttons.isEmpty {
            // Find the topmost button to position screen above it
            if let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
                let buttonTopY = topButton.frame.minY

                // Use the space above the buttons for the screen
                let defaultFrame = CGRect(
                    x: 0,
                    y: 0,
                    width: mappingSize.width,
                    height: buttonTopY * 0.95 // Leave a small gap
                )

                // Calculate the frame using the EXACT SAME method as DeltaSkinScreenLayer
                let finalFrame = scaledFrame(
                    defaultFrame,
                    mappingSize: mappingSize,
                    scale: scale,
                    offset: offset
                )

                DLOG("Positioning GPU view above buttons: \(finalFrame)")
                applyFrame(finalFrame, to: gameScreenView)
                return
            }
        }

        // Last resort: use top half of the skin for the screen
        let defaultFrame = CGRect(
            x: 0,
            y: 0,
            width: mappingSize.width,
            height: mappingSize.height * 0.5
        )

        // Calculate the frame using the EXACT SAME method as DeltaSkinScreenLayer
        let finalFrame = scaledFrame(
            defaultFrame,
            mappingSize: mappingSize,
            scale: scale,
            offset: offset
        )

        DLOG("Positioning GPU view using default top half: \(finalFrame)")
        applyFrame(finalFrame, to: gameScreenView)

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
        let viewSize = view.bounds.size
        let scale = min(viewSize.width / mappingSize.width, viewSize.height / mappingSize.height)
        let offset = CGPoint(
            x: (viewSize.width - (mappingSize.width * scale)) / 2,
            y: (viewSize.height - (mappingSize.height * scale)) / 2
        )
        if let screens = skin.screens(for: traits) {
            let gameScreens = screens.filter { $0.placement == DeltaSkinScreenPlacement.app }
            if let first = gameScreens.first, let output = first.outputFrame {
                return scaledFrame(output, mappingSize: mappingSize, scale: scale, offset: offset)
            }
            if let first = screens.first, let output = first.outputFrame {
                return scaledFrame(output, mappingSize: mappingSize, scale: scale, offset: offset)
            }
        }
        if let buttons = skin.buttons(for: traits), !buttons.isEmpty,
           let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) {
            let defaultFrame = CGRect(x: 0, y: 0, width: mappingSize.width, height: topButton.frame.minY * 0.95)
            return scaledFrame(defaultFrame, mappingSize: mappingSize, scale: scale, offset: offset)
        }
        let defaultFrame = CGRect(x: 0, y: 0, width: mappingSize.width, height: mappingSize.height * 0.5)
        return scaledFrame(defaultFrame, mappingSize: mappingSize, scale: scale, offset: offset)
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
        gameScreenView.frame = frame

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
            DLOG("Setting MTLView layer frame directly: \(frame)")
            DLOG("  Current MTLView frame: \(metalVC.mtlView.frame)")
            DLOG("  Current MTLView layer frame: \(metalVC.mtlView.layer.frame)")

            // Set both the view and layer frames
            metalVC.mtlView.frame = frame
            metalVC.mtlView.layer.frame = frame

            // Force redraw
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
            metalVC.draw(in: metalVC.mtlView)

            DLOG("  After MTLView frame: \(metalVC.mtlView.frame)")
            DLOG("  After MTLView layer frame: \(metalVC.mtlView.layer.frame)")
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

        // Try a delayed positioning as well to catch any race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak gameScreenView] in
            guard let self = self, let gameScreenView = gameScreenView else { return }

            DLOG("DELAYED GPU VIEW CHECK:")
            DLOG("  Frame after delay: \(gameScreenView.frame)")

            // If the frame has changed, reapply it
            if gameScreenView.frame != frame {
                DLOG("  Frame changed, reapplying...")
                gameScreenView.frame = frame

                // Also reapply to MTLView if available
                if let metalVC = self.gpuViewController as? PVMetalViewController {
                    metalVC.mtlView.frame = frame
                    metalVC.mtlView.layer.frame = frame
                    metalVC.mtlView.setNeedsLayout()
                    metalVC.mtlView.layoutIfNeeded()
                    metalVC.draw(in: metalVC.mtlView)
                }

                gameScreenView.setNeedsLayout()
                gameScreenView.layoutIfNeeded()
            }
        }
    }

    /// Reset the GPU view to its default position (full screen)
    internal func resetGPUViewPosition() {
        guard let gameScreenView = gpuViewController.view else {
            ELOG("GPU view not found")
            return
        }

        // Set the GPU view to fill the entire screen
        gameScreenView.frame = view.bounds
        gameScreenView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameScreenView.contentMode = .scaleAspectFit
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // Set the MTLView layer frame as well
        if let metalVC = gpuViewController as? PVMetalViewController {
            metalVC.mtlView.frame = view.bounds
            metalVC.mtlView.layer.frame = view.bounds
            metalVC.mtlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            metalVC.mtlView.contentMode = .scaleAspectFit

            // Force redraw
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
            metalVC.draw(in: metalVC.mtlView)
        }
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
        gameScreenView.frame = frame
        gameScreenView.autoresizingMask = []
        gameScreenView.contentMode = .scaleToFill
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0

        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // IMPORTANT: Set the MTLView layer frame directly
        if let metalVC = gpuViewController as? PVMetalViewController {
            DLOG("Setting MTLView layer frame directly: \(frame)")

            // Set both the view and layer frames
            metalVC.mtlView.frame = frame
            metalVC.mtlView.layer.frame = frame

            // Force redraw
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
            metalVC.draw(in: metalVC.mtlView)

            // Schedule another check to make sure the frame sticks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak metalVC] in
                guard let metalVC = metalVC else { return }

                DLOG("DELAYED CHECK - MTLView frame: \(metalVC.mtlView.frame)")
                DLOG("DELAYED CHECK - MTLView layer frame: \(metalVC.mtlView.layer.frame)")

                // If the frame changed, reapply it
                if metalVC.mtlView.frame != frame || metalVC.mtlView.layer.frame != frame {
                    DLOG("Frame changed after positioning, reapplying...")
                    metalVC.mtlView.frame = frame
                    metalVC.mtlView.layer.frame = frame
                    metalVC.mtlView.setNeedsLayout()
                    metalVC.mtlView.layoutIfNeeded()
                    metalVC.draw(in: metalVC.mtlView)
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

    /// Apply a frame directly to the GPU view with optimized positioning
    private func applyFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            DLOG("🔴 ERROR: GPU view not found")
            return
        }

        // If this is a RetroArch core, size its internal renderView directly
        if core.coreIdentifier?.contains("libretro") == true,
           let bridge = core.bridge as? (any NSObjectProtocol) {
            if let viewportBridge = bridge as? EmulatorCoreViewportPositioning {
                // Ensure RA uses custom layout and apply frame in touchView space
                viewportBridge.setUseCustomRenderViewLayout(true)
                // Frame passed is already in self.view coordinates; convert to touchViewController.view
                if let parent = core.touchViewController?.view {
                    let rectInParent = view.convert(frame, to: parent)
                    viewportBridge.applyRenderViewFrameInTouchView(rectInParent)
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
        DLOG("🔴 Using frame: \(optimizedFrame)")

        DLOG("🔴 Applying frame to GPU view: \(optimizedFrame)")
        DLOG("🔴 Current GPU view frame before: \(gameScreenView.frame)")

        // Apply the frame to the GPU view
        applyExactFrameToGPUView(optimizedFrame)
    }

    /// Apply an exact frame to the GPU view without any modifications
    private func applyExactFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            DLOG("🔴 ERROR: GPU view not found")
            return
        }

        // If this is a RetroArch core, size its internal renderView directly
        if core.coreIdentifier?.contains("libretro") == true,
           let bridge = core.bridge as? (any NSObjectProtocol) {
            if let viewportBridge = bridge as? EmulatorCoreViewportPositioning {
                // Ensure RA uses custom layout and apply frame in touchView space
                viewportBridge.setUseCustomRenderViewLayout(true)
                // Frame passed is already in self.view coordinates; convert to touchViewController.view
                if let parent = core.touchViewController?.view {
                    let rectInParent = view.convert(frame, to: parent)
                    viewportBridge.applyRenderViewFrameInTouchView(rectInParent)
                    DLOG("🔴 Applied frame to RA renderView: \(rectInParent)")
                    return
                }
            }
        }

        // Validate the frame - ensure it has valid dimensions
        guard frame.width > 0 && frame.height > 0 else {
            DLOG("🔴 ERROR: Invalid frame dimensions: \(frame)")
            return
        }

        DLOG("🔴 Applying EXACT frame to GPU view: \(frame)")
        DLOG("🔴 Current GPU view frame before: \(gameScreenView.frame)")

        // Apply the frame - ONLY set the frame, nothing else
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Enable custom positioning - explicitly reference properties from PVGPUViewController
            (metalVC as PVGPUViewController).useCustomPositioning = true
            (metalVC as PVGPUViewController).customFrame = frame

            // Apply the frame to both the view and MTLView
            metalVC.view.frame = frame
            metalVC.mtlView.frame = CGRect(origin: .zero, size: frame.size) // MTLView is positioned within its parent view

            // Force a redraw
            metalVC.mtlView.setNeedsDisplay()
            metalVC.draw(in: metalVC.mtlView)

            // Make sure the view is visible
            metalVC.view.isHidden = false
            metalVC.mtlView.isHidden = false

            DLOG("🔴 Applied EXACT frame to Metal view: \(metalVC.view.frame)")
            DLOG("🔴 Applied size to MTLView: \(metalVC.mtlView.frame)")
            DLOG("🔴 Enabled custom positioning with EXACT frame: \(frame)")
        } else {
            // For non-Metal views
            gameScreenView.frame = frame
            (gpuViewController as PVGPUViewController).useCustomPositioning = true
            (gpuViewController as PVGPUViewController).customFrame = frame

            // Make sure the view is visible
            gameScreenView.isHidden = false

            DLOG("🔴 Applied EXACT frame to non-Metal view: \(gameScreenView.frame)")
        }

        // Force layout update
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()

        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }

        // Log the result
        DLOG("🔴 After applying frame:")
        DLOG("🔴   GPU view frame: \(gameScreenView.frame)")
    }

    // Method moved to PVEmulatorViewController+DeltaSkin.swift


}
