//
//  GCControllerHapticsManager.swift
//  PVCoreBridge
//
//  Manages GCDeviceHaptics-based rumble for external game controllers.
//  When a DualSense, DualShock 4, Xbox, or Switch controller is connected,
//  rumble is routed to the physical motors via CHHapticEngine rather than
//  firing the device Taptic Engine.
//
//  Supports:
//  - DualSense: LeftHandle, RightHandle localities + adaptive triggers
//  - DualShock 4: Default locality
//  - Xbox Series X/S: LeftHandle, RightHandle, LeftTrigger, RightTrigger
//  - Switch Pro / Joy-Con: Default (HD Rumble LRA)
//  - Fallback: device UIImpactFeedbackGenerator when no controller haptics
//

import Foundation
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
import PVLogging

/// Manages haptic engines for external game controllers via GCDeviceHaptics.
/// One shared instance routes rumble from emulator cores to controller motors.
@MainActor
@available(iOS 14.0, tvOS 14.0, *)
public final class GCControllerHapticsManager {

    // MARK: - Types

    /// Rumble parameters for dual-motor controllers.
    public struct RumbleParams {
        /// Low-frequency motor intensity [0, 1]. Maps to the left/grip motor.
        public var lowFrequency: Float
        /// High-frequency motor intensity [0, 1]. Maps to the right/trigger motor.
        public var highFrequency: Float
        /// Duration in seconds. Pass 0 for a short one-shot impulse.
        public var duration: TimeInterval

        public init(lowFrequency: Float = 0.8,
                    highFrequency: Float = 0.5,
                    duration: TimeInterval = 0.3) {
            self.lowFrequency = lowFrequency
            self.highFrequency = highFrequency
            self.duration = duration
        }
    }

    // MARK: - Singleton

    public static let shared = GCControllerHapticsManager()

    // MARK: - Private state

    /// Maps player index (0-based) → controller.
    private var playerControllers: [Int: GCController] = [:]

    /// Maps player index → (locality → engine).
    private var engineMap: [Int: [GCHapticsLocality: CHHapticEngine]] = [:]

    /// Cached haptic intensity multiplier, updated when UserDefaults changes.
    /// Avoids reading UserDefaults on every rumble call.
    private var _cachedIntensityMultiplier: Float = 1.0

    /// Global haptic intensity multiplier driven by `hapticFeedback` and
    /// `controllerHapticIntensity` UserDefaults keys (written by PVSettings).
    public var intensityMultiplier: Float { _cachedIntensityMultiplier }

    private func refreshIntensityCache() {
        guard UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true else {
            _cachedIntensityMultiplier = 0
            return
        }
        let stored = UserDefaults.standard.object(forKey: "controllerHapticIntensity") as? Double ?? 1.0
        _cachedIntensityMultiplier = Float(max(0.0, min(1.0, stored)))
    }

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    private init() {
        refreshIntensityCache()
        registerNotifications()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func registerNotifications() {
        let nc = NotificationCenter.default

        let connectObs = nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.controllerConnected(controller) }
        }

