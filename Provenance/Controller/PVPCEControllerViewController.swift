//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPCEControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVPCEButton {
        get {
            return PVPCEButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVPCEControllerViewController: PVControllerViewController<MednafenGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "I" {
                button.buttonTag = .button1
            }
            else if title == "II" {
                button.buttonTag = .button2
            }
            else if title == "III" {
                button.buttonTag = .button3
            }
            else if title == "IV" {
                button.buttonTag = .button4
            }
            else if title == "V" {
                button.buttonTag = .button5
            }
            else if title == "VI" {
                button.buttonTag = .button6
            }
        }

        selectButton?.buttonTag = .select
        startButton?.buttonTag = .run
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let pceCore = emulatorCore
        pceCore?.didRelease(PVPCEButton.up, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.down, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.left, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                pceCore?.didPush(PVPCEButton.up, forPlayer: 0)
                pceCore?.didPush(PVPCEButton.left, forPlayer: 0)
            case .up:
                pceCore?.didPush(PVPCEButton.up, forPlayer: 0)
            case .upRight:
                pceCore?.didPush(PVPCEButton.up, forPlayer: 0)
                pceCore?.didPush(PVPCEButton.right, forPlayer: 0)
            case .left:
                pceCore?.didPush(PVPCEButton.left, forPlayer: 0)
            case .right:
                pceCore?.didPush(PVPCEButton.right, forPlayer: 0)
            case .downLeft:
                pceCore?.didPush(PVPCEButton.down, forPlayer: 0)
                pceCore?.didPush(PVPCEButton.left, forPlayer: 0)
            case .down:
                pceCore?.didPush(PVPCEButton.down, forPlayer: 0)
            case .downRight:
                pceCore?.didPush(PVPCEButton.down, forPlayer: 0)
                pceCore?.didPush(PVPCEButton.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let pceCore = emulatorCore
        pceCore?.didRelease(PVPCEButton.up, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.down, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.left, forPlayer: 0)
        pceCore?.didRelease(PVPCEButton.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let pceCore = emulatorCore
        pceCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let pceCore = emulatorCore
        pceCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let pceCore = emulatorCore
        pceCore?.didPush(PVPCEButton.mode, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let pceCore = emulatorCore
        pceCore?.didRelease(PVPCEButton.mode, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let pceCore = emulatorCore
        pceCore?.didPush(PVPCEButton.select, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let pceCore = emulatorCore
        pceCore?.didRelease(PVPCEButton.select, forPlayer: UInt(player))
    }
}
