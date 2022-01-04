//
	//  PVEmulatorCore.swift
	//  PVSupport
	//
	//  Created by Joseph Mattiello on 3/8/18.
	//  Copyright © 2018 James Addyman. All rights reserved.
	//

import Foundation

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
//				self?.rumbleGenerator.impactOccurred()
			} else {
				AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
			}
		}
	}
}
