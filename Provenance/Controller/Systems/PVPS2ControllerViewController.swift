//  PVPS2ControllerViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 9/5/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

import PVSupport

private extension JSButton {
    var buttonTag: PVPS2Button {
        get {
            return PVPS2Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVPS2ControllerViewController: PVControllerViewController<PVPS2SystemResponderClient> {
    override func layoutViews() {
        leftAnalogButton?.buttonTag = .l3
        rightAnalogButton?.buttonTag = .r3

        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let text = button.titleLabel.text else {
                return
            }
            if text == "✖" || text == "✕" {
                button.buttonTag = .cross
            } else if text == "●" || text == "○" {
                button.buttonTag = .circle
            } else if text == "◼" || text == "□" {
                button.buttonTag = .square
            } else if text == "▲" || text == "▵" {
                button.buttonTag = .triangle
            }
        }

        leftShoulderButton?.buttonTag = .l1
        rightShoulderButton?.buttonTag = .r1
        leftShoulderButton2?.buttonTag = .l2
        rightShoulderButton2?.buttonTag = .r2
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }
    
    override func prelayoutSettings() {
        //alwaysRightAlign = true
        alwaysJoypadOverDpad = false
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
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
        switch direction {
        case .upLeft:
            emulatorCore.didPush(.up, forPlayer: 0)
            emulatorCore.didPush(.left, forPlayer: 0)
        case .up:
            emulatorCore.didPush(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(.up, forPlayer: 0)
            emulatorCore.didPush(.right, forPlayer: 0)
        case .left:
            emulatorCore.didPush(.left, forPlayer: 0)
        case .right:
            emulatorCore.didPush(.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didPush(.down, forPlayer: 0)
            emulatorCore.didPush(.left, forPlayer: 0)
        case .down:
            emulatorCore.didPush(.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didPush(.down, forPlayer: 0)
            emulatorCore.didPush(.right, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

   override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
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
        emulatorCore.didPush(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }

    override func pressAnalogMode(forPlayer player: Int) {
        emulatorCore.didPush(.analogMode, forPlayer: player)
        super.pressAnalogMode(forPlayer: player)
    }

    override func releaseAnalogMode(forPlayer player: Int) {
        emulatorCore.didRelease(.analogMode, forPlayer: player)
    }
}
