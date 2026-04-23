import Foundation
import PVCoreBridge
import PVLogging
#if canImport(GameController) && canImport(CoreHaptics)
import GameController
import CoreHaptics
#endif
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// ObjC-visible helper that forwards libretro rumble callbacks into
/// the shared GCControllerHapticsManager pipeline.
@objc(PVLibRetroRumbleHelper)
public final class PVLibRetroRumbleHelper: NSObject {

    /// Set the active system profile on GCControllerHapticsManager for better haptic tuning.
    /// Call this when a new game/system is loaded.
    @objc public static func setCurrentSystem(identifier sysId: String) {
        Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.setSystemProfile(forSystemIdentifier: sysId)
            }
#endif
        }
    }

    /// Called from the C rumble callback in PVLibRetroCore.m / PVThinLibretroFrontend.mm.
    /// Strength is 0–0xFFFF per the libretro API.
    @objc public static func rumble(port: UInt32, isStrong: Bool, strength: UInt16) {
        let normalised = Float(strength) / Float(UInt16.max)
        if normalised == 0 {
            stopRumble(port: port)
            return
        }

        let low: Float = isStrong ? normalised : 0
        let high: Float = isStrong ? 0 : normalised
        // Cores like mupen64plus-libretro only fire set_rumble_state on game state changes
        // (e.g. Rumble Pak on/off writes), so the helper must play long enough to cover a
        // typical rumble event if the "off" signal is delayed or dropped (pause, exit, etc.).
        // 2.0s is long enough for most Rumble Pak bursts while short enough that a lost
        // "off" signal doesn't leave the controller buzzing for 10 seconds.
        let duration: TimeInterval = 2.0

        Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                let params = GCControllerHapticsManager.RumbleParams(
                    lowFrequency: low,
                    highFrequency: high,
                    duration: duration
                )
                GCControllerHapticsManager.shared.rumble(player: Int(port), params: params)
                return
            }
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
            let generator = UIImpactFeedbackGenerator(style: isStrong ? .heavy : .medium)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(normalised))
#endif
        }
    }

    @objc public static func stopRumble(port: UInt32) {
        Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.stopRumble(player: Int(port))
            }
#endif
        }
    }
}
