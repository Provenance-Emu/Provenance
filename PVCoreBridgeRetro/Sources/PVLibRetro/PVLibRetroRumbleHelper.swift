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
