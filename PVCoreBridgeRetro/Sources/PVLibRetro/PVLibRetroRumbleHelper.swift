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

/// C-callable entry point for the libretro rumble callback.
/// Matches `retro_set_rumble_state_t` signature: (port, effect, strength) -> bool.
/// effect: 0 = RETRO_RUMBLE_STRONG, 1 = RETRO_RUMBLE_WEAK
/// strength: 0–0xFFFF
@_cdecl("pv_retro_rumble_callback")
public func pv_retro_rumble_callback(_ port: UInt32, _ effect: UInt32, _ strength: UInt16) -> Bool {
    let isStrong = (effect == 0) // RETRO_RUMBLE_STRONG = 0
    let normalised = Float(strength) / Float(UInt16.max)

    if normalised == 0 {
        Task { @MainActor in
#if canImport(GameController) && canImport(CoreHaptics)
            if #available(iOS 14.0, tvOS 14.0, *) {
                GCControllerHapticsManager.shared.stopRumble(player: Int(port))
            }
#endif
        }
        return true
    }

    let low: Float = isStrong ? normalised : 0
    let high: Float = isStrong ? 0 : normalised
    let duration: TimeInterval = isStrong ? 0.15 : 0.08

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
    return true
}
