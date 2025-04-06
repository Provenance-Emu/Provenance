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
    }
    
    /// Whether the audio visualizer is currently enabled
    var isAudioVisualizerEnabled: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.audioVisualizerEnabledKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.audioVisualizerEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if newValue {
                setupAudioVisualizer()
            } else {
                removeAudioVisualizer()
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
        
        // Create the retrowave-styled audio visualizer view
        let visualizerView = RetrowaveDynamicIslandAudioVisualizer(
            audioEngine: gameAudio,
            numberOfPoints: 60,
            updateInterval: 0.03 // More frequent updates for better responsiveness
        )
        
        // Create a hosting controller for the SwiftUI view
        let hostingController = UIHostingController(
            rootView: AnyView(visualizerView)
        )
        
        // Configure the hosting controller
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the hosting controller as a child
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
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
        isAudioVisualizerEnabled.toggle()
        
        if isAudioVisualizerEnabled {
            showAudioVisualizer()
        } else {
            hideAudioVisualizer()
        }
        
        // Save the preference
        UserDefaults.standard.set(isAudioVisualizerEnabled, forKey: "PVAudioVisualizerEnabled")
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
