//  PVWiiControllerViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance EMU. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
	var buttonTag: PVWiiMoteButton {
		get {
			return PVWiiMoteButton(rawValue: tag)!
		}
		set {
			tag = newValue.rawValue
		}
	}
}

final class PVWiiControllerViewController: PVControllerViewController<PVWiiSystemResponderClient> {
	override func layoutViews() {
        leftShoulderButton?.buttonTag = .nunchukC
        rightShoulderButton?.buttonTag = .nunchukZ
        leftShoulderButton2?.buttonTag = .wiiPlus
        rightShoulderButton2?.buttonTag = .wiiMinus
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
		buttonGroup?.subviews.forEach {
			guard let button = $0 as? JSButton, let text = button.titleLabel.text else {
				return
			}
			switch text.lowercased() {
			case "a", "wii":
				button.buttonTag = .wiiA
			case "b", "wiib":
				button.buttonTag = .wiiB
			case "+", "wii+":
				button.buttonTag = .wiiPlus
			case "-", "wii-":
				button.buttonTag = .wiiMinus
			case "1", "wii1":
				button.buttonTag = .wiiOne
			case "2", "wii2":
				button.buttonTag = .wiiTwo
			case "c", "wii-c", "wiic":
				button.buttonTag = .nunchukC
			case "z", "wii-z", "wiiz":
				button.buttonTag = .nunchukZ
			default:
				break
			}
		}
	}
    override func prelayoutSettings() {
        //alwaysRightAlign = true
        alwaysJoypadOverDpad = false
        topRightJoyPad2 = false
        joyPadScale = 0.35
        joyPad2Scale = 0.35
    }
    override func dPad(_ dPad: JSDPad, joystick2 value: JoystickValue) {
        var y:CGFloat = -CGFloat(value.y - 0.5) * 5
        var x:CGFloat = CGFloat(value.x - 0.5) * 5

        y = y < -1 ? -1 : y > 1 ? 1 : y;
        x = x < -1 ? -1 : x > 1 ? 1 : x;
        emulatorCore.didMoveJoystick(.rightAnalog, withXValue: x, withYValue: y, forPlayer: 0)
    }
    override func dPad(_ dPad: JSDPad, joystick value: JoystickValue) {
        var y:CGFloat = -CGFloat(value.y - 0.5) * 5
        var x:CGFloat = CGFloat(value.x - 0.5) * 5

        y = y < -1 ? -1 : y > 1 ? 1 : y;
        x = x < -1 ? -1 : x > 1 ? 1 : x;
        emulatorCore.didMoveJoystick(.leftAnalog, withXValue: x, withYValue: y, forPlayer: 0)
    }
	override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
		emulatorCore.didRelease(.wiiDPadUp, forPlayer: 0)
		emulatorCore.didRelease(.wiiDPadDown, forPlayer: 0)
		emulatorCore.didRelease(.wiiDPadLeft, forPlayer: 0)
		emulatorCore.didRelease(.wiiDPadRight, forPlayer: 0)
		switch direction {
		case .upLeft:
			emulatorCore.didPush(.wiiDPadUp, forPlayer: 0)
			emulatorCore.didPush(.wiiDPadLeft, forPlayer: 0)
		case .up:
			emulatorCore.didPush(.wiiDPadUp, forPlayer: 0)
		case .upRight:
			emulatorCore.didPush(.wiiDPadUp, forPlayer: 0)
			emulatorCore.didPush(.wiiDPadRight, forPlayer: 0)
		case .left:
			emulatorCore.didPush(.wiiDPadLeft, forPlayer: 0)
		case .right:
			emulatorCore.didPush(.wiiDPadRight, forPlayer: 0)
		case .downLeft:
			emulatorCore.didPush(.wiiDPadDown, forPlayer: 0)
			emulatorCore.didPush(.wiiDPadLeft, forPlayer: 0)
		case .down:
			emulatorCore.didPush(.wiiDPadDown, forPlayer: 0)
		case .downRight:
			emulatorCore.didPush(.wiiDPadDown, forPlayer: 0)
			emulatorCore.didPush(.wiiDPadRight, forPlayer: 0)
		default:
			break
		}
		vibrate()
	}

	override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
		 switch direction {
		 case .upLeft:
			 emulatorCore.didRelease(.wiiDPadUp, forPlayer: 0)
			 emulatorCore.didRelease(.wiiDPadLeft, forPlayer: 0)
		 case .up:
			 emulatorCore.didRelease(.wiiDPadUp, forPlayer: 0)
		 case .upRight:
			 emulatorCore.didRelease(.wiiDPadUp, forPlayer: 0)
			 emulatorCore.didRelease(.wiiDPadRight, forPlayer: 0)
		 case .left:
			 emulatorCore.didRelease(.wiiDPadLeft, forPlayer: 0)
		 case .none:
			 break
		 case .right:
			 emulatorCore.didRelease(.wiiDPadRight, forPlayer: 0)
		 case .downLeft:
			 emulatorCore.didRelease(.wiiDPadDown, forPlayer: 0)
			 emulatorCore.didRelease(.wiiDPadLeft, forPlayer: 0)
		 case .down:
			 emulatorCore.didRelease(.wiiDPadDown, forPlayer: 0)
		 case .downRight:
			 emulatorCore.didRelease(.wiiDPadDown, forPlayer: 0)
			 emulatorCore.didRelease(.wiiDPadRight, forPlayer: 0)
		 }
	 }

	override func buttonPressed(_ button: JSButton) {
		emulatorCore.didPush(button.buttonTag, forPlayer: 0)
		super.buttonPressed(button)
	}

	override func buttonReleased(_ button: JSButton) {
		emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
	}

	override func pressStart(forPlayer player: Int) {
		emulatorCore.didPush(.wiiHome, forPlayer: player)
		super.pressStart(forPlayer: player)
	}

	override func releaseStart(forPlayer player: Int) {
		emulatorCore.didRelease(.wiiHome, forPlayer: player)
	}
}
