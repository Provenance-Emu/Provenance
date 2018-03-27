//
//  PVVBControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PVVBButton {
        get {
            return PVVBButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVVBControllerViewController: PVControllerViewController<PVVirtualBoySystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "A" {
                button.buttonTag = .a
            } else if title == "B" {
                button.buttonTag = .b
            }
        }

        leftShoulderButton?.buttonTag = .l
        rightShoulderButton?.buttonTag = .r
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.leftUp, forPlayer: 0)
        emulatorCore.didRelease(.leftDown, forPlayer: 0)
        emulatorCore.didRelease(.leftLeft, forPlayer: 0)
        emulatorCore.didRelease(.leftRight, forPlayer: 0)
        switch direction {
            case .upLeft:
                emulatorCore.didPush(.leftUp, forPlayer: 0)
                emulatorCore.didPush(.leftLeft, forPlayer: 0)
            case .up:
                emulatorCore.didPush(.leftUp, forPlayer: 0)
            case .upRight:
                emulatorCore.didPush(.leftUp, forPlayer: 0)
                emulatorCore.didPush(.leftRight, forPlayer: 0)
            case .left:
                emulatorCore.didPush(.leftLeft, forPlayer: 0)
            case .right:
                emulatorCore.didPush(.leftRight, forPlayer: 0)
            case .downLeft:
                emulatorCore.didPush(.leftDown, forPlayer: 0)
                emulatorCore.didPush(.leftLeft, forPlayer: 0)
            case .down:
                emulatorCore.didPush(.leftDown, forPlayer: 0)
            case .downRight:
                emulatorCore.didPush(.leftDown, forPlayer: 0)
                emulatorCore.didPush(.leftRight, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        emulatorCore.didRelease(.leftUp, forPlayer: 0)
        emulatorCore.didRelease(.leftDown, forPlayer: 0)
        emulatorCore.didRelease(.leftLeft, forPlayer: 0)
        emulatorCore.didRelease(.leftRight, forPlayer: 0)
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
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
