//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVN64ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 11/28/2016.
//  Copyright (c) 2016 James Addyman. All rights reserved.
//

import PVSupport
import GameController

private extension JSButton {
    var buttonTag: PVN64Button {
        get {
            return PVN64Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

// TODO: Make VirtualGC a protocol that calls different methods if iOS 15+, rather than seperate classes, or a factory or something more dynamic

// These should override the default protocol but theyu're not.
// I made a test Workspace with the same protocl inheritance with assoicated type
// and the extension overrides in this format overrode the default extension implimentations.
// I give up after many many hours figuringn out why. Just use a descrete subclass for now.

// extension ControllerVC where Self == PVN64ControllerViewController {
// extension ControllerVC where ResponderType : PVN64SystemResponderClient {

#if os(iOS)

@available(iOS 15.0, *)
let createVirtualController = { (elements: Set<String>) -> GCVirtualController in

  // Earlier I used `fullScreenCover` for games in MenuScreen,
  // but GCVirtualController was BELOW it.
  // So keep GCVirtualController in View, not Overlay/Modal/Sheet containers
  // https://developer.apple.com/forums/thread/682138
  let virtualConfiguration = GCVirtualController.Configuration()
  virtualConfiguration.elements = elements
  let virtualController = GCVirtualController(configuration: virtualConfiguration)

  return virtualController
}

@available(iOS 15.0, *)
final class PVN64ControllerViewController2: PVControllerViewController<PVN64SystemResponderClient> {
	let cPadAsThumbstick: Bool = true
	lazy var elements: Set<String> = {
		var elements: Set<String> = [
			GCInputLeftThumbstick,
			GCInputButtonA,
			GCInputButtonB,
			GCInputLeftShoulder,
			GCInputRightShoulder,
			GCInputLeftTrigger,
			GCInputDirectionPad,
			GCInputDirectionalCardinalDpad]

		if cPadAsThumbstick {
			elements.insert(GCInputRightShoulder)
		}
		return elements
	}()

	var virtualController: GCVirtualController? {
		didSet {
			if let virtualController = virtualController {
				virtualController.connect { maybeError in
					guard maybeError == nil else {
						ELOG("\(maybeError!.localizedDescription)")
						return
					}
				}
			}
		}
		willSet {
			if newValue == nil, let virtualController = virtualController {
				virtualController.disconnect()
			}
		}
	}

	override func setupTouchControls() {
		guard virtualController == nil else { return }
		let isKeyboardConnected = GCKeyboard.coalesced != nil
		if isKeyboardConnected {
		  print("Keyboard is connected")
		}

		let isGamepadConnected = GCController.controllers().count > 0

		if isGamepadConnected {
		  print("Gamepad is connected")
		}
// TODO: Hookup / check keyboard
//		if !isGamepadConnected {
//		  print("There is no keyboard or gamepad so just create Virtual one")
			virtualController = createVirtualController(elements)
//		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		virtualController?.disconnect()
		super.viewWillDisappear(animated)
	}
}
#endif

final class PVN64ControllerViewController: PVControllerViewController<PVN64SystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if button.titleLabel?.text == "A" {
                button.buttonTag = .a
            } else if button.titleLabel?.text == "B" {
                button.buttonTag = .b
            } else if button.titleLabel?.text == "Z" {
                button.buttonTag = .z
            } else if button.titleLabel?.text == "C▲" {
                button.buttonTag = .cUp
            } else if button.titleLabel?.text == "C▼" {
                button.buttonTag = .cDown
            } else if button.titleLabel?.text == "C◀" {
                button.buttonTag = .cLeft
            } else if button.titleLabel?.text == "C▶" {
                button.buttonTag = .cRight
            }
        }

        leftShoulderButton?.buttonTag = .l
        rightShoulderButton?.buttonTag = .r
        zTriggerButton?.buttonTag = .z
        startButton?.buttonTag = .start
    }
    
