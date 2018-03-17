//
//  PVNESControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import PVFCEU

fileprivate extension JSButton {
    var buttonTag : PVNESButton {
        get {
            return PVNESButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVNESControllerViewController: PVControllerViewController<PVFCEUEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "A" {
                button.buttonTag = .A
            }
            else if title == "B" {
                button.buttonTag = .B
            }
        }

        startButton?.buttonTag = .start
        selectButton?.buttonTag = .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let nesCore = emulatorCore
        nesCore?.release(.up, forPlayer: 0)
        nesCore?.release(.down, forPlayer: 0)
        nesCore?.release(.left, forPlayer: 0)
        nesCore?.release(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                nesCore?.push(.up, forPlayer: 0)
                nesCore?.push(.left, forPlayer: 0)
            case .up:
                nesCore?.push(.up, forPlayer: 0)
            case .upRight:
                nesCore?.push(.up, forPlayer: 0)
                nesCore?.push(.right, forPlayer: 0)
            case .left:
                nesCore?.push(.left, forPlayer: 0)
            case .right:
                nesCore?.push(.right, forPlayer: 0)
            case .downLeft:
                nesCore?.push(.down, forPlayer: 0)
                nesCore?.push(.left, forPlayer: 0)
            case .down:
                nesCore?.push(.down, forPlayer: 0)
            case .downRight:
                nesCore?.push(.down, forPlayer: 0)
                nesCore?.push(.right, forPlayer: 0)
            default:
                break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let nesCore = emulatorCore
        nesCore?.release(.up, forPlayer: 0)
        nesCore?.release(.down, forPlayer: 0)
        nesCore?.release(.left, forPlayer: 0)
        nesCore?.release(.right, forPlayer: 0)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let nesCore = emulatorCore
        nesCore?.push(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let nesCore = emulatorCore
        nesCore?.release(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let nesCore = emulatorCore
        nesCore?.push(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let nesCore = emulatorCore
        nesCore?.release(.start, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let nesCore = emulatorCore
        nesCore?.push(.select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let nesCore = emulatorCore
        nesCore?.release(.select, forPlayer: player)
        super.releaseSelect(forPlayer: player)
    }
}
