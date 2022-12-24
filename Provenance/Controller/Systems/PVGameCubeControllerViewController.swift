//  PVGameCubeControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 2021/10/20.
//  Copyright (c) 2021 Provenance EMU. All rights reserved.
//

import PVSupport

private extension JSButton {
    var buttonTag: PVGCButton {
        get {
            return PVGCButton(rawValue: tag)!
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

// extension ControllerVC where Self == PVGameCubeControllerViewController {
// extension ControllerVC where ResponderType : PVGameCubeSystemResponderClient {

final class PVGameCubeControllerViewController: PVControllerViewController<PVGameCubeSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if button.titleLabel?.text == "A" {
                button.buttonTag = .a
            } else if button.titleLabel?.text == "B" {
                button.buttonTag = .b
            } else if button.titleLabel?.text == "X" {
                button.buttonTag = .x
            } else if button.titleLabel?.text == "Y" {
                button.buttonTag = .y
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

        leftShoulderButton2?.buttonTag = .l
        rightShoulderButton2?.buttonTag = .r
        leftShoulderButton?.buttonTag = .x
        rightShoulderButton?.buttonTag = .y
        zTriggerButton?.buttonTag = .z
        startButton?.buttonTag = .start
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
        emulatorCore.didPush(.start, forPlayer: player)
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }
}
