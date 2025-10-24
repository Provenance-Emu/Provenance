//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPCEControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVPCEButton {
        get {
            return PVPCEButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVPCEControllerViewController: PVControllerViewController<PVPCESystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "i", "1":
                button.buttonTag = .button1
            case "ii", "2":
                button.buttonTag = .button2
            case "iii", "3":
                button.buttonTag = .button3
            case "iv", "4":
                button.buttonTag = .button4
            case "v", "5":
                button.buttonTag = .button5
            case "vi", "6":
                button.buttonTag = .button6
            case "start", "run":
                button.buttonTag = .run
            case "select":
                button.buttonTag = .select
            default:
                break
            }
        }

        selectButton?.buttonTag = .select
        startButton?.buttonTag = .run
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
        emulatorCore.didPush(.mode, forPlayer: player)
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.mode, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
        vibrate()
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
