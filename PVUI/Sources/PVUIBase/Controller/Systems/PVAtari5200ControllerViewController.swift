//
//  PVAtari5200ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PV5200Button {
        get {
            return PV5200Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVAtari5200ControllerViewController: PVControllerViewController<PV5200SystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "fire 1", "1":
                button.buttonTag = .fire1
            case "fire 2", "2":
                button.buttonTag = .fire2
            case "select":
                button.buttonTag = .start
            case "reset", "start":
                button.buttonTag = .reset
            default:
                break
            }
        }

        startButton?.buttonTag = .reset
        selectButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, joystick value: JoystickValue) {
        var up:CGFloat = value.y < 0.5 ? CGFloat(1 - (value.y * 2)) : 0.0
        var down:CGFloat = value.y > 0.5 ? CGFloat((value.y - 0.5) * 2) : 0.0
        var left:CGFloat = value.x < 0.5 ? CGFloat(1 - (value.x * 2)) : 0.0
        var right:CGFloat = value.x > 0.5 ? CGFloat((value.x - 0.5) * 2) : 0.0

        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
        if up != 0 {
            emulatorCore.didPush(.up, forPlayer: 0)
        }
        if left != 0 {
            emulatorCore.didPush(.left, forPlayer: 0)
        }
        if down != 0 {
            emulatorCore.didPush(.down, forPlayer: 0)
        }
        if right != 0 {
            emulatorCore.didPush(.right, forPlayer: 0)
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
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.reset, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.reset, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.pause, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.pause, forPlayer: player)
    }
}
