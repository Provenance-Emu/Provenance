//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPokeMiniControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/04/2017.
//  Copyright (c) 2017 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVPMButton {
        get {
            return PVPMButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVPokeMiniControllerViewController: PVControllerViewController<PVPokeMiniSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            switch button.titleLabel?.text?.lowercased() {
            case "a", "0":
                button.buttonTag = .a
            case "b", "1":
                button.buttonTag = .b
            case "c", "2":
                button.buttonTag = .c
            case "menu":
                button.buttonTag = .menu
            case "power":
                button.buttonTag = .power
            case "shake":
                button.buttonTag = .shake
            default:
                break
            }
        }

        leftShoulderButton2?.buttonTag = .menu
        startButton?.buttonTag = .power
        selectButton?.buttonTag = .shake
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
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
        super.dPad(dPad, didPress: direction)
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
        super.dPad(dPad, didRelease: direction)
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.power, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.power, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.shake, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.shake, forPlayer: player)
        super.releaseSelect(forPlayer: player)
    }
}