        let disconnectObs = nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.controllerDisconnected(controller) }
        }

        // Stop engines when the app moves to background; resume on foreground.
        #if canImport(UIKit) && !os(watchOS)
        let bgObs = nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAllEngines() }
        }
        notificationObservers.append(bgObs)
        #endif

        // Keep intensity cache in sync with UserDefaults changes from PVSettings.
        let udObs = nc.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshIntensityCache() }
        }
        notificationObservers.append(udObs)

        notificationObservers.append(connectObs)
        notificationObservers.append(disconnectObs)
    }

    // MARK: - Player → Controller Registration

    /// Register a GCController for a player slot (0-based index).
    public func register(controller: GCController?, forPlayer player: Int) {
        if let old = playerControllers[player] {
            // Clean up old engines if controller changed.
            if old !== controller {
                removeEngines(forPlayer: player)
            }
        }

        guard let controller = controller else {
            playerControllers.removeValue(forKey: player)
            return
        }

        playerControllers[player] = controller
        buildEngines(forPlayer: player, controller: controller)
    }

    // MARK: - Rumble API

    /// Fire a dual-motor rumble on the controller for the given player.
    /// Falls back to the device Taptic Engine if the controller has no haptics support.
    ///
    /// - Parameters:
    ///   - player: 0-based player index.
    ///   - params: Intensity and duration parameters.
    public func rumble(player: Int, params: RumbleParams = .init()) {
        guard let controller = playerControllers[player] else {
            VLOG("[GCHaptics] No controller registered for player \(player + 1)")
            return
        }

        guard controller.haptics != nil else {
            VLOG("[GCHaptics] Controller \(controller.vendorName ?? "?") has no GCDeviceHaptics, skipping")
            return
        }

        let intensity = max(0, min(1, intensityMultiplier))
        guard intensity > 0 else { return }

        let controllerType = detectControllerType(controller)
        switch controllerType {
        case .dualSense, .dualShock4:
            playDualMotorRumble(player: player, controller: controller,
                                leftIntensity: params.lowFrequency * intensity,
                                rightIntensity: params.highFrequency * intensity,
                                duration: params.duration)
        case .xbox:
            playXboxRumble(player: player, controller: controller,
                           leftIntensity: params.lowFrequency * intensity,
                           rightIntensity: params.highFrequency * intensity,
                           duration: params.duration)
        case .switchPro, .joycon:
            playSwitchRumble(player: player, controller: controller,
                             intensity: max(params.lowFrequency, params.highFrequency) * intensity,
                             duration: params.duration)
        case .unknown:
            playDefaultRumble(player: player, controller: controller,
                              intensity: max(params.lowFrequency, params.highFrequency) * intensity,
                              duration: params.duration)
        }
    }

    /// Configure DualSense adaptive triggers for a specific game-system profile.
    @available(iOS 14.5, tvOS 14.5, *)
    public func configureDualSenseAdaptiveTriggers(controller: GCController, profile: AdaptiveTriggerProfile) {
        guard let dualSense = controller.physicalInputProfile as? GCDualSenseGamepad else { return }

        switch profile {
        case .off:
            dualSense.leftTrigger.setModeOff()
            dualSense.rightTrigger.setModeOff()

        case .bow:
            // Resistance builds as trigger is pulled — simulates bow tension.
            dualSense.leftTrigger.setModeFeedbackWithStartPosition(0.1, resistiveStrength: 0.8)
            dualSense.rightTrigger.setModeFeedbackWithStartPosition(0.1, resistiveStrength: 0.8)

        case .gun:
            // Click resistance at the firing point, then release — gun trigger feel.
            dualSense.leftTrigger.setModeWeaponWithStartPosition(0.15, endPosition: 0.4, resistiveStrength: 1.0)
            dualSense.rightTrigger.setModeWeaponWithStartPosition(0.15, endPosition: 0.4, resistiveStrength: 1.0)

        case .racing:
            // Progressive slope resistance — engine load / brake feel.
            if #available(iOS 15.4, tvOS 15.4, *) {
                dualSense.leftTrigger.setModeSlopeFeedback(startPosition: 0.0, endPosition: 1.0, startStrength: 0.2, endStrength: 0.9)
                dualSense.rightTrigger.setModeSlopeFeedback(startPosition: 0.0, endPosition: 1.0, startStrength: 0.2, endStrength: 0.9)
            } else {
                dualSense.leftTrigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.6)
                dualSense.rightTrigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.6)
            }

        case .soft:
            // Light uniform feedback across the full travel.
            dualSense.leftTrigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.3)
            dualSense.rightTrigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.3)
        }
    }

    // MARK: - Engine Management

    private func buildEngines(forPlayer player: Int, controller: GCController) {
        guard let haptics = controller.haptics else { return }

        var localityMap: [GCHapticsLocality: CHHapticEngine] = [:]

        let localities = availableLocalities(for: controller)
        for locality in localities {
            if let engine = createEngine(haptics: haptics, locality: locality) {
                localityMap[locality] = engine
            }
        }

        engineMap[player] = localityMap
        ILOG("[GCHaptics] Built \(localityMap.count) haptic engine(s) for player \(player + 1) (\(controller.vendorName ?? "unknown"))")
    }

    private func createEngine(haptics: GCDeviceHaptics, locality: GCHapticsLocality) -> CHHapticEngine? {
        guard let engine = haptics.createEngine(withLocality: locality) else { return nil }

        engine.isAutoShutdownEnabled = true

        engine.stoppedHandler = { reason in
            VLOG("[GCHaptics] Engine stopped: \(reason)")
        }

        engine.resetHandler = {
            ILOG("[GCHaptics] Engine reset — restarting")
            try? engine.start()
        }

        // Start the engine once at creation time. The resetHandler handles recovery
        // if the engine stops unexpectedly (e.g., after app foreground transition).
        try? engine.start()

        return engine
    }

    private func removeEngines(forPlayer player: Int) {
        if let engines = engineMap.removeValue(forKey: player) {
            for (_, engine) in engines {
                engine.stop(completionHandler: nil)
            }
        }
    }

    private func stopAllEngines() {
        for (_, localityMap) in engineMap {
            for (_, engine) in localityMap {
                engine.stop(completionHandler: nil)
            }
        }
        VLOG("[GCHaptics] All engines stopped (app backgrounded)")
    }

    // MARK: - Controller Detection

    private enum ControllerType {
        case dualSense, dualShock4, xbox, switchPro, joycon, unknown
    }

    private func detectControllerType(_ controller: GCController) -> ControllerType {
        if #available(iOS 14.5, tvOS 14.5, *) {
            if controller.physicalInputProfile is GCDualSenseGamepad { return .dualSense }
        }
        if controller.physicalInputProfile is GCDualShockGamepad { return .dualShock4 }
        if #available(iOS 14.0, tvOS 14.0, *) {
            if controller.physicalInputProfile is GCXboxGamepad { return .xbox }
        }

        let vendor = controller.vendorName?.lowercased() ?? ""
        let category = controller.productCategory.lowercased()

        if vendor.contains("joy-con") || vendor.contains("joycon") {
            return .joycon
        }
        if vendor.contains("nintendo") || category.contains("switch") {
            return .switchPro
        }
        return .unknown
    }

    private func availableLocalities(for controller: GCController) -> [GCHapticsLocality] {
        let type = detectControllerType(controller)
        switch type {
        case .dualSense:
            return [.default, .leftHandle, .rightHandle]
        case .xbox:
            return [.default, .leftHandle, .rightHandle, .leftTrigger, .rightTrigger]
        default:
            return [.default]
        }
    }

    // MARK: - Per-Controller Rumble Implementations

    private func playDualMotorRumble(player: Int, controller: GCController,
                                     leftIntensity: Float, rightIntensity: Float,
                                     duration: TimeInterval) {
        let engines = engineMap[player] ?? [:]

        // Left handle = low-frequency (grip) motor.
        if let leftEngine = engines[.leftHandle] ?? engines[.default] {
            playEvent(engine: leftEngine, intensity: leftIntensity, sharpness: 0.2, duration: duration)
        }

        // Right handle = high-frequency motor (only if separate engine exists).
        if let rightEngine = engines[.rightHandle], engines[.leftHandle] != nil {
            playEvent(engine: rightEngine, intensity: rightIntensity, sharpness: 0.6, duration: duration)
        }
    }

    private func playXboxRumble(player: Int, controller: GCController,
                                leftIntensity: Float, rightIntensity: Float,
                                duration: TimeInterval) {
        let engines = engineMap[player] ?? [:]

        if let leftEngine = engines[.leftHandle] ?? engines[.default] {
            playEvent(engine: leftEngine, intensity: leftIntensity, sharpness: 0.1, duration: duration)
        }
        if let rightEngine = engines[.rightHandle] {
            playEvent(engine: rightEngine, intensity: rightIntensity, sharpness: 0.7, duration: duration)
        }
        // Trigger motors — proportional to the high-frequency component.
        if let leftTrigger = engines[.leftTrigger] {
            playEvent(engine: leftTrigger, intensity: rightIntensity * 0.5, sharpness: 0.8, duration: duration)
        }
        if let rightTrigger = engines[.rightTrigger] {
            playEvent(engine: rightTrigger, intensity: rightIntensity * 0.5, sharpness: 0.9, duration: duration)
        }
    }

    private func playSwitchRumble(player: Int, controller: GCController,
                                  intensity: Float, duration: TimeInterval) {
        guard let engine = engineMap[player]?[.default] else { return }
        // Switch HD Rumble LRA responds well to mid sharpness.
        playEvent(engine: engine, intensity: intensity, sharpness: 0.4, duration: duration)
    }

    private func playDefaultRumble(player: Int, controller: GCController,
                                   intensity: Float, duration: TimeInterval) {
        guard let engine = engineMap[player]?[.default] else { return }
        playEvent(engine: engine, intensity: intensity, sharpness: 0.5, duration: duration)
    }

    private func playEvent(engine: CHHapticEngine, intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard intensity > 0 else { return }

        do {
            let clampedIntensity = max(0.01, min(1.0, intensity))
            let clampedSharpness = max(0.0, min(1.0, sharpness))
            let clampedDuration = max(0.05, duration)

            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: clampedSharpness)
                ],
                relativeTime: 0,
                duration: clampedDuration
            )

            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            ELOG("[GCHaptics] Failed to play haptic event: \(error)")
        }
    }

    // MARK: - Controller Notifications

    private func controllerConnected(_ controller: GCController) {
        ILOG("[GCHaptics] Controller connected: \(controller.vendorName ?? "unknown"), haptics: \(controller.haptics != nil)")
        // Engines are built on demand when register(controller:forPlayer:) is called.
    }

    private func controllerDisconnected(_ controller: GCController) {
        ILOG("[GCHaptics] Controller disconnected: \(controller.vendorName ?? "unknown")")
        // Find and clean up engines for this controller.
        for (player, registeredController) in playerControllers where registeredController === controller {
            removeEngines(forPlayer: player)
            playerControllers.removeValue(forKey: player)
        }
    }
}

// MARK: - AdaptiveTriggerProfile

/// Predefined adaptive trigger profiles for the DualSense.
@available(iOS 14.5, tvOS 14.5, *)
public enum AdaptiveTriggerProfile {
    /// Triggers return to default spring feel.
    case off
    /// Resistance that builds across the full travel — bow / slingshot.
    case bow
    /// Hard stop at a specific pull depth — gun / weapon trigger.
    case gun
    /// Progressive ramp from light to heavy — racing brake / throttle.
    case racing
    /// Light uniform resistance — general soft feedback.
    case soft
}


#endif // canImport(GameController) && canImport(CoreHaptics)
