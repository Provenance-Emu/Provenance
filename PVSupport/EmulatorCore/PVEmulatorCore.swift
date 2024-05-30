//
//  PVEmulatorCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 3/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import CoreHaptics
import PVLogging

#if os(iOS) && !targetEnvironment(macCatalyst)
// @_silgen_name("AudioServicesStopSystemSound")
// func AudioServicesStopSystemSound(_ soundID: SystemSoundID)

	// vibrationPattern parameter must be NSDictionary to prevent crash when bridging from Swift.Dictionary.
// @_silgen_name("AudioServicesPlaySystemSoundWithVibration")
// func AudioServicesPlaySystemSoundWithVibration(_ soundID: SystemSoundID, _ idk: Any?, _ vibrationPattern: NSDictionary)
// #endif

@available(iOS 14.0, tvOS 14.0, *)
private var hapticEngines: [CHHapticEngine?] = [CHHapticEngine?].init(repeating: nil, count: 4)

@objc
public extension PVEmulatorCore {
    var supportsRumble: Bool { false }

	func rumble() {
		rumble(player: 0)
	}

    @available(iOS 14.0, tvOS 14.0, *)
    func hapticEngine(for player: Int) -> CHHapticEngine? {
        if let engine = hapticEngines[player] {
            return engine
        } else if let controller = controller(for: player), let newEngine = controller.haptics?.createEngine(withLocality: .all) {
            hapticEngines[player] = newEngine
            newEngine.isAutoShutdownEnabled = true
            return newEngine
        } else {
            return nil
        }
    }

    func controller(for player: Int) -> GCController? {
        var controller: GCController?
        switch player {
        case 1:
            if let controller1 = self.controller1, controller1.isAttachedToDevice {
                #if os(iOS) && !targetEnvironment(macCatalyst)
                rumblePhone()
                #else
                VLOG("rumblePhone*(")
                #endif
            } else {
                controller = self.controller1
            }
        case 2:
            controller = self.controller2
        case 3:
            controller = self.controller3
        case 4:
            controller = self.controller4
        default:
            WLOG("No player \(player)")
            controller = nil
        }
        return controller
    }

	func rumble(player: Int) {
		guard self.supportsRumble else {
			WLOG("Rumble called on core that doesn't support it")
			return
		}

        if #available(iOS 14.0, tvOS 14.0, *) {
            if let haptics = hapticEngine(for: player) {
                // TODO: haptic vibrate
            }
        } else {
            // Fallback on earlier versions
        }
	}

    #if os(iOS) && !targetEnvironment(macCatalyst)
	func rumblePhone() {

		let deviceHasHaptic = (UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0) > 0

		DispatchQueue.main.async {
			if deviceHasHaptic {
//				AudioServicesStopSystemSound(kSystemSoundID_Vibrate)

				var vibrationLength = 30

                #if canImport(UIKit)
				if UIDevice.current.modelGeneration.hasPrefix("iPhone6") {
						// iPhone 5S has a weaker vibration motor, so we vibrate for 10ms longer to compensate
					vibrationLength = 40
				}
                #endif
					// Must use NSArray/NSDictionary to prevent crash.
				let pattern: [Any] = [false, 0, true, vibrationLength]
				let dictionary: [String: Any] = ["VibePattern": pattern, "Intensity": 1]

//				AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary as NSDictionary)
                self.rumble()
			}
//            else {
//				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
//			}
		}
	}
    #endif
}

#if canImport(UIKit)
private extension UIDevice {
	var modelGeneration: String {
		var sysinfo = utsname()
		uname(&sysinfo)

		var modelGeneration: String!

		withUnsafePointer(to: &sysinfo.machine) { pointer in
			pointer.withMemoryRebound(to: UInt8.self, capacity: Int(Mirror(reflecting: pointer.pointee).children.count), { (pointer) in
				modelGeneration = String(cString: pointer)
			})
		}

		return modelGeneration
	}
}
#endif
#endif
public extension PVEmulatorCore {
    static var status: [String:Bool] = [:]
}
