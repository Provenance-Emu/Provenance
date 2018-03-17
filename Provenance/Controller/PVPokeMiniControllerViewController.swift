//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPokeMiniControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 10/04/2017.
//  Copyright (c) 2017 Joe Mattiello. All rights reserved.
//

import PVPokeMini

fileprivate extension JSButton {
    var buttonTag : PVPMButton {
        get {
            return PVPMButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVPokeMiniControllerViewController: PVControllerViewController<PVPokeMiniEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "A") {
                button.buttonTag = .A
            }
            else if (button.titleLabel?.text == "B") {
                button.buttonTag = .B
            }
            else if (button.titleLabel?.text == "C") {
                button.buttonTag = .C
            }
        }

        leftShoulderButton?.buttonTag = .menu
        startButton?.buttonTag = .power
        selectButton?.buttonTag = .shake
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let pokeCore = emulatorCore
        pokeCore?.didRelease(.up, forPlayer: 0)
        pokeCore?.didRelease(.down, forPlayer: 0)
        pokeCore?.didRelease(.left, forPlayer: 0)
        pokeCore?.didRelease(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                pokeCore?.didPush(.up, forPlayer: 0)
                pokeCore?.didPush(.left, forPlayer: 0)
            case .up:
                pokeCore?.didPush(.up, forPlayer: 0)
            case .upRight:
                pokeCore?.didPush(.up, forPlayer: 0)
                pokeCore?.didPush(.right, forPlayer: 0)
            case .left:
                pokeCore?.didPush(.left, forPlayer: 0)
            case .right:
                pokeCore?.didPush(.right, forPlayer: 0)
            case .downLeft:
                pokeCore?.didPush(.down, forPlayer: 0)
                pokeCore?.didPush(.left, forPlayer: 0)
            case .down:
                pokeCore?.didPush(.down, forPlayer: 0)
            case .downRight:
                pokeCore?.didPush(.down, forPlayer: 0)
                pokeCore?.didPush(.right, forPlayer: 0)
            default:
                break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let pokeCore = emulatorCore
        pokeCore?.didRelease(.up, forPlayer: 0)
        pokeCore?.didRelease(.down, forPlayer: 0)
        pokeCore?.didRelease(.left, forPlayer: 0)
        pokeCore?.didRelease(.right, forPlayer: 0)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let pokeCore = emulatorCore
        pokeCore?.didPush(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let pokeCore = emulatorCore
        pokeCore?.didRelease(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let pokeCore = emulatorCore
        pokeCore?.didPush(.power, forPlayer: UInt(player))
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let pokeCore = emulatorCore
        pokeCore?.didRelease(.power, forPlayer: UInt(player))
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let pokeCore = emulatorCore
        pokeCore?.didPush(.shake, forPlayer: UInt(player))
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let pokeCore = emulatorCore
        pokeCore?.didRelease(.shake, forPlayer: UInt(player))
        super.releaseSelect(forPlayer: player)
    }
}
