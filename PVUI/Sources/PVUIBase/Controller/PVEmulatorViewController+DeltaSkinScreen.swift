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
        
        // Try to position immediately in case the skin is already loaded
        Task {
            do {
                // Try to get the selected skin for this system
                let skin = try await DeltaSkinManager.shared.skinToUse(for: systemId)
                
                // If we have a skin, position the GPU view based on its screen information
                if let skin = skin {
                    await MainActor.run {
                        positionGPUViewWithSkin(skin)
                    }
                } else {
                    DLOG("No skin found for \(systemId), using default GPU view position")
                    // If no skin is found, use the default position (full screen)
                    await MainActor.run {
                        resetGPUViewPosition()
                    }
                }
            } catch {
                ELOG("Error loading skin: \(error)")
                // If there's an error, use the default position
                await MainActor.run {
                    resetGPUViewPosition()
                }
            }
        }
        
        // Also schedule delayed positioning attempts to catch any race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tryPositionGPUView()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.tryPositionGPUView()
        }
    }
    
    @objc private func handleSkinLoaded(_ notification: Notification) {
        DLOG("🎮 Received skin loaded notification")
        tryPositionGPUView()
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
        
        // Calculate the view size and scale
        let viewSize = view.bounds.size
        let scale = min(
            viewSize.width / mappingSize.width,
            viewSize.height / mappingSize.height
        )
        
        // Calculate the offset for centering the skin in the view
        let xOffset = (viewSize.width - (mappingSize.width * scale)) / 2
        let yOffset = (viewSize.height - (mappingSize.height * scale)) / 2
        let offset = CGPoint(x: xOffset, y: yOffset)
        
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
                    // Calculate the scaled frame using the same method as DeltaSkinScreenLayer
                    let finalFrame = scaledFrame(
                        outputFrame,
                        mappingSize: mappingSize,
                        scale: scale,
                        offset: offset
                    )
                    
                    DLOG("Positioning GPU view using explicit screen: \(finalFrame)")
                    applyFrame(finalFrame, to: gameScreenView)
                    return
                }
            }
        }
        
        // If no explicit screens found, try to use a default screen position
        let outputFrame = DeltaSkinDefaults.defaultScreenFrame(
            for: skin.gameType,
            in: mappingSize,
            buttons: skin.buttons(for: traits),
            isPreview: false
        )
        
        // Calculate the scaled frame
        let finalFrame = scaledFrame(
            outputFrame,
            mappingSize: mappingSize,
            scale: scale,
            offset: offset
        )
        
        DLOG("Positioning GPU view using default screen frame: \(finalFrame)")
        applyFrame(finalFrame, to: gameScreenView)
        
    }
    
    /// Scale a frame using the same method as DeltaSkinScreenLayer
    private func scaledFrame(
        _ frame: CGRect,
        mappingSize: CGSize,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGRect {
        CGRect(
            x: frame.minX * scale + offset.x,
            y: frame.minY * scale + offset.y,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }
    
    /// Apply the calculated frame to the GPU view
    private func applyFrame(_ frame: CGRect, to gameScreenView: UIView) {
        // Log the calculated frame for debugging
        DLOG("""
        Applying frame to GPU view:
        - Frame: \(frame)
        - Origin: (\(frame.origin.x), \(frame.origin.y))
        - Size: \(frame.width) x \(frame.height)
        """)
        
        // Apply the calculated frame to the GPU view
        gameScreenView.frame = frame
        
        // Remove autoresizing mask to prevent automatic resizing
        gameScreenView.autoresizingMask = []
        
        // Make sure the GPU view is visible
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0
        
        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()
        
        // Make sure GPU view is behind the skin view
        if let skinContainerView = view.subviews.first(where: { $0 is DeltaSkinContainerView }) {
            view.insertSubview(gameScreenView, belowSubview: skinContainerView)
        }
        
        // Force a redraw of the GPU view
        if let metalVC = gpuViewController as? PVMetalViewController {
            metalVC.draw(in: metalVC.mtlView)
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
        gameScreenView.isHidden = false
        gameScreenView.alpha = 1.0
        
        // Force layout
        gameScreenView.setNeedsLayout()
        gameScreenView.layoutIfNeeded()
        
        // Force a redraw of the GPU view
        if let metalVC = gpuViewController as? PVMetalViewController {
            metalVC.draw(in: metalVC.mtlView)
        }
    }
}
