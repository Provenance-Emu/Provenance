//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVN64ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 11/28/2016.
//  Copyright (c) 2016 James Addyman. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PVN64Button {
        get {
            return PVN64Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

// These should override the default protocol but theyu're not.
// I made a test Workspace with the same protocl inheritance with assoicated type
// and the extension overrides in this format overrode the default extension implimentations.
// I give up after many many hours figuringn out why. Just use a descrete subclass for now.

//extension ControllerVC where Self == PVN64ControllerViewController {
//extension ControllerVC where ResponderType : PVN64SystemResponderClient {

class PVN64ControllerViewController: PVControllerViewController<PVN64SystemResponderClient> {

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "A") {
                button.buttonTag = .a
            } else if (button.titleLabel?.text == "B") {
                button.buttonTag = .b
            } else if (button.titleLabel?.text == "C▲") {
                button.buttonTag = .cUp
            } else if (button.titleLabel?.text == "C▼") {
                button.buttonTag = .cDown
            } else if (button.titleLabel?.text == "C◀") {
                button.buttonTag = .cLeft
            } else if (button.titleLabel?.text == "C▶") {
                button.buttonTag = .cRight
            }
        }

        leftShoulderButton?.buttonTag = .l
        rightShoulderButton?.buttonTag = .r
        zTriggerButton?.buttonTag = .z
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
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
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        emulatorCore.didMoveJoystick(.analogUp, withValue: 0, forPlayer: 0)
        emulatorCore.didMoveJoystick(.analogLeft, withValue: 0, forPlayer: 0)
        emulatorCore.didMoveJoystick(.analogRight, withValue: 0, forPlayer: 0)
        emulatorCore.didMoveJoystick(.analogDown, withValue: 0, forPlayer: 0)
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
