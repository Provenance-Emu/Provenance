//
	//  PVEmulatorCore.swift
	//  PVSupport
	//
	//  Created by Joseph Mattiello on 3/8/18.
	//  Copyright © 2018 James Addyman. All rights reserved.
	//

import Foundation

@_silgen_name("AudioServicesStopSystemSound")
func AudioServicesStopSystemSound(_ soundID: SystemSoundID)

	// vibrationPattern parameter must be NSDictionary to prevent crash when bridging from Swift.Dictionary.
@_silgen_name("AudioServicesPlaySystemSoundWithVibration")
func AudioServicesPlaySystemSoundWithVibration(_ soundID: SystemSoundID, _ idk: Any?, _ vibrationPattern: NSDictionary)

@objc
public extension PVEmulatorCore {
	var supportsRumble: Bool { false }

	func rumble() {
		rumble(player: 0)
	}

	func rumble(player: Int) {
		guard self.supportsRumble else {
			WLOG("Rumble called on core that doesn't support it")
			return
		}

		var controller: GCController?
		switch player {
		case 1:
			if let controller1 = self.controller1, controller1.isAttachedToDevice {
				rumblePhone()
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
			return
		}

	}

	func rumblePhone() {

		let deviceHasHaptic = (UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int ?? 0) > 0

		DispatchQueue.main.async {
			if deviceHasHaptic {
				AudioServicesStopSystemSound(kSystemSoundID_Vibrate)

				var vibrationLength = 30

				if UIDevice.current.modelGeneration.hasPrefix("iPhone6") {
						// iPhone 5S has a weaker vibration motor, so we vibrate for 10ms longer to compensate
					vibrationLength = 40
				}

					// Must use NSArray/NSDictionary to prevent crash.
				let pattern: [Any] = [false, 0, true, vibrationLength]
				let dictionary: [String: Any] = ["VibePattern": pattern, "Intensity": 1]

				AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary as NSDictionary)
					//				self?.rumbleGenerator.impactOccurred()
			} else {
				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
			}
		}
	}
}

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
