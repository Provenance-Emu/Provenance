//
//  PVAtari5200ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PV5200Button {
        get {
            return PV5200Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVAtari5200ControllerViewController: PVControllerViewController<PV5200SystemResponderClient> {

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "Fire 1" || title == "1" {
                button.buttonTag = .fire1
            } else if title == "Fire 2" || title == "2" {
                button.buttonTag = .fire2
            }
        }

        leftShoulderButton?.buttonTag = .reset
        startButton?.buttonTag = .start
        selectButton?.buttonTag = .pause
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
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
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
