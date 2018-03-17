//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVSNESControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 12/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import PVSNES

fileprivate extension JSButton {
    var buttonTag : PVSNESButton {
        get {
            return PVSNESButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVSNESControllerViewController: PVControllerViewController<PVSNESEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "A") {
                button.buttonTag = .A
            }
            else if (button.titleLabel?.text == "B") || (button.titleLabel?.text == "1") {
                button.buttonTag = .B
            }
            else if (button.titleLabel?.text == "X") || (button.titleLabel?.text == "2") {
                button.buttonTag = .X
            }
            else if (button.titleLabel?.text == "Y") {
                button.buttonTag = .Y
            }
        }

        leftShoulderButton?.buttonTag = .triggerLeft
        rightShoulderButton?.buttonTag = .triggerRight
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let snesCore = emulatorCore 
        snesCore?.release(.up, forPlayer: 0)
        snesCore?.release(.down, forPlayer: 0)
        snesCore?.release(.left, forPlayer: 0)
        snesCore?.release(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                snesCore?.push(.up, forPlayer: 0)
                snesCore?.push(.left, forPlayer: 0)
            case .up:
                snesCore?.push(.up, forPlayer: 0)
            case .upRight:
                snesCore?.push(.up, forPlayer: 0)
                snesCore?.push(.right, forPlayer: 0)
            case .left:
                snesCore?.push(.left, forPlayer: 0)
            case .right:
                snesCore?.push(.right, forPlayer: 0)
            case .downLeft:
                snesCore?.push(.down, forPlayer: 0)
                snesCore?.push(.left, forPlayer: 0)
            case .down:
                snesCore?.push(.down, forPlayer: 0)
            case .downRight:
                snesCore?.push(.down, forPlayer: 0)
                snesCore?.push(.right, forPlayer: 0)
            default:
                break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let snesCore = emulatorCore 
        snesCore?.release(.up, forPlayer: 0)
        snesCore?.release(.down, forPlayer: 0)
        snesCore?.release(.left, forPlayer: 0)
        snesCore?.release(.right, forPlayer: 0)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let snesCore = emulatorCore 
        snesCore?.push(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let snesCore = emulatorCore 
        snesCore?.release(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let snesCore = emulatorCore 
        snesCore?.push(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let snesCore = emulatorCore 
        snesCore?.release(.start, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let snesCore = emulatorCore 
        snesCore?.push(.select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let snesCore = emulatorCore 
        snesCore?.release(.select, forPlayer: player)
        super.releaseSelect(forPlayer: player)
    }
}
