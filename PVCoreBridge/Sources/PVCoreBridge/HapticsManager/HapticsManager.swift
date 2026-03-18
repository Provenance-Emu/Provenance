//
//  HapticsManager.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation
import PVLogging
#if canImport(GameController) && canImport(CoreHaptics)
@preconcurrency import GameController
@preconcurrency import CoreHaptics

/// All access is confined to the main actor; `@unchecked Sendable` is safe
/// because `@MainActor` guarantees single-threaded access.
@MainActor
@available(iOS 14.0, tvOS 14.0, *)
internal final class HapticsManager: @unchecked Sendable {

    static let shared: HapticsManager = .init()

    // MARK: - Engine construction

    nonisolated private static func buildDeviceEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.isMutedForAudio = false
            engine.isMutedForHaptics = false
            engine.stoppedHandler = { reason in
                WLOG("HapticsManager device engine stopped: \(reason.rawValue)")
            }
            engine.resetHandler = {
                ILOG("HapticsManager device engine reset — restarting")
                try? engine.start()
            }
            return engine
        } catch {
            ELOG("HapticsManager: failed to create device engine: \(error)")
            return nil
        }
    }

    nonisolated private static func buildControllerEngine(for controller: GCController) -> CHHapticEngine? {
        guard let haptics = controller.haptics,
              let engine = haptics.createEngine(withLocality: GCHapticsLocality.default) else { return nil }
        engine.isAutoShutdownEnabled = true
        engine.stoppedHandler = { reason in
            WLOG("HapticsManager controller engine stopped: \(reason.rawValue)")
        }
        engine.resetHandler = {
            ILOG("HapticsManager controller engine reset — restarting")
            try? engine.start()
        }
        return engine
    }

    // MARK: - State

    /// Device Taptic Engines indexed by player (0-based). May be nil if device lacks haptics.
    private var deviceEngines: [Int: CHHapticEngine] = [:]
    /// External controller engines indexed by player (0-based).
    private var controllerEngines: [Int: CHHapticEngine] = [:]

    private init() {
        if let engine = HapticsManager.buildDeviceEngine() {
            deviceEngines[0] = engine
        }
        observeControllers()
    }

    // MARK: - Controller observation

    private func observeControllers() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let controller = note.object as? GCController else { return }
            let index = Int(controller.playerIndex.rawValue)
            guard index >= 0 else { return }
            if let engine = HapticsManager.buildControllerEngine(for: controller) {
                self.controllerEngines[index] = engine
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let controller = note.object as? GCController else { return }
            let index = Int(controller.playerIndex.rawValue)
            self.controllerEngines.removeValue(forKey: index)
        }
    }

    // MARK: - Public API

    /// Returns the device Taptic Engine for the given player index, creating it if needed.
    func hapticsEngine(forPlayer player: Int) -> CHHapticEngine? {
        if let existing = deviceEngines[player] { return existing }
        let engine = HapticsManager.buildDeviceEngine()
        deviceEngines[player] = engine
        return engine
    }

    /// Trigger a rumble event on the device Taptic Engine and any connected controller for `player`.
    /// Respects `rumbleEnabled`, `rumbleDeviceEnabled`, and `rumbleControllerEnabled` UserDefaults keys.
    /// - Parameters:
    ///   - lowFrequency:  0.0–1.0 intensity for low-frequency (heavy) motor.
    ///   - highFrequency: 0.0–1.0 intensity for high-frequency (light) motor.
    ///   - duration:      Duration in seconds.
    ///   - player:        0-based player index.
    func rumble(lowFrequency: Float, highFrequency: Float, duration: TimeInterval, player: Int = 0) {
        let rumbleEnabled = UserDefaults.standard.object(forKey: "rumbleEnabled") as? Bool ?? true
        guard rumbleEnabled else { return }

        let clampedLow  = min(max(lowFrequency, 0), 1)
        let clampedHigh = min(max(highFrequency, 0), 1)
        let clampedDuration = max(duration, 0.05)

        let deviceEnabled = UserDefaults.standard.object(forKey: "rumbleDeviceEnabled") as? Bool ?? true
        if deviceEnabled, let engine = deviceEngines[player] ?? HapticsManager.buildDeviceEngine() {
            deviceEngines[player] = engine
            playPattern(on: engine, intensity: max(clampedLow, clampedHigh), sharpness: clampedHigh, duration: clampedDuration)
        }

        let controllerEnabled = UserDefaults.standard.object(forKey: "rumbleControllerEnabled") as? Bool ?? true
        if controllerEnabled, let engine = controllerEngines[player] {
            playPattern(on: engine, intensity: max(clampedLow, clampedHigh), sharpness: clampedHigh, duration: clampedDuration)
        }
    }

    /// Stop all active haptic players on engines for `player`.
    func stopRumble(player: Int = 0) {
        deviceEngines[player]?.stop(completionHandler: nil)
        controllerEngines[player]?.stop(completionHandler: nil)
    }

    // MARK: - Pattern helpers

    private func playPattern(on engine: CHHapticEngine, intensity: Float, sharpness: Float, duration: TimeInterval) {
        do {
            try engine.start()
            let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensityParam, sharpnessParam],
                relativeTime: 0,
                duration: duration
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            ELOG("HapticsManager: failed to play pattern: \(error)")
        }
    }
}
#endif
