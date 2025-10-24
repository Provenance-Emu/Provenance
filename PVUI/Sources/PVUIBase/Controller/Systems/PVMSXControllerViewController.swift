//
//  PVEP128ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 2022.06.15
//  Copyright (c) 2022 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVEP128Button {
        get {
            return PVEP128Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVEP128ControllerViewController: PVControllerViewController<PVEP128SystemResponderClient> {
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
                button.buttonTag = .select
            case "reset", "start":
                button.buttonTag = .reset
            case "pause":
                button.buttonTag = .pause
            default:
                break
            }
        }

        startButton?.buttonTag = .reset
        selectButton?.buttonTag = .select
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
        emulatorCore.didPush(.select, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
