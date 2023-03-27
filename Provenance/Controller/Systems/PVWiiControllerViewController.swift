//  PVWiiControllerViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance EMU. All rights reserved.
//

import PVSupport

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
			if text == "A" || text == "A" {
				button.buttonTag = .wiiA
			} else if text == "B" || text == "B" {
				button.buttonTag = .wiiB
			} else if text == "+" || text == "+" {
				button.buttonTag = .wiiPlus
			} else if text == "-" || text == "-" {
				button.buttonTag = .wiiMinus
			} else if text == "1" || text == "1" {
				button.buttonTag = .wiiOne
			} else if text == "2" || text == "2" {
				button.buttonTag = .wiiTwo
			} else if text == "C" || text == "C" {
				button.buttonTag = .nunchukC
			} else if text == "Z" || text == "Z" {
				button.buttonTag = .nunchukZ
			}
		}
	}
    override func prelayoutSettings() {
        //alwaysRightAlign = true
        alwaysJoypadOverDpad = false
        topRightJoyPad2 = false
        joyPadScale = 0.5
        joyPad2Scale = 0.5
    }
    override func dPad(_ dPad: JSDPad, joystick2 value: JoystickValue) {
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

        // print("x: \(value.x) , y: \(value.y), up:\(up), down:\(down), left:\(left), right:\(right), ")
        emulatorCore.didMoveJoystick(.wiiSwingUp, withValue: up, forPlayer: 0)
        if down != 0 {
            emulatorCore.didMoveJoystick(.wiiSwingDown, withValue: down, forPlayer: 0)
        }
        emulatorCore.didMoveJoystick(.wiiSwingLeft, withValue: left, forPlayer: 0)
        if right != 0 {
            emulatorCore.didMoveJoystick(.wiiSwingRight, withValue: right, forPlayer: 0)
        }
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

        // print("x: \(value.x) , y: \(value.y), up:\(up), down:\(down), left:\(left), right:\(right), ")
        emulatorCore.didMoveJoystick(.nunchukStickUp, withValue: up, forPlayer: 0)
        if down != 0 {
            emulatorCore.didMoveJoystick(.nunchukStickDown, withValue: down, forPlayer: 0)
        }
        emulatorCore.didMoveJoystick(.nunchukStickLeft, withValue: left, forPlayer: 0)
        if right != 0 {
            emulatorCore.didMoveJoystick(.nunchukStickRight, withValue: right, forPlayer: 0)
        }
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
