//
//  PVStellaControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVStella

fileprivate extension JSButton {
    var buttonTag : PV2600Button {
        get {
            return PV2600Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVStellaControllerViewController: PVControllerViewController<PVStellaGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "Fire" {
                button.buttonTag = .fire1
            }
            else if title == "Select" {
                button.buttonTag = .select
            }
            else if title == "Reset" {
                button.buttonTag = .reset
            }
        }
        
        startButton?.buttonTag = .reset
        selectButton?.buttonTag = .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let stellaCore = emulatorCore
        stellaCore?.didRelease(.up, forPlayer: 0)
        stellaCore?.didRelease(.down, forPlayer: 0)
        stellaCore?.didRelease(.left, forPlayer: 0)
        stellaCore?.didRelease(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                stellaCore?.didPush(.up, forPlayer: 0)
                stellaCore?.didPush(.left, forPlayer: 0)
            case .up:
                stellaCore?.didPush(.up, forPlayer: 0)
            case .upRight:
                stellaCore?.didPush(.up, forPlayer: 0)
                stellaCore?.didPush(.right, forPlayer: 0)
            case .left:
                stellaCore?.didPush(.left, forPlayer: 0)
            case .right:
                stellaCore?.didPush(.right, forPlayer: 0)
            case .downLeft:
                stellaCore?.didPush(.down, forPlayer: 0)
                stellaCore?.didPush(.left, forPlayer: 0)
            case .down:
                stellaCore?.didPush(.down, forPlayer: 0)
            case .downRight:
                stellaCore?.didPush(.down, forPlayer: 0)
                stellaCore?.didPush(.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let stellaCore = emulatorCore
        stellaCore?.didRelease(.up, forPlayer: 0)
        stellaCore?.didRelease(.down, forPlayer: 0)
        stellaCore?.didRelease(.left, forPlayer: 0)
        stellaCore?.didRelease(.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let stellaCore = emulatorCore
        stellaCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let stellaCore = emulatorCore
        stellaCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let stellaCore = emulatorCore
        stellaCore?.didPush(.reset, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let stellaCore = emulatorCore
        stellaCore?.didRelease(.reset, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let stellaCore = emulatorCore
        stellaCore?.didPush(.select, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let stellaCore = emulatorCore
        stellaCore?.didRelease(.select, forPlayer: UInt(player))
    }
}
