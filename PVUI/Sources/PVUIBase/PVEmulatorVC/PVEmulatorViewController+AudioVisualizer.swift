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

    /// Set up the audio visualizer if the device and core support it
    @objc public func setupAudioVisualizer() {
        // Only proceed if we're on iOS 16 or later
        guard #available(iOS 16.0, *) else {
            DLOG("Audio visualizer requires iOS 16 or later")
            return
        }

        // Check if the core supports audio visualizer
        guard core.supportsAudioVisualizer else {
            DLOG("Core does not support audio visualizer: \(core.description)")
            return
        }

        // Remove any existing visualizer first to ensure we're using the correct mode
        removeAudioVisualizer()

        // Check if visualizer is disabled
        if visualizerMode == .off {
            return
        }

        // Create the appropriate visualizer based on the selected mode
        let visualizerView: AnyView
        let isRetroArch = core.coreIdentifier?.contains("libretro") == true
        DLOG("core identifier: \(core.coreIdentifier ?? "null")")
        // Acquire waveform provider from bridge if available
        let provider: (any EmulatorCoreWaveformProvider)? = {
            guard isRetroArch, let objcCore = core as? (any ObjCBridgedCore) else {
                DLOG("isRetroArch: \(isRetroArch ? "Yes" : "No")")
                return nil
            }
            if let typed = objcCore.bridge as? (any EmulatorCoreWaveformProvider) {
                DLOG("Has audio visualizer api? Yes (typed)")
                return typed
            } else {
                DLOG("Has audio visualizer api? No")
                return nil
            }
        }()

        // For RetroArch, enable the waveform tap immediately so data starts flowing
        if let provider = provider {
            provider.installWaveformTap()
            DLOG("Installed RA waveform tap from setupAudioVisualizer (typed)")
        }

        // Choose engine: RA taps its own audio, others use our engine
        let engine: AudioEngineProtocol = isRetroArch ? RAAudioTapEngine(provider: provider) : gameAudio

        switch visualizerMode {
        case .off:
            return // Don't create a visualizer if mode is off

        case .standard:
            // Create the standard bar-style retrowave audio visualizer
            visualizerView = AnyView(
                RetrowaveDynamicIslandAudioVisualizer(
                    audioEngine: engine,
                    numberOfPoints: 60,
                    updateInterval: 0.008 // 120fps updates for smoother animation
                )
            )

        case .standardCircular:
            // Create the standard circular retrowave audio visualizer
            visualizerView = AnyView(
                RetrowaveDynamicIslandAudioVisualizer(
                    audioEngine: engine,
                    numberOfPoints: 60,
                    updateInterval: 0.008, // 120fps updates for smoother animation
                    isCircular: true
                )
            )

        case .metal:
            // Create the enhanced Metal-based bar-style retrowave audio visualizer
            visualizerView = AnyView(
                EnhancedMetalVisualizer(
                    audioEngine: engine,
                    numberOfPoints: 128, // More points for higher resolution
                    updateInterval: 0.008 // 120fps updates for smoother animation
                )
            )

        case .metalCircular:
            // Get the actual Dynamic Island dimensions
            let islandFrame = DynamicIslandPositioner.getDynamicIslandFrame()

            // Create the enhanced circular Metal visualizer with actual dimensions
            visualizerView = AnyView(
                EnhancedCircularMetalVisualizer(
                    audioEngine: engine,
                    numberOfPoints: 128, // More points for higher resolution
                    islandWidth: islandFrame.width,
                    islandHeight: islandFrame.height,
                    updateInterval: 0.008 // 120fps updates for smoother animation
                )
                .positionedAtDynamicIsland()
            )
        }

        // Create a hosting controller for the SwiftUI view
        let hostingController = UIHostingController(
            rootView: visualizerView
        )

        // Configure the hosting controller to ignore safe areas and position at the notch
        hostingController.view.backgroundColor = UIColor.clear

        // Important: Don't use auto layout constraints for this view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true

        // Size the hosting controller to match the screen width
        let screenWidth = UIScreen.main.bounds.width
        let visualizerWidth = min(screenWidth, 400) // Limit width
        hostingController.view.frame = CGRect(x: 0, y: 0, width: visualizerWidth, height: 80)

        // Add the hosting controller as a child
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Store the hosting controller for later reference
        audioVisualizerHostingController = hostingController

        // Ensure proper z-order (visualizer stays on top)
        ensureVisualizerOnTop()

        // Add observer for orientation changes
        #if os(iOS)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        #endif
        DLOG("Audio visualizer set up successfully")
    }

    /// Remove the audio visualizer
    @objc public func removeAudioVisualizer() {
        guard let hostingController = audioVisualizerHostingController else {
            return
        }

#if os(iOS)
        // Remove orientation change observer
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
#endif

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
        if core.coreIdentifier?.contains("libretro") == true,
           let objcCore = core as? (any ObjCBridgedCore),
           let provider = objcCore.bridge as? (any EmulatorCoreWaveformProvider) {
            provider.installWaveformTap()
        }
        setupAudioVisualizer()
        // Ensure it's on top after showing
        ensureVisualizerOnTop()
    }

    /// Hide the audio visualizer
    @objc public func hideAudioVisualizer() {
        if core.coreIdentifier?.contains("libretro") == true,
           let objcCore = core as? (any ObjCBridgedCore),
           let provider = objcCore.bridge as? (any EmulatorCoreWaveformProvider) {
            provider.removeWaveformTap()
        }
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
                // Ensure it's on top
                ensureVisualizerOnTop()
            }
        }
    }

    /// Handle orientation changes
    @objc private func orientationDidChange() {
        // The SwiftUI visualizer will automatically reposition itself
        // using the DynamicIslandPositioner

        // Just update the frame size to match the current screen width
        if let hostingController = audioVisualizerHostingController {
            let screenWidth = UIScreen.main.bounds.width
            let visualizerWidth = min(screenWidth, 400) // Limit width
            hostingController.view.frame = CGRect(x: 0, y: 0, width: visualizerWidth, height: 80)

            // Ensure visualizer stays on top after rotation
            ensureVisualizerOnTop()

            // Force layout update
            view.layoutIfNeeded()
        }
    }

    /// Ensure the visualizer stays on top of all other views
    internal func ensureVisualizerOnTop() {
        if let hostingController = audioVisualizerHostingController {
            // First, make sure the view is in the view hierarchy
            if hostingController.view.superview == nil {
                view.addSubview(hostingController.view)
            }

            // Then bring it to the front
            view.bringSubviewToFront(hostingController.view)

            // Make sure it's visible
            hostingController.view.isHidden = false
            hostingController.view.alpha = 1.0

            DLOG("Ensured visualizer is on top")
        }
    }

    /// Set up constraints for the visualizer based on current orientation
    private func setupVisualizerConstraints(for hostingController: UIHostingController<AnyView>) {
        // Remove existing constraints from the hosting controller's view
        hostingController.view.constraints.forEach { constraint in
            if constraint.firstItem === hostingController.view {
                hostingController.view.removeConstraint(constraint)
            }
        }

        // Deactivate any constraints where the hosting controller's view is the second item
        NSLayoutConstraint.deactivate(view.constraints.filter { $0.secondItem === hostingController.view })

        // Get screen dimensions
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let visualizerWidth = min(screenWidth * 0.8, 300) // Limit width

        // Get the actual notch/Dynamic Island position
        let notchFrame = DynamicIslandPositioner.getDynamicIslandFrame()

        // Determine current orientation
#if os(iOS)
        let orientation = UIDevice.current.orientation

        switch orientation {
        case .portrait, .unknown, .faceUp, .faceDown:
            // Portrait mode - align exactly with the notch
            NSLayoutConstraint.activate([
                hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: notchFrame.minY),
                hostingController.view.widthAnchor.constraint(equalToConstant: visualizerWidth),
                hostingController.view.heightAnchor.constraint(equalToConstant: 60)
            ])

        case .landscapeLeft:
            // Landscape left - visualizer on right side aligned with notch
            NSLayoutConstraint.activate([
                hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
                hostingController.view.widthAnchor.constraint(equalToConstant: 60),
                hostingController.view.heightAnchor.constraint(equalToConstant: visualizerWidth)
            ])

        case .landscapeRight:
            // Landscape right - visualizer on left side aligned with notch
            NSLayoutConstraint.activate([
                hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
                hostingController.view.widthAnchor.constraint(equalToConstant: 60),
                hostingController.view.heightAnchor.constraint(equalToConstant: visualizerWidth)
            ])

        case .portraitUpsideDown:
            // Portrait upside down - visualizer at bottom
            NSLayoutConstraint.activate([
                hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
                hostingController.view.widthAnchor.constraint(equalToConstant: visualizerWidth),
                hostingController.view.heightAnchor.constraint(equalToConstant: 60)
            ])

        @unknown default:
            // Default to portrait mode aligned with notch
            NSLayoutConstraint.activate([
                hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: notchFrame.minY),
                hostingController.view.widthAnchor.constraint(equalToConstant: visualizerWidth),
                hostingController.view.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
        #else // not ios
        // Default to portrait mode aligned with notch
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: notchFrame.minY),
            hostingController.view.widthAnchor.constraint(equalToConstant: visualizerWidth),
            hostingController.view.heightAnchor.constraint(equalToConstant: 60)
        ])
        #endif
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
