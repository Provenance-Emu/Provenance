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

#if canImport(GameController)
import GameController
#endif
import PVLogging

@objc public protocol EmulatorCoreControllerDataSource {
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
    var touchViewController: UIViewController? { get }
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
//    var supportsRumble: Bool { false }

    @MainActor
    func rumble() {
        Task {
            await rumble(player: 0)
        }
    }
}
#endif

#if canImport(CoreHaptics)
public extension EmulatorCoreRumbleDataSource {

    @MainActor
    @available(iOS 14.0, tvOS 14.0, *)
    func hapticEngine(for player: Int) async -> CHHapticEngine? {
        return await HapticsManager.shared.hapticsEngine(forPlayer: player)
    }
    
    @MainActor
    func rumble(player: Int) async {
        guard self.supportsRumble else {
            WLOG("Rumble called on core that doesn't support it")
            return
        }

        if #available(iOS 14.0, tvOS 14.0, *) {
            Task { [weak self] in
                let haptics = await self?.hapticEngine(for: player)
                if let haptics =  haptics {
                    #warning("deviceHasHaptic incomplete")
                    // TODO: haptic vibrate
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }

    @MainActor func rumblePhone() {
#if os(iOS) && !targetEnvironment(macCatalyst)

        let deviceHasHaptic = (UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0) > 0

        DispatchQueue.main.async {
            if deviceHasHaptic {
            #warning("deviceHasHaptic incomplete")

                //                AudioServicesStopSystemSound(kSystemSoundID_Vibrate)

                let vibrationLength = 30

                // Must use NSArray/NSDictionary to prevent crash.
                let pattern: [Any] = [false, 0, true, vibrationLength]
                let _: [String: Any] = ["VibePattern": pattern, "Intensity": 1]

                //                AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary as NSDictionary)
                self.rumble()
            }
            //            else {
            //                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            //            }
        }
#endif
    }
}
#endif
