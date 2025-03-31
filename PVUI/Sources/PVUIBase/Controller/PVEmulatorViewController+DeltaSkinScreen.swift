import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary
import PVLogging

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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.forceGPUViewPosition()
                        }
                    }
                } else {
                    DLOG("No skin found for \(systemId), using default GPU view position")
                    // If no skin is found, use the default position (full screen)
                    await MainActor.run {
                        resetGPUViewPosition()
                        
                        // IMPORTANT: Force position with a hardcoded frame as a last resort
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.forceGPUViewPosition()
                        }
                    }
                }
            } catch {
                ELOG("Error loading skin: \(error)")
                // If there's an error, use the default position
                await MainActor.run {
                    resetGPUViewPosition()
                    
                    // IMPORTANT: Force position with a hardcoded frame as a last resort
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.forceGPUViewPosition()
                    }
                }
            }
        }
        
        // Also schedule delayed positioning attempts to catch any race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tryPositionGPUView()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.tryPositionGPUView()
            
            // IMPORTANT: Force position with a hardcoded frame as a final attempt
            self?.forceGPUViewPosition()
        }
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
            return
        }
        
        // Extract the frame from the notification
        let colorBarsFrame = frameValue.cgRectValue
        
        // Log the color bars frame for debugging
        print("🔴 Received color bars frame: \(colorBarsFrame)")
        
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
        let currentOrientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
        
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
                    print("GPU VIEW FRAME: \(finalFrame) for screen \(firstScreen.id)")
                    print("  Original OutputFrame: \(outputFrame)")
                    print("  MappingSize: \(mappingSize), Scale: \(scale), Offset: \(offset)")
                    print("  View Bounds: \(view.bounds)")
                    
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
        
        print("🔴 Calculated frame without explicit position:")
        print("🔴   View size: \(viewSize)")
        print("🔴   Layout dimensions: width=\(layoutWidth), height=\(layoutHeight)")
        print("🔴   Top button Y: \(topButton.frame.minY), Scaled: \(skinTopY)")
        print("🔴   Available space: \(availableSpace)")
        print("🔴   Screen dimensions: width=\(screenWidth), height=\(screenHeight), x=\(screenX), y=\(screenY)")
        
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
        print("GPU VIEW BEFORE POSITIONING:")
        print("  Current frame: \(gameScreenView.frame)")
        print("  Transform: \(gameScreenView.transform)")
        print("  AutoresizingMask: \(gameScreenView.autoresizingMask.rawValue)")
        print("  ContentMode: \(gameScreenView.contentMode.rawValue)")
        
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
            print("Setting MTLView layer frame directly: \(frame)")
            print("  Current MTLView frame: \(metalVC.mtlView.frame)")
            print("  Current MTLView layer frame: \(metalVC.mtlView.layer.frame)")
            
            // Set both the view and layer frames
            metalVC.mtlView.frame = frame
            metalVC.mtlView.layer.frame = frame
            
            // Force redraw
            metalVC.mtlView.setNeedsLayout()
            metalVC.mtlView.layoutIfNeeded()
            metalVC.draw(in: metalVC.mtlView)
            
            print("  After MTLView frame: \(metalVC.mtlView.frame)")
            print("  After MTLView layer frame: \(metalVC.mtlView.layer.frame)")
        }
        
        // DEBUG: Print after positioning
        print("GPU VIEW AFTER POSITIONING:")
        print("  New frame: \(gameScreenView.frame)")
        print("  Transform: \(gameScreenView.transform)")
        print("  AutoresizingMask: \(gameScreenView.autoresizingMask.rawValue)")
        print("  ContentMode: \(gameScreenView.contentMode.rawValue)")
        
        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }
        
        // Try a delayed positioning as well to catch any race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak gameScreenView] in
            guard let self = self, let gameScreenView = gameScreenView else { return }
            
            print("DELAYED GPU VIEW CHECK:")
            print("  Frame after delay: \(gameScreenView.frame)")
            
            // If the frame has changed, reapply it
            if gameScreenView.frame != frame {
                print("  Frame changed, reapplying...")
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
    private func resetGPUViewPosition() {
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
        print("MANUALLY POSITIONING GPU VIEW: \(frame)")
        
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
            print("Setting MTLView layer frame directly: \(frame)")
            
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
                
                print("DELAYED CHECK - MTLView frame: \(metalVC.mtlView.frame)")
                print("DELAYED CHECK - MTLView layer frame: \(metalVC.mtlView.layer.frame)")
                
                // If the frame changed, reapply it
                if metalVC.mtlView.frame != frame || metalVC.mtlView.layer.frame != frame {
                    print("Frame changed after positioning, reapplying...")
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
                    let currentDevice: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
                    let currentOrientation: DeltaSkinOrientation = UIDevice.current.orientation.isLandscape ? .landscape : .portrait
                    
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
                        
                        print("🔴 EXACTLY matching DeltaSkinScreenLayer calculation:")
                        print("🔴   Original OutputFrame: \(outputFrame)")
                        print("🔴   View Size: \(viewSize)")
                        print("🔴   Mapping Size: \(mappingSize)")
                        print("🔴   Scale: \(scale)")
                        print("🔴   Offset: \(offset)")
                        print("🔴   Calculated Frame: \(calculatedFrame)")
                        
                        print("🔴 Using explicit screen frame from screens array:")
                        print("🔴   Original OutputFrame: \(outputFrame)")
                        print("🔴   Scaled Frame: \(calculatedFrame)")
                        print("🔴   MappingSize: \(mappingSize), Scale: \(scale), Offset: \(offset)")
                        
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
                        
                        print("🔴 Using gameScreenFrame from raw dictionary:")
                        print("🔴   Original Frame: \(gameScreenFrame)")
                        print("🔴   Scaled Frame: \(calculatedFrame)")
                        
                        await MainActor.run {
                            createDebugOverlay(frame: calculatedFrame)
                            applyFrameToGPUView(calculatedFrame)
                        }
                        return
                    }
                    
                    // Check if this skin has explicit screen positions by other means
                    let hasExplicitScreenPosition = hasScreenPosition(skin: skin, traits: traits)
                    print("🔴 Skin has explicit screen position: \(hasExplicitScreenPosition)")
                    
                    var calculatedFrame: CGRect
                    
                    if !hasExplicitScreenPosition {
                        // CASE 1: Skin does NOT have explicit screen position
                        // Calculate screen position based on available space above skin
                        calculatedFrame = calculateFrameWithoutExplicitPosition(skin: skin, traits: traits, viewSize: viewSize)
                        print("🔴 Using calculated frame for skin without explicit position: \(calculatedFrame)")
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
                        print("🔴 Using default screen frame: \(defaultFrame) → \(calculatedFrame)")
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
    
    /// Create a debug overlay with the given frame
    private func createDebugOverlay(frame: CGRect) {
        // Store the current target frame for positioning
        currentTargetFrame = frame
        
        // Remove any existing debug overlays
        view.subviews.forEach { subview in
            if subview.tag == 9999 {
                subview.removeFromSuperview()
            }
        }
        
        print("""
            🔴 ADDING DEBUG OVERLAY at: \(frame)
            🔴 View bounds: \(view.bounds)
            """ )
        
        // Create a debug overlay view
        let debugOverlay = UIView(frame: frame)
        debugOverlay.tag = 9999 // Use a tag to identify it later
        debugOverlay.backgroundColor = UIColor.red.withAlphaComponent(0.3)
        debugOverlay.layer.borderColor = UIColor.yellow.cgColor
        debugOverlay.layer.borderWidth = 2.0
        
        // Add a label to show the frame
        let labelWidth = frame.width - 20
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: labelWidth, height: 60))
        label.text = "Expected GPU View\nFrame: \(frame)"
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)
        debugOverlay.addSubview(label)
        
        // Add the debug overlay to the view
        view.addSubview(debugOverlay)
        
        // Make sure it's above everything else
        view.bringSubviewToFront(debugOverlay)
        // Log the current GPU view frame for comparison
        if let gameScreenView = gpuViewController.view {
            print("🔴 Current GPU view frame: \(gameScreenView.frame)")
            
            if let metalVC = gpuViewController as? PVMetalViewController {
                print("🔴 Current MTLView frame: \(metalVC.mtlView.frame)")
            }
        }
        
        // Add buttons to test different positioning approaches
        addDebugButtons(targetFrame: frame)
    }
    
    /// Add debug buttons to test different positioning approaches
    private func addDebugButtons(targetFrame: CGRect) {
        // Create a container for the buttons
        let buttonContainer = UIView(frame: CGRect(x: 20, y: 20, width: 200, height: 150))
        buttonContainer.tag = 9999 // Use the same tag for easy removal
        buttonContainer.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        buttonContainer.layer.cornerRadius = 10
        
        // Add a title
        let titleLabel = UILabel(frame: CGRect(x: 10, y: 5, width: 140, height: 20))
        titleLabel.text = "Debug Controls"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
        buttonContainer.addSubview(titleLabel)
        
        // Add buttons for different positioning approaches
        let button1 = createDebugButton(title: "Try Frame", y: 30, action: #selector(tryFramePositioning))
        let button2 = createDebugButton(title: "Reset Position", y: 70, action: #selector(resetPositioning))
        
        buttonContainer.addSubview(button1)
        buttonContainer.addSubview(button2)
        
        // Add the button container to the view
        view.addSubview(buttonContainer)
        view.bringSubviewToFront(buttonContainer)
    }
    
    /// Create a debug button with the given title and action
    private func createDebugButton(title: String, y: CGFloat, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10, y: y, width: 180, height: 30)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 5
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    /// Try positioning using frame
    @objc private func tryFramePositioning() {
        // Use the stored target frame instead of trying to find a debug overlay
        guard let frame = currentTargetFrame else {
            print("🔴 No target frame available for positioning")
            return
        }
        
        print("🔴 Trying frame positioning: \(frame)")
        
        // Apply the frame to the GPU view
        applyFrameToGPUView(frame)
    }
    
    /// Apply a frame directly to the GPU view with optimized positioning
    private func applyFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            print("🔴 ERROR: GPU view not found")
            return
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
        print("🔴 Using frame: \(optimizedFrame)")
        
        print("🔴 Applying frame to GPU view: \(optimizedFrame)")
        print("🔴 Current GPU view frame before: \(gameScreenView.frame)")
        
        // Apply the frame to the GPU view
        applyExactFrameToGPUView(optimizedFrame)
    }
        
    /// Apply an exact frame to the GPU view without any modifications
    private func applyExactFrameToGPUView(_ frame: CGRect) {
        guard let gameScreenView = gpuViewController.view else {
            print("🔴 ERROR: GPU view not found")
            return
        }
        
        print("🔴 Applying EXACT frame to GPU view: \(frame)")
        print("🔴 Current GPU view frame before: \(gameScreenView.frame)")
        
        // Apply the frame - ONLY set the frame, nothing else
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Enable custom positioning - explicitly reference properties from PVGPUViewController
            (metalVC as PVGPUViewController).useCustomPositioning = true
            (metalVC as PVGPUViewController).customFrame = frame
            
            // Apply the frame to both the view and MTLView
            metalVC.view.frame = frame
            metalVC.mtlView.frame = frame
            
            // Force a redraw
            metalVC.mtlView.setNeedsDisplay()
            metalVC.draw(in: metalVC.mtlView)
            
            // Make sure the view is visible
            metalVC.view.isHidden = false
            metalVC.mtlView.isHidden = false
            
            print("🔴 Applied EXACT frame to MTLView: \(metalVC.mtlView.frame)")
            print("🔴 Enabled custom positioning with EXACT frame: \(frame)")
        } else {
            // For non-Metal views
            gameScreenView.frame = frame
            (gpuViewController as PVGPUViewController).useCustomPositioning = true
            (gpuViewController as PVGPUViewController).customFrame = frame
            
            // Make sure the view is visible
            gameScreenView.isHidden = false
            
            print("🔴 Applied EXACT frame to non-Metal view: \(gameScreenView.frame)")
        }
        
        // Force layout update
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()
        
        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }
        
        // Log the result
        print("🔴 After applying frame:")
        print("🔴   GPU view frame: \(gameScreenView.frame)")
    }
    
    /// Reset to default positioning
    @objc private func resetPositioning() {
        // Disable custom positioning first
        if let metalVC = gpuViewController as? PVMetalViewController {
            // Explicitly reference properties from PVGPUViewController
            (metalVC as PVGPUViewController).useCustomPositioning = false
            (metalVC as PVGPUViewController).customFrame = .zero
            print("🔴 Disabled custom positioning")
        }
        
        // Then reset to default
        resetGPUViewPosition()
        print("🔴 Reset to default positioning")
    }
    

}
