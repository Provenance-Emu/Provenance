//
//  PVAtari5200ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVAtari800

fileprivate extension JSButton {
    var buttonTag : PV5200Button {
        get {
            return PV5200Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVAtari5200ControllerViewController: PVControllerViewController<ATR800GameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "Fire 1" {
                button.buttonTag = .fire1
            }
            else if title == "Fire 2" {
                button.buttonTag = .fire2
            }
        }
        
        leftShoulderButton?.buttonTag = .reset
        startButton?.buttonTag = .start
        selectButton?.buttonTag = .pause
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didRelease5200Button(.up, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.down, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.left, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                a800SystemCore?.didPush5200Button(.up, forPlayer: 0)
                a800SystemCore?.didPush5200Button(.left, forPlayer: 0)
            case .up:
                a800SystemCore?.didPush5200Button(.up, forPlayer: 0)
            case .upRight:
                a800SystemCore?.didPush5200Button(.up, forPlayer: 0)
                a800SystemCore?.didPush5200Button(.right, forPlayer: 0)
            case .left:
                a800SystemCore?.didPush5200Button(.left, forPlayer: 0)
            case .right:
                a800SystemCore?.didPush5200Button(.right, forPlayer: 0)
            case .downLeft:
                a800SystemCore?.didPush5200Button(.down, forPlayer: 0)
                a800SystemCore?.didPush5200Button(.left, forPlayer: 0)
            case .down:
                a800SystemCore?.didPush5200Button(.down, forPlayer: 0)
            case .downRight:
                a800SystemCore?.didPush5200Button(.down, forPlayer: 0)
                a800SystemCore?.didPush5200Button(.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didRelease5200Button(.up, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.down, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.left, forPlayer: 0)
        a800SystemCore?.didRelease5200Button(.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didPush5200Button(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didRelease5200Button(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didPush5200Button(.reset, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didRelease5200Button(.reset, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didPush5200Button(.pause, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let a800SystemCore = emulatorCore
        a800SystemCore?.didRelease5200Button(.pause, forPlayer: UInt(player))
    }
}
