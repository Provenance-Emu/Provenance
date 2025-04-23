//
//  PVAtariJaguarControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 03/20/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVJaguarButton {
        get {
            return PVJaguarButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVAtariJaguarControllerViewController: PVControllerViewController<PVJaguarSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "a":
                button.buttonTag = .a
            case "b":
                button.buttonTag = .b
            case "c":
                button.buttonTag = .c
            case "option", "start":
                button.buttonTag = .option
            case "pause", "select":
                button.buttonTag = .pause
            case "0", "button0":
                button.buttonTag = .button0
            case "1", "button1":
                button.buttonTag = .button1
            case "2", "button2":
                button.buttonTag = .button2
            case "3", "button3":
                button.buttonTag = .button3
            case "4", "button4":
                button.buttonTag = .button4
            case "5", "button5":
                button.buttonTag = .button5
            case "6", "button6":
                button.buttonTag = .button6
            case "7", "button7":
                button.buttonTag = .button7
            case "8", "button8":
                button.buttonTag = .button8
            case "9", "button9":
                button.buttonTag = .button9
            case "#", "button#":
                button.buttonTag = .pound
            case "*", "button*":
                button.buttonTag = .asterisk
            default:
                break
            }
        }

        startButton?.buttonTag = .pause
        selectButton?.buttonTag = .option
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(jaguarButton: .up, forPlayer: 0)
        emulatorCore.didRelease(jaguarButton: .down, forPlayer: 0)
        emulatorCore.didRelease(jaguarButton: .left, forPlayer: 0)
        emulatorCore.didRelease(jaguarButton: .right, forPlayer: 0)
        switch direction {
        case .upLeft:
            emulatorCore.didPush(jaguarButton: .up, forPlayer: 0)
            emulatorCore.didPush(jaguarButton: .left, forPlayer: 0)
        case .up:
            emulatorCore.didPush(jaguarButton: .up, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(jaguarButton: .up, forPlayer: 0)
            emulatorCore.didPush(jaguarButton: .right, forPlayer: 0)
        case .left:
            emulatorCore.didPush(jaguarButton: .left, forPlayer: 0)
        case .right:
            emulatorCore.didPush(jaguarButton: .right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didPush(jaguarButton: .down, forPlayer: 0)
            emulatorCore.didPush(jaguarButton: .left, forPlayer: 0)
        case .down:
            emulatorCore.didPush(jaguarButton: .down, forPlayer: 0)
        case .downRight:
            emulatorCore.didPush(jaguarButton: .down, forPlayer: 0)
            emulatorCore.didPush(jaguarButton: .right, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

   override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(jaguarButton: .up, forPlayer: 0)
            emulatorCore.didRelease(jaguarButton: .left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(jaguarButton: .up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(jaguarButton: .up, forPlayer: 0)
            emulatorCore.didRelease(jaguarButton: .right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(jaguarButton: .left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(jaguarButton: .right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(jaguarButton: .down, forPlayer: 0)
            emulatorCore.didRelease(jaguarButton: .left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(jaguarButton: .down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(jaguarButton: .down, forPlayer: 0)
            emulatorCore.didRelease(jaguarButton: .right, forPlayer: 0)
        }
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(jaguarButton: button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(jaguarButton: button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(jaguarButton: .pause, forPlayer: player)
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(jaguarButton: .pause, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(jaguarButton: .option, forPlayer: player)
        vibrate()
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(jaguarButton: .option, forPlayer: player)
    }
}
