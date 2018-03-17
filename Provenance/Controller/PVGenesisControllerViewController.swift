//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVGenesisControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import PVGenesis

fileprivate extension JSButton {
    var buttonTag : PVGenesisButton {
        get {
            return PVGenesisButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVGenesisControllerViewController: PVControllerViewController<PVGenesisEmulatorCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "A" {
                button.buttonTag = .A
            }
            else if title == "B" || title == "1" {
                button.buttonTag = .B
            }
            else if title == "C" || title == "2" {
                button.buttonTag = .C
            }
            else if title == "X" {
                button.buttonTag = .X
            }
            else if title == "Y" {
                button.buttonTag = .Y
            }
            else if title == "Z" {
                button.buttonTag = .Z
            }
        }

        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let genesisCore = emulatorCore
        genesisCore?.release(.up, forPlayer: 0)
        genesisCore?.release(.down, forPlayer: 0)
        genesisCore?.release(.left, forPlayer: 0)
        genesisCore?.release(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                genesisCore?.push(.up, forPlayer: 0)
                genesisCore?.push(.left, forPlayer: 0)
            case .up:
                genesisCore?.push(.up, forPlayer: 0)
            case .upRight:
                genesisCore?.push(.up, forPlayer: 0)
                genesisCore?.push(.right, forPlayer: 0)
            case .left:
                genesisCore?.push(.left, forPlayer: 0)
            case .right:
                genesisCore?.push(.right, forPlayer: 0)
            case .downLeft:
                genesisCore?.push(.down, forPlayer: 0)
                genesisCore?.push(.left, forPlayer: 0)
            case .down:
                genesisCore?.push(.down, forPlayer: 0)
            case .downRight:
                genesisCore?.push(.down, forPlayer: 0)
                genesisCore?.push(.right, forPlayer: 0)
            default:
                break
        }
        super.dPad(dPad, didPress: direction)
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let genesisCore = emulatorCore
        genesisCore?.release(.up, forPlayer: 0)
        genesisCore?.release(.down, forPlayer: 0)
        genesisCore?.release(.left, forPlayer: 0)
        genesisCore?.release(.right, forPlayer: 0)
        super.dPadDidReleaseDirection(dPad)
    }

    override func buttonPressed(_ button: JSButton) {
        let genesisCore = emulatorCore
        genesisCore?.push(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let genesisCore = emulatorCore
        genesisCore?.release(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        let genesisCore = emulatorCore
        genesisCore?.push(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let genesisCore = emulatorCore
        genesisCore?.release(.start, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        let genesisCore = emulatorCore
        genesisCore?.push(.mode, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let genesisCore = emulatorCore
        genesisCore?.release(.mode, forPlayer: player)
        releaseSelect(forPlayer: player)
    }
}
