//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVGBAControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 21/03/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

import AudioToolbox
import PVGBA

fileprivate extension JSButton {
    var buttonTag : PVGBAButton {
        get {
            return PVGBAButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVGBAControllerViewController: PVControllerViewController<PVGBAEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            
            if (button.titleLabel?.text == "A") {
                button.buttonTag =  .A
            }
            else if (button.titleLabel?.text == "B") {
                button.buttonTag =  .B
            }
        }

        leftShoulderButton?.buttonTag =  .L
        rightShoulderButton?.buttonTag =  .R
        
        startButton?.buttonTag =  .start
        selectButton?.buttonTag =  .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let gbaCore = emulatorCore
        gbaCore?.release( .up, forPlayer: 0)
        gbaCore?.release( .down, forPlayer: 0)
        gbaCore?.release( .left, forPlayer: 0)
        gbaCore?.release( .right, forPlayer: 0)
        switch direction {
        case .upLeft:
            gbaCore?.push( .up, forPlayer: 0)
            gbaCore?.push( .left, forPlayer: 0)
        case .up:
            gbaCore?.push( .up, forPlayer: 0)
        case .upRight:
            gbaCore?.push( .up, forPlayer: 0)
            gbaCore?.push( .right, forPlayer: 0)
        case .left:
            gbaCore?.push( .left, forPlayer: 0)
        case .right:
            gbaCore?.push( .right, forPlayer: 0)
        case .downLeft:
            gbaCore?.push( .down, forPlayer: 0)
            gbaCore?.push( .left, forPlayer: 0)
        case .down:
            gbaCore?.push( .down, forPlayer: 0)
        case .downRight:
            gbaCore?.push( .down, forPlayer: 0)
            gbaCore?.push( .right, forPlayer: 0)
        case .none:
            break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let gbaCore = emulatorCore
        gbaCore?.release( .up, forPlayer: 0)
        gbaCore?.release( .down, forPlayer: 0)
        gbaCore?.release( .left, forPlayer: 0)
        gbaCore?.release( .right, forPlayer: 0)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let gbaCore = emulatorCore
        gbaCore?.push(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let gbaCore = emulatorCore
        gbaCore?.release(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let gbaCore = emulatorCore
        gbaCore?.push( .start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let gbaCore = emulatorCore
        gbaCore?.release( .start, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let gbaCore = emulatorCore
        gbaCore?.push( .select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let gbaCore = emulatorCore
        gbaCore?.release( .select, forPlayer: player)
        super.releaseSelect(forPlayer: player)
    }
}
