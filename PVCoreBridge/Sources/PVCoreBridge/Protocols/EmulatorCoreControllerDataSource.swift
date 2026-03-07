//
//  EmulatorCoreControllerDataSource.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/3/24.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

#if canImport(GameController)
import GameController
#endif
import PVLogging

@objc public protocol EmulatorCoreControllerDataSource: ResponderClient {
#if canImport(GameController)
    var controller1: GCController? { get set }
    var controller2: GCController? { get set }
    var controller3: GCController? { get set }
    var controller4: GCController? { get set }

    var controller5: GCController? { get set }
    var controller6: GCController? { get set }
    var controller7: GCController? { get set }
    var controller8: GCController? { get set }

    func controller(forPlayer: UInt) -> GCController?
#endif
#if canImport(UIKit) && !os(watchOS)
    var touchViewController: UIViewController? { get set }
#endif
}

#if canImport(GameController)
public extension EmulatorCoreControllerDataSource {

    @MainActor
    func controller(for player: Int) -> GCController? {
        switch player {
        case 1:
            if let controller1 = self.controller1, controller1.isAttachedToDevice {
#if os(iOS) && !targetEnvironment(macCatalyst)
                (self as? EmulatorCoreRumbleDataSource)?.rumblePhone()
#else
                VLOG("rumblePhone*(")
#endif
            }
            return controller1
        case 2: return controller2
        case 3: return controller3
        case 4: return controller4
        case 5: return controller5
        case 6: return controller6
        case 7: return controller7
        case 8: return controller7
        default:
            WLOG("No player \(player)")
            return nil
        }
    }
}
#endif

#if canImport(CoreHaptics)
import CoreHaptics
public extension EmulatorCoreRumbleDataSource {

    @MainActor
    func rumble() {
        Task {
            await MainActor.run { rumble(player: 0) }
        }
    }
}
#endif

#if canImport(CoreHaptics)
public extension EmulatorCoreRumbleDataSource {

    @MainActor
    @available(iOS 14.0, tvOS 14.0, *)
    func hapticEngine(for player: Int) -> CHHapticEngine? {
        return HapticsManager.shared.hapticsEngine(forPlayer: player)
    }

    /// Fire rumble for the given player (0-based).
    ///
    /// Routing priority:
    /// 1. External controller with GCDeviceHaptics support → controller motors
    /// 2. Attached controller (phone) → device Taptic Engine via rumblePhone()
    /// 3. No controller → device Taptic Engine
    @MainActor
    func rumble(player: Int) {
        rumble(player: player, lowFrequency: 0.8, highFrequency: 0.5, duration: 0.3)
    }

    /// Fire rumble with explicit dual-motor parameters.
    ///
    /// - Parameters:
    ///   - player: 0-based player index.
    ///   - lowFrequency: Low-frequency (grip/left) motor intensity in [0, 1].
    ///   - highFrequency: High-frequency (right) motor intensity in [0, 1].
    ///   - duration: Vibration duration in seconds.
    @MainActor
    func rumble(player: Int, lowFrequency: Float, highFrequency: Float, duration: TimeInterval = 0.3) {
        guard self.supportsRumble else {
            WLOG("Rumble called on core that doesn't support it")
            return
        }
        if #available(iOS 14.0, tvOS 14.0, *) {
            // 1-based player index for GCController lookup; player param is 0-based.
            let playerIndex = player + 1
            let controller = self.controller(for: playerIndex)

            if let controller = controller, !controller.isAttachedToDevice, controller.haptics != nil {
                // External controller with haptics support — route to controller motors.
                let params = GCControllerHapticsManager.RumbleParams(
                    lowFrequency: lowFrequency,
                    highFrequency: highFrequency,
                    duration: duration
                )
                GCControllerHapticsManager.shared.rumble(player: player, params: params)
            } else {
                // Attached (phone) controller or no haptics → Taptic Engine.
#if os(iOS) && !targetEnvironment(macCatalyst)
                rumblePhone()
#endif
            }
        } else {
#if os(iOS) && !targetEnvironment(macCatalyst)
            rumblePhone()
#endif
        }
    }

    /// Trigger a rumble with explicit motor intensities and duration for `player`.
    @MainActor
    func rumble(lowFrequency: Float, highFrequency: Float, duration: TimeInterval, player: Int) {
        guard self.supportsRumble else { return }
        if #available(iOS 14.0, tvOS 14.0, *) {
            HapticsManager.shared.rumble(lowFrequency: lowFrequency, highFrequency: highFrequency, duration: duration, player: player)
        }
    }

    /// Stop all rumble for `player`.
    @MainActor
    func stopRumble(player: Int = 0) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            HapticsManager.shared.stopRumble(player: player)
        }
    }

    @MainActor func rumblePhone() {
#if os(iOS) && !targetEnvironment(macCatalyst)
        let deviceHasHaptic = (UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0) > 0
        if deviceHasHaptic {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
#endif
    }
}
#endif
