//
	//  PVEmulatorCore.swift
	//  PVSupport
	//
	//  Created by Joseph Mattiello on 3/8/18.
	//  Copyright © 2018 James Addyman. All rights reserved.
	//

import Foundation
import CoreHaptics

@available(iOS 14.0, tvOS 14.0, *)
private var hapticEngines: [CHHapticEngine?] = [CHHapticEngine?].init(repeating: nil, count: 4)

@objc
public extension PVEmulatorCore {
    var numberOfUsers: UInt {
        if self.controller4 != nil { return 4 }
        if self.controller3 != nil { return 3 }
        if self.controller2 != nil { return 2 }
        if self.controller1 != nil { return 1 }
        return 1
    }
}

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
        case 0, 1:
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

    func rumble(player: Int, sharpness: Float = 0.5, intensity: Float = 1) {
		guard self.supportsRumble else {
			WLOG("Rumble called on core that doesn't support it")
			return
		}

        if #available(iOS 14.0, tvOS 14.0, *) {
            if let haptics = hapticEngine(for: player) {
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                  CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                  CHHapticEventParameter(parameterID: .hapticIntensity, value: 1)
                ], relativeTime: 0)

                do {
                  let pattern = try CHHapticPattern(events: [event], parameters: [])
                  let player = try haptics.makePlayer(with: pattern)
                  try player.start(atTime: CHHapticTimeImmediate)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        } else {
            // Fallback on earlier versions
        }
	}

    #if os(iOS) && !targetEnvironment(macCatalyst)
	func rumblePhone() {
        DispatchQueue.main.async { [weak self] in
            self?.rumble(player: 1)
		}
	}
    #endif
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
