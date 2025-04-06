import UIKit
import SwiftUI
import PVCoreAudio
import PVEmulatorCore
import PVLibrary
import PVLogging
import PVUIBase
import QuartzCore
import Combine
import PVThemes

// MARK: - Audio Visualizer Extension

/// Extension to add audio visualization support to the emulator view controller
extension PVEmulatorViewController {
    
    /// Property to track if the audio visualizer is enabled
    private struct AssociatedKeys {
        static var audioVisualizerEnabledKey = "audioVisualizerEnabled"
        static var audioVisualizerHostingControllerKey = "audioVisualizerHostingController"
        static var audioVisualizerModeKey = "audioVisualizerMode"
    }
    
    /// Whether the audio visualizer is currently enabled
    var isAudioVisualizerEnabled: Bool {
        get {
            return visualizerMode != .off
        }
        set {
            // For backward compatibility
            visualizerMode = newValue ? .standard : .off
        }
    }
    
    /// The current visualizer mode
    var visualizerMode: VisualizerMode {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.audioVisualizerModeKey) as? VisualizerMode ?? VisualizerMode.current
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.audioVisualizerModeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if newValue == .off {
                removeAudioVisualizer()
            } else {
                setupAudioVisualizer()
            }
        }
    }
    
    /// The hosting controller for the audio visualizer
    private var audioVisualizerHostingController: UIHostingController<AnyView>? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.audioVisualizerHostingControllerKey) as? UIHostingController<AnyView>
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.audioVisualizerHostingControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Set up the audio visualizer if the device supports it
    @objc public func setupAudioVisualizer() {
        // Only proceed if we're on iOS 16 or later
        guard #available(iOS 16.0, *) else {
            DLOG("Audio visualizer requires iOS 16 or later")
            return
        }
        
        // Check if we already have a visualizer
        if audioVisualizerHostingController != nil {
            return
        }
        
        // Create the appropriate visualizer based on the selected mode
        let visualizerView: AnyView
        
        switch visualizerMode {
        case .off:
            return // Don't create a visualizer if mode is off
            
        case .standard:
            // Create the standard retrowave audio visualizer
            visualizerView = AnyView(
                RetrowaveDynamicIslandAudioVisualizer(
                    audioEngine: gameAudio,
                    numberOfPoints: 60,
                    updateInterval: 0.03
                )
            )
            
        case .metal:
            // Create the Metal-based retrowave audio visualizer
            visualizerView = AnyView(
                MetalDynamicIslandAudioVisualizer(
                    audioEngine: gameAudio,
                    numberOfPoints: 128, // More points for higher resolution
                    updateInterval: 0.016 // 60fps updates
                )
            )
        }
        
        // Create a hosting controller for the SwiftUI view
        let hostingController = UIHostingController(
            rootView: visualizerView
        )
        
        // Configure the hosting controller
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the hosting controller as a child
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Ensure proper z-order (visualizer stays on top)
        view.bringSubviewToFront(hostingController.view)
        
        // Set up constraints to position at the Dynamic Island
        let screenWidth = UIScreen.main.bounds.width
        let visualizerWidth = min(screenWidth * 0.8, 300) // Limit width
        
        // Calculate top offset based on device model
        let topOffset = getDynamicIslandTopOffset()
        
        NSLayoutConstraint.activate([
            // Position at the top center of the screen where the Dynamic Island is
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset),
            hostingController.view.widthAnchor.constraint(equalToConstant: visualizerWidth),
            hostingController.view.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Store reference to the hosting controller
        audioVisualizerHostingController = hostingController
        
        // Store the hosting controller
        audioVisualizerHostingController = hostingController
        
        DLOG("Audio visualizer set up successfully")
    }
    
    /// Remove the audio visualizer
    @objc public func removeAudioVisualizer() {
        guard let hostingController = audioVisualizerHostingController else {
            return
        }
        
        // Remove the hosting controller
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        
        // Clear the reference
        audioVisualizerHostingController = nil
        
        DLOG("Audio visualizer removed")
    }
}

// MARK: - Menu Integration

extension PVEmulatorViewController {
    /// Show the audio visualizer
    @objc public func showAudioVisualizer() {
        setupAudioVisualizer()
    }
    
    /// Hide the audio visualizer
    @objc public func hideAudioVisualizer() {
        removeAudioVisualizer()
    }
    
    /// Toggle the audio visualizer on/off
    @objc public func toggleAudioVisualizer() {
        // Toggle between off and the last used mode (or standard if none)
        if visualizerMode == .off {
            // Get the last used mode from user defaults, or use standard as default
            visualizerMode = VisualizerMode.current != .off ? VisualizerMode.current : .standard
        } else {
            visualizerMode = .off
        }
        
        // Update UI based on new mode
        if visualizerMode == .off {
            hideAudioVisualizer()
        } else {
            showAudioVisualizer()
        }
        
        // Save the preference
        visualizerMode.saveToUserDefaults()
    }
    
    /// Set a specific visualizer mode
    @objc public func setVisualizerMode(_ mode: VisualizerMode) {
        // Only update if the mode has changed
        if visualizerMode != mode {
            visualizerMode = mode
            
            // Update UI based on new mode
            if mode == .off {
                hideAudioVisualizer()
            } else {
                // Remove existing visualizer if any
                removeAudioVisualizer()
                // Set up new visualizer with the selected mode
                setupAudioVisualizer()
            }
        }
    }
    
    /// Get the appropriate top offset for the Dynamic Island based on device model
    private func getDynamicIslandTopOffset() -> CGFloat {
        let deviceName = UIDevice.current.name
        
        // Default offset for iPhone 14 Pro/15 Pro
        var topOffset: CGFloat = 11
        
        // iPhone 14 Pro Max/15 Pro Max has slightly different dimensions
        if deviceName.contains("Max") {
            topOffset = 12
        }
        // iPhone 15/16 base models
        else if deviceName.contains("iPhone 15") || deviceName.contains("iPhone 16") {
            topOffset = 11
        }
        // iPhone 16 Pro/Pro Max
        else if deviceName.contains("iPhone 16 Pro") {
            topOffset = 11
        }
        
        return topOffset
    }
}
