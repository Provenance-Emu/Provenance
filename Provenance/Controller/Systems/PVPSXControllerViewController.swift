//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPSXControllerViewController.swift
//  Provenance
//
//  Created by shruglins on 26/8/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport

private extension JSButton {
    var buttonTag: PVPSXButton {
        get {
            return PVPSXButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVPSXControllerViewController: PVControllerViewController<PVPSXSystemResponderClient> {
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
        emulatorCore.didMoveJoystick(.leftAnalogUp, withValue: up, forPlayer: 0)
        if down != 0 {
            emulatorCore.didMoveJoystick(.leftAnalogDown, withValue: down, forPlayer: 0)
        }
        emulatorCore.didMoveJoystick(.leftAnalogLeft, withValue: left, forPlayer: 0)
        if right != 0 {
            emulatorCore.didMoveJoystick(.leftAnalogRight, withValue: right, forPlayer: 0)
        }
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