    override func dPad(_ dPad: JSDPad, joystick value: JoystickValue) {
        var up:CGFloat = value.y < 0.5 ? CGFloat(1 - (value.y * 2)) : 0.0
        var down:CGFloat = value.y > 0.5 ? CGFloat((value.y - 0.5) * 2) : 0.0
        var left:CGFloat = value.x < 0.5 ? CGFloat(1 - (value.x * 2)) : 0.0
        var right:CGFloat = value.x > 0.5 ? CGFloat((value.x - 0.5) * 2) : 0.0

        up = min(up, 1.0)
        down = min(down, 1.0)
        left = min(left, 1.0)
        right = min(right, 1.0)
        
        up = max(up, 0.0)
        down = max(down, 0.0)
        left = max(left, 0.0)
        right = max(right, 0.0)

        print("x: \(value.x) , y: \(value.y), up:\(up), down:\(down), left:\(left), right:\(right), ")
        emulatorCore.didMoveJoystick(.analogUp, withValue: up, forPlayer: 0)
        if down != 0 {
            emulatorCore.didMoveJoystick(.analogDown, withValue: down, forPlayer: 0)
        }
        emulatorCore.didMoveJoystick(.analogLeft, withValue: left, forPlayer: 0)
        if right != 0 {
            emulatorCore.didMoveJoystick(.analogRight, withValue: right, forPlayer: 0)
        }
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        if false {
            // OLD non joystick way
            emulatorCore.didMoveJoystick(.analogUp, withValue: 0, forPlayer: 0)
            emulatorCore.didMoveJoystick(.analogLeft, withValue: 0, forPlayer: 0)
            emulatorCore.didMoveJoystick(.analogRight, withValue: 0, forPlayer: 0)
            emulatorCore.didMoveJoystick(.analogDown, withValue: 0, forPlayer: 0)
            switch direction {
            case .upLeft:
                emulatorCore.didMoveJoystick(.analogUp, withValue: 1, forPlayer: 0)
                emulatorCore.didMoveJoystick(.analogLeft, withValue: 1, forPlayer: 0)
            case .up:
                emulatorCore.didMoveJoystick(.analogUp, withValue: 1, forPlayer: 0)
            case .upRight:
                emulatorCore.didMoveJoystick(.analogUp, withValue: 1, forPlayer: 0)
                emulatorCore.didMoveJoystick(.analogRight, withValue: 1, forPlayer: 0)
            case .left:
                emulatorCore.didMoveJoystick(.analogLeft, withValue: 1, forPlayer: 0)
            case .right:
                emulatorCore.didMoveJoystick(.analogRight, withValue: 1, forPlayer: 0)
            case .downLeft:
                emulatorCore.didMoveJoystick(.analogDown, withValue: 1, forPlayer: 0)
                emulatorCore.didMoveJoystick(.analogLeft, withValue: 1, forPlayer: 0)
            case .down:
                emulatorCore.didMoveJoystick(.analogDown, withValue: 1, forPlayer: 0)
            case .downRight:
                emulatorCore.didMoveJoystick(.analogDown, withValue: 1, forPlayer: 0)
                emulatorCore.didMoveJoystick(.analogRight, withValue: 1, forPlayer: 0)
            default:
                break
            }
        } else {
            emulatorCore.didRelease(.dPadUp, forPlayer: 0)
            emulatorCore.didRelease(.dPadDown, forPlayer: 0)
            emulatorCore.didRelease(.dPadLeft, forPlayer: 0)
            emulatorCore.didRelease(.dPadRight, forPlayer: 0)

            switch direction {
            case .upLeft:
                emulatorCore.didPush(.dPadUp, forPlayer: 0)
                emulatorCore.didPush(.dPadLeft, forPlayer: 0)
            case .up:
                emulatorCore.didPush(.dPadUp, forPlayer: 0)
            case .upRight:
                emulatorCore.didPush(.dPadUp, forPlayer: 0)
                emulatorCore.didPush(.dPadRight, forPlayer: 0)
            case .left:
                emulatorCore.didPush(.dPadLeft, forPlayer: 0)
            case .right:
                emulatorCore.didPush(.dPadRight, forPlayer: 0)
            case .downLeft:
                emulatorCore.didPush(.dPadDown, forPlayer: 0)
                emulatorCore.didPush(.dPadLeft, forPlayer: 0)
            case .down:
                emulatorCore.didPush(.dPadDown, forPlayer: 0)
            case .downRight:
                emulatorCore.didPush(.dPadDown, forPlayer: 0)
                emulatorCore.didPush(.dPadRight, forPlayer: 0)
            default:
                break
            }
        }

        vibrate()
    }

    override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.dPadUp, forPlayer: 0)
            emulatorCore.didRelease(.dPadLeft, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.dPadUp, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.dPadUp, forPlayer: 0)
            emulatorCore.didRelease(.dPadRight, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(.dPadLeft, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(.dPadRight, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(.dPadDown, forPlayer: 0)
            emulatorCore.didRelease(.dPadLeft, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(.dPadDown, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(.dPadDown, forPlayer: 0)
            emulatorCore.didRelease(.dPadRight, forPlayer: 0)
        }
        super.dPad(dPad, didRelease: direction)
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.start, forPlayer: player)
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }
}
