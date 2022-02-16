//
//  PVVectrexControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport

private extension JSButton {
    var buttonTag: PVVectrexButton {
        get {
            return PVVectrexButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVVectrexControllerViewController: PVControllerViewController<PVVectrexSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "1" || title == "" {
                button.buttonTag = .button1
            } else if title == "2" {
                button.buttonTag = .button2
            } else if title == "3" {
                button.buttonTag = .button3
            } else if title == "4" {
                button.buttonTag = .button4
            }
        }

//        startButton?.buttonTag = .reset
//        selectButton?.buttonTag = .select
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.analogUp, forPlayer: 0)
        emulatorCore.didRelease(.analogDown, forPlayer: 0)
        emulatorCore.didRelease(.analogLeft, forPlayer: 0)
        emulatorCore.didRelease(.analogRight, forPlayer: 0)
        switch direction {
        case .upLeft:
            emulatorCore.didPush(.analogUp, forPlayer: 0)
            emulatorCore.didPush(.analogLeft, forPlayer: 0)
        case .up:
            emulatorCore.didPush(.analogUp, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(.analogUp, forPlayer: 0)
            emulatorCore.didPush(.analogRight, forPlayer: 0)
        case .left:
            emulatorCore.didPush(.analogLeft, forPlayer: 0)
        case .right:
            emulatorCore.didPush(.analogRight, forPlayer: 0)
        case .downLeft:
            emulatorCore.didPush(.analogDown, forPlayer: 0)
            emulatorCore.didPush(.analogLeft, forPlayer: 0)
        case .down:
            emulatorCore.didPush(.analogDown, forPlayer: 0)
        case .downRight:
            emulatorCore.didPush(.analogDown, forPlayer: 0)
            emulatorCore.didPush(.analogRight, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

    override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.analogUp, forPlayer: 0)
            emulatorCore.didRelease(.analogLeft, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.analogUp, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.analogUp, forPlayer: 0)
            emulatorCore.didRelease(.analogRight, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(.analogLeft, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(.analogRight, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(.analogDown, forPlayer: 0)
            emulatorCore.didRelease(.analogLeft, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(.analogDown, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(.analogDown, forPlayer: 0)
            emulatorCore.didRelease(.analogRight, forPlayer: 0)
        }
        super.dPad(dPad, didRelease: direction)
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
//        emulatorCore.didPush(.reset, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
//        emulatorCore.didRelease(.reset, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
//        emulatorCore.didPush(.select, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
//        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
