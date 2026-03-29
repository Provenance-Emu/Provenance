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
import PVPrimitives
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
import PVLogging
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

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

    /// Per-system haptic tuning profile. Defaults to `.generic` until a core sets it.
    private var systemProfile: RumbleSystemProfile = .generic

    /// The system identifier of the currently active emulation session, used to
    /// re-apply adaptive trigger profiles when the `dualSenseAdaptiveTriggersEnabled`
    /// setting changes at runtime.
    private var currentSystemIdentifier: String?

    /// Tracks when each player's rumble burst started (monotonic uptime, for duration measurement).
    private var rumbleStartTimes: [Int: TimeInterval] = [:]

    /// Tracks how many on/off pulse cycles each player has had in the current window.
    private var playerPulseCounts: [Int: Int] = [:]

    /// Tracks the start of each player's pulse counting window (monotonic uptime).
    private var playerPulseWindowStart: [Int: TimeInterval] = [:]

    /// Stores the intensity used in the most recent rumble call per player (used for fallback haptic on stop).
    private var playerLastFallbackIntensity: [Int: CGFloat] = [:]

    /// Cached haptic intensity multiplier, updated when UserDefaults changes.
    /// Avoids reading UserDefaults on every rumble call.
    private var _cachedIntensityMultiplier: Float = 1.0

    /// Global haptic intensity multiplier driven by `hapticFeedback` and
    /// `controllerHapticIntensity` UserDefaults keys (written by PVSettings).
    public var intensityMultiplier: Float { _cachedIntensityMultiplier }

    /// Set a per-system haptic profile that tunes motor scaling and sharpness.
    public func setSystemProfile(_ profile: RumbleSystemProfile) {
        systemProfile = profile
    }

    /// Convenience: look up the best-matching profile for a Provenance system identifier and apply it.
    ///
    /// Checks `UserDefaults` for a user override first (written by `RumbleProfilesView`):
    /// - `rumbleSystemOverrides[sysId]` — UUID string of a custom preset, or `"builtin:<name>"`
    /// - If the stored value is a UUID, look up the matching blob in `rumbleCustomPresets`
    /// Falls back to the default `RumbleSystemProfile.profile(forSystemIdentifier:)` if no
    /// override is set or the stored data cannot be decoded.
    ///
    /// Also applies the appropriate DualSense adaptive trigger profile for the system
    /// if `dualSenseAdaptiveTriggersEnabled` is true, and updates the light bar color
    /// via `ControllerLightBarManager`.
    public func setSystemProfile(forSystemIdentifier sysId: String) {
        currentSystemIdentifier = sysId
        systemProfile = effectiveProfile(forSystemIdentifier: sysId)
        if #available(iOS 14.5, tvOS 14.5, *) {
            applyAdaptiveTriggers()
        }
        if #available(iOS 14.0, tvOS 14.0, *) {
            ControllerLightBarManager.shared.setSystemColor(forSystemIdentifier: sysId)
        }
    }

    /// Resolve the effective `RumbleSystemProfile` for a system identifier,
    /// honouring any user override stored in `UserDefaults`.
    ///
    /// Resolution order:
    /// 1. Controller-type override from `rumbleControllerOverrides` (based on connected controller type)
    /// 2. Per-system override from `rumbleSystemOverrides`
    /// 3. Built-in default from `RumbleSystemProfile.profile(forSystemIdentifier:)`
    public func effectiveProfile(forSystemIdentifier sysId: String) -> RumbleSystemProfile {
        // 1) Controller-type override (per connected game controller)
        if let controllerTypeKey = currentControllerTypeKey() {
            let controllerOverrides = UserDefaults.standard.dictionary(forKey: "rumbleControllerOverrides") as? [String: String] ?? [:]
            if let overrideValue = controllerOverrides[controllerTypeKey],
               let profile = resolveStoredProfileValue(overrideValue) {
                return profile
            }
        }

        // 2) Per-system override
        let systemOverrides = UserDefaults.standard.dictionary(forKey: "rumbleSystemOverrides") as? [String: String] ?? [:]
        if let overrideValue = systemOverrides[sysId],
           let profile = resolveStoredProfileValue(overrideValue) {
            return profile
        }

        // 3) Fallback to the built-in default profile
        return RumbleSystemProfile.profile(forSystemIdentifier: sysId)
    }

    /// Derive the current controller-type key used for controller-specific overrides.
    /// Prefers the controller mapped to player index 0, then any mapped controller,
    /// and finally falls back to `GCController.controllers.first` if needed.
    private func currentControllerTypeKey() -> String? {
        if let controller = playerControllers[0],
           let key = controllerTypeKey(for: controller) {
            return key
        }

        if let anyController = playerControllers.values.first,
           let key = controllerTypeKey(for: anyController) {
            return key
        }

        if let globalController = GCController.controllers().first,
           let key = controllerTypeKey(for: globalController) {
            return key
        }

        return nil
    }

    /// Compute a stable string key for a given `GCController` to use with
    /// `rumbleControllerOverrides`. Uses `productCategory` when available,
    /// falling back to `vendorName` if necessary.
    private func controllerTypeKey(for controller: GCController) -> String? {
        let category = controller.productCategory
        if !category.isEmpty {
            return category
        }
        if let vendor = controller.vendorName, !vendor.isEmpty {
            return vendor
        }
        return nil
    }

    /// Resolve a stored override value (UUID string or "builtin:<name>") to a `RumbleSystemProfile`.
    private func resolveStoredProfileValue(_ value: String) -> RumbleSystemProfile? {
        if value.hasPrefix("builtin:") {
            let name = String(value.dropFirst("builtin:".count))
            return builtInProfile(forName: name)
        }
        // Try UUID lookup in rumbleCustomPresets (stored as [Data] JSON blobs in PVSettings)
        guard let presetBlobs = UserDefaults.standard.array(forKey: "rumbleCustomPresets") as? [Data] else {
            return nil
        }
        for data in presetBlobs {
            guard let preset = try? JSONDecoder().decode(RumblePreset.self, from: data),
                  preset.id.uuidString == value else { continue }
            return preset.toSystemProfile()
        }
        return nil
    }

    /// Match a built-in preset name to the corresponding `RumbleSystemProfile`.
    private func builtInProfile(forName name: String) -> RumbleSystemProfile? {
        switch name {
        case "Generic":              return .generic
        case "N64 Rumble Pak":       return .n64RumblePak
        case "PSX DualShock":        return .psxDualShock
        case "PS3 DualShock 3":      return .ps3DualShock3
        case "GBA Cartridge Motor":  return .gbaCartridgeMotor
        case "GameCube":             return .gamecubeSingle
        case "Switch HD Rumble":     return .switchHDRumble
        case "Xbox Dual Motor":      return .xboxDualMotor
        default:                     return nil
        }
    }

    /// Reset the system profile back to `.generic`.
    /// Call this when an emulation session ends so the next core starts with neutral tuning.
    /// Also turns off adaptive triggers and resets the light bar on any connected controllers.
    public func resetSystemProfile() {
        systemProfile = .generic
        currentSystemIdentifier = nil
        if #available(iOS 14.5, tvOS 14.5, *) {
            for controller in playerControllers.values {
                configureDualSenseAdaptiveTriggers(controller: controller, profile: .off)
            }
        }
        if #available(iOS 14.0, tvOS 14.0, *) {
            ControllerLightBarManager.shared.resetSystemColor()
        }
    }

    private func refreshIntensityCache() {
        // Gate controller rumble on the dedicated Tier 4 toggles only.
        // `hapticFeedback` controls on-screen button feedback and must not silence game rumble.
        let rumbleEnabled = UserDefaults.standard.object(forKey: "rumbleEnabled") as? Bool ?? true
        let controllerEnabled = UserDefaults.standard.object(forKey: "rumbleControllerEnabled") as? Bool ?? true
        guard rumbleEnabled && controllerEnabled else {
            _cachedIntensityMultiplier = 0
            return
        }
        let stored = UserDefaults.standard.object(forKey: "controllerHapticIntensity") as? Double ?? 1.0
        _cachedIntensityMultiplier = Float(max(0.0, min(1.0, stored)))
    }

    /// Applies (or removes) DualSense adaptive trigger feedback on all registered controllers
    /// based on the current `dualSenseAdaptiveTriggersEnabled` UserDefaults setting and the
    /// active system identifier.
    ///
    /// Call whenever the setting changes or a new system profile is loaded.
    @available(iOS 14.5, tvOS 14.5, *)
    private func applyAdaptiveTriggers() {
        let enabled = UserDefaults.standard.object(forKey: "dualSenseAdaptiveTriggersEnabled") as? Bool ?? true
        let profile: AdaptiveTriggerProfile
        if enabled, let sysId = currentSystemIdentifier {
            profile = adaptiveTriggerProfile(forSystemIdentifier: sysId)
        } else {
            profile = .off
        }
        for controller in playerControllers.values {
            configureDualSenseAdaptiveTriggers(controller: controller, profile: profile)
        }
    }

    /// Map a Provenance system identifier to the best DualSense adaptive trigger profile.
    ///
    /// PlayStation systems with analog L2/R2 triggers get a `.soft` feedback profile
    /// so the physical resistance complements the original controller experience.
    /// All other systems default to `.off` (standard spring feel).
    @available(iOS 14.5, tvOS 14.5, *)
    private func adaptiveTriggerProfile(forSystemIdentifier sysId: String) -> AdaptiveTriggerProfile {
        let id = sysId.lowercased()
        // PlayStation systems have analog L2/R2; soft resistance enhances immersion.
        if id.contains("psx") || id.contains("ps1") || id.contains("ps2")
            || id.contains("ps3") || id.contains("playstation") {
            return .soft
        }
        return .off
    }

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    private init() {
        refreshIntensityCache()
        registerNotifications()
    }

    private func registerNotifications() {
        let nc = NotificationCenter.default

        let connectObs = nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let gc = note.object as? GCController else { return }
            /// Safe: delivered on queue: .main which is the MainActor executor.
            nonisolated(unsafe) let controller = gc
            MainActor.assumeIsolated { self?.controllerConnected(controller) }
        }

        let disconnectObs = nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let gc = note.object as? GCController else { return }
            /// Safe: delivered on queue: .main which is the MainActor executor.
            nonisolated(unsafe) let controller = gc
            MainActor.assumeIsolated { self?.controllerDisconnected(controller) }
        }

        // Stop engines when the app moves to background; restart on foreground.
        // Note: CHHapticEngine.resetHandler only fires on external server resets,
        // not after a manual .stop(). We must restart engines explicitly on foreground.
        #if canImport(UIKit) && !os(watchOS)
        let bgObs = nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAllEngines() }
        }
        notificationObservers.append(bgObs)

        let fgObs = nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restartAllEngines() }
        }
        notificationObservers.append(fgObs)
        #endif

        // Keep intensity cache and adaptive trigger state in sync with UserDefaults changes.
        let udObs = nc.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIntensityCache()
                if #available(iOS 14.5, tvOS 14.5, *) {
                    self?.applyAdaptiveTriggers()
                }
            }
        }
        notificationObservers.append(udObs)

        notificationObservers.append(connectObs)
        notificationObservers.append(disconnectObs)
    }

    // MARK: - Player → Controller Registration

    /// How `register(controller:forPlayer:effect:)` updates non-haptic subsystems.
    public enum RegistrationEffect: Sendable {
        /// Haptic engines plus adaptive triggers and `ControllerLightBarManager` (normal gameplay).
        case fullSync
        /// Haptic engines only — skips light bar and adaptive-trigger updates (e.g. settings test rumble).
        case hapticsEnginesOnly
    }

    /// Register a GCController for a player slot (0-based index).
    /// - Parameters:
    ///   - effect: Use `.hapticsEnginesOnly` when you must avoid light bar / adaptive-trigger side effects.
    public func register(controller: GCController?, forPlayer player: Int, effect: RegistrationEffect = .fullSync) {
        if let old = playerControllers[player] {
            // Clean up old engines if controller changed.
            if old !== controller {
                removeEngines(forPlayer: player)
            }
        }

        guard let controller = controller else {
            playerControllers.removeValue(forKey: player)
            if effect == .fullSync {
                if #available(iOS 14.0, tvOS 14.0, *) {
                    ControllerLightBarManager.shared.register(controller: nil, forPlayer: player)
                }
            }
            return
        }

        playerControllers[player] = controller
        buildEngines(forPlayer: player, controller: controller)

        guard effect == .fullSync else { return }

        // Apply adaptive triggers to a newly registered DualSense if a system is active.
        if #available(iOS 14.5, tvOS 14.5, *) {
            applyAdaptiveTriggers()
        }

        // Keep light bar manager in sync with the same player-controller map.
        if #available(iOS 14.0, tvOS 14.0, *) {
            ControllerLightBarManager.shared.register(controller: controller, forPlayer: player)
        }
    }

    // MARK: - Rumble API

    /// Fire a dual-motor rumble on the controller for the given player.
    /// Falls back to the device Taptic Engine if the controller has no haptics support.
    ///
    /// - Parameters:
    ///   - player: 0-based player index.
    ///   - params: Intensity and duration parameters.
    public func rumble(player: Int, params: RumbleParams = .init()) {
        // Track burst timing: record start time on the leading edge of a new burst.
        // Use monotonic uptime so classification isn't affected by wall-clock adjustments (NTP, DST).
        let now = ProcessInfo.processInfo.systemUptime
        let isNewBurst = rumbleStartTimes[player] == nil
        if isNewBurst {
            rumbleStartTimes[player] = now
        }

        // Update pulse counting window: only count on/off transitions (new bursts),
        // not on every continuous frame-driven rumble call, to avoid every burst
        // being classified as .rapidPulse.
        if isNewBurst {
            if let windowStart = playerPulseWindowStart[player] {
                let windowElapsed = now - windowStart
                if windowElapsed > 0.5 {
                    // More than 500 ms since first pulse — start a fresh window.
                    playerPulseCounts[player] = 1
                    playerPulseWindowStart[player] = now
                } else {
                    playerPulseCounts[player] = (playerPulseCounts[player] ?? 0) + 1
                }
            } else {
                // First burst ever for this player — initialise the window.
                playerPulseCounts[player] = 1
                playerPulseWindowStart[player] = now
            }
        }

        // Apply system profile scaling to params.
        let scaledLow = params.lowFrequency * systemProfile.lowFrequencyScale
        let scaledHigh = params.highFrequency * systemProfile.highFrequencyScale
        // Use the caller-provided duration; callers that want continuous-until-stop
        // (e.g. libretro rumble helper) pass a large value such as 10.0 seconds.
        let continuousDuration = params.duration

        guard let controller = playerControllers[player] else {
            VLOG("[GCHaptics] No controller registered for player \(player + 1) — falling back to Taptic Engine")
            #if canImport(UIKit) && os(iOS) && !targetEnvironment(macCatalyst)
            // Store the intensity so stopRumble can fire a single, correctly-styled haptic.
            let baseIntensity = max(0, min(1, _cachedIntensityMultiplier))
            let paramsMax = max(scaledLow, scaledHigh)
            let paramsScale = max(0, min(1, paramsMax))
            let intensity = CGFloat(baseIntensity * paramsScale)
            if intensity > 0 {
                playerLastFallbackIntensity[player] = intensity
            }
            #endif
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
                                leftIntensity: scaledLow * intensity,
                                rightIntensity: scaledHigh * intensity,
                                duration: continuousDuration,
                                sharpness: systemProfile.sharpness)
        case .xbox:
            playXboxRumble(player: player, controller: controller,
                           leftIntensity: scaledLow * intensity,
                           rightIntensity: scaledHigh * intensity,
                           duration: continuousDuration,
                           sharpness: systemProfile.sharpness)
        case .switchPro, .joycon:
            playSwitchRumble(player: player, controller: controller,
                             intensity: max(scaledLow, scaledHigh) * intensity,
                             duration: continuousDuration,
                             sharpness: systemProfile.sharpness)
        case .unknown:
            playDefaultRumble(player: player, controller: controller,
                              intensity: max(scaledLow, scaledHigh) * intensity,
                              duration: continuousDuration,
                              sharpness: systemProfile.sharpness)
        }

        // For finite one-shot rumbles that don't call stopRumble(), the CHHapticEngine
        // stops automatically after `duration` seconds — but rumbleStartTimes[player]
        // would remain set indefinitely, causing the next burst to be misclassified.
        // Schedule a cleanup task so stale tracking state is cleared after the haptic expires.
        // Continuous-until-stop callers (duration ≥ 5.0) rely on stopRumble() to clean up.
        if continuousDuration < 5.0 && isNewBurst {
            let capturedPlayer = player
            let clearAfter = continuousDuration + 0.1
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(clearAfter * 1_000_000_000))
                self?.rumbleStartTimes.removeValue(forKey: capturedPlayer)
            }
        }
    }

    /// Stops any active rumble playback for the registered controller engines of `player`.
    ///
    /// The controller registration is preserved so future rumble events can restart
    /// the same engines without requiring the emulator core to re-register them.
    public func stopRumble(player: Int) {
        // Measure burst duration and classify the pattern.
        // Use monotonic uptime to match the timestamps recorded in rumble().
        let now = ProcessInfo.processInfo.systemUptime
        let burstDuration: TimeInterval
        if let startTime = rumbleStartTimes[player] {
            burstDuration = now - startTime
        } else {
            burstDuration = 0
        }

        let pulseCount = playerPulseCounts[player] ?? 1
        let windowStart = playerPulseWindowStart[player] ?? now
        let windowDuration = now - windowStart

        let pattern = RumbleBurstClassifier.classify(
            duration: burstDuration,
            pulseCount: pulseCount,
            windowDuration: windowDuration
        )
        VLOG("[GCHaptics] Burst classified as .\(pattern) for player \(player + 1) (duration: \(String(format: "%.3f", burstDuration))s, pulses: \(pulseCount))")

        // Clear tracking state for this player.
        rumbleStartTimes.removeValue(forKey: player)

        // Drain the stored fallback intensity unconditionally — regardless of whether a
        // controller is now connected. If a controller connected *between* rumble() and
        // stopRumble(), the stored intensity must be discarded so it can't fire spuriously
        // in a future fallback-path call.
        #if canImport(UIKit) && os(iOS) && !targetEnvironment(macCatalyst)
        let fallbackIntensity = playerLastFallbackIntensity.removeValue(forKey: player)
        #else
        playerLastFallbackIntensity.removeValue(forKey: player)
        #endif

        guard let engines = engineMap[player], !engines.isEmpty else {
            // No controller engines — fire a single device fallback haptic whose style is
            // derived from the classified pattern and whose intensity came from rumble().
            #if canImport(UIKit) && os(iOS) && !targetEnvironment(macCatalyst)
            let style = hapticStyleForPattern(pattern)
            // Only fire if a positive intensity was stored by rumble() — if haptics were disabled,
            // no value was stored and we must not fire here.
            guard let intensity = fallbackIntensity, intensity > 0 else { return }
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred(intensity: intensity)
            #endif
            return
        }

        for (_, engine) in engines {
            engine.stop(completionHandler: nil)
        }
        VLOG("[GCHaptics] Stopped rumble for player \(player + 1)")
    }

    /// Map a classified `RumblePattern` to a `UIImpactFeedbackGenerator.FeedbackStyle`.
    #if canImport(UIKit) && os(iOS) && !targetEnvironment(macCatalyst)
    private func hapticStyleForPattern(_ pattern: RumblePattern) -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch pattern {
        case .shortTransient:
            return .light
        case .mediumBurst:
            return .medium
        case .longSustained:
            return .heavy
        case .rapidPulse:
            return .rigid
        }
    }
    #endif

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

        engine.resetHandler = { [weak engine] in
            ILOG("[GCHaptics] Engine reset — restarting")
            try? engine?.start()
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

    private func restartAllEngines() {
        for (player, localityMap) in engineMap {
            for (locality, engine) in localityMap {
                do {
                    try engine.start()
                    VLOG("[GCHaptics] Engine restarted for player \(player + 1), locality \(locality)")
                } catch {
                    ELOG("[GCHaptics] Failed to restart engine for player \(player + 1), locality \(locality): \(error)")
                }
            }
        }
        VLOG("[GCHaptics] All engines restarted (app foregrounded)")
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
        if controller.physicalInputProfile is GCXboxGamepad { return .xbox }

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
                                     duration: TimeInterval, sharpness: Float = 0.4) {
        let engines = engineMap[player] ?? [:]

        // Left handle = low-frequency (grip) motor — use lower sharpness for the heavy motor.
        let leftSharpness = max(0, sharpness - 0.2)
        if let leftEngine = engines[.leftHandle] ?? engines[.default] {
            playEvent(engine: leftEngine, intensity: leftIntensity, sharpness: leftSharpness, duration: duration)
        }

        // Right handle = high-frequency motor, only played when a separate left-handle engine
        // exists — ensures we use per-motor engines rather than falling back to the shared default.
        // Use slightly higher sharpness for the high-frequency motor.
        let rightSharpness = min(1, sharpness + 0.2)
        if let rightEngine = engines[.rightHandle], engines[.leftHandle] != nil {
            playEvent(engine: rightEngine, intensity: rightIntensity, sharpness: rightSharpness, duration: duration)
        }
    }

    private func playXboxRumble(player: Int, controller: GCController,
                                leftIntensity: Float, rightIntensity: Float,
                                duration: TimeInterval, sharpness: Float = 0.4) {
        let engines = engineMap[player] ?? [:]

        if let leftEngine = engines[.leftHandle] ?? engines[.default] {
            playEvent(engine: leftEngine, intensity: leftIntensity, sharpness: max(0, sharpness - 0.2), duration: duration)
        }
        if let rightEngine = engines[.rightHandle] {
            playEvent(engine: rightEngine, intensity: rightIntensity, sharpness: min(1, sharpness + 0.2), duration: duration)
        }
        // Trigger motors — proportional to the high-frequency component.
        if let leftTrigger = engines[.leftTrigger] {
            playEvent(engine: leftTrigger, intensity: rightIntensity * 0.5, sharpness: min(1, sharpness + 0.4), duration: duration)
        }
        if let rightTrigger = engines[.rightTrigger] {
            playEvent(engine: rightTrigger, intensity: rightIntensity * 0.5, sharpness: min(1, sharpness + 0.5), duration: duration)
        }
    }

    private func playSwitchRumble(player: Int, controller: GCController,
                                  intensity: Float, duration: TimeInterval, sharpness: Float = 0.5) {
        guard let engine = engineMap[player]?[.default] else { return }
        // Switch HD Rumble LRA responds well to profile-derived sharpness.
        playEvent(engine: engine, intensity: intensity, sharpness: sharpness, duration: duration)
    }

    private func playDefaultRumble(player: Int, controller: GCController,
                                   intensity: Float, duration: TimeInterval, sharpness: Float = 0.5) {
        guard let engine = engineMap[player]?[.default] else { return }
        playEvent(engine: engine, intensity: intensity, sharpness: sharpness, duration: duration)
    }

    private func playEvent(engine: CHHapticEngine, intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard intensity > 0 else { return }

        do {
            try engine.start()

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
