//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVAtari7800ControllerViewController.swift
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//
//
//  PVAtari7800ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 08/22/2016.
//  Copyright (c) 2016 Joe Mattiello. All rights reserved.
//

import ProSystem

fileprivate extension JSButton {
    var buttonTag : OE7800Button {
        get {
            return OE7800Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVAtari7800ControllerViewController: PVControllerViewController<PVProSystemGameCore> {
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
            else if title == "Select" {
                button.buttonTag = .select
            }
            else if title == "Reset" {
                button.buttonTag = .reset
            }
            else if title == "Pause" {
                button.buttonTag = .pause
            }
        }

        startButton?.buttonTag = .reset
        selectButton?.buttonTag = .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let proSystemCore = emulatorCore
        proSystemCore?.didRelease7800Button(.up, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.down, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.left, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                proSystemCore?.didPush7800Button(.up, forPlayer: 0)
                proSystemCore?.didPush7800Button(.left, forPlayer: 0)
            case .up:
                proSystemCore?.didPush7800Button(.up, forPlayer: 0)
            case .upRight:
                proSystemCore?.didPush7800Button(.up, forPlayer: 0)
                proSystemCore?.didPush7800Button(.right, forPlayer: 0)
            case .left:
                proSystemCore?.didPush7800Button(.left, forPlayer: 0)
            case .right:
                proSystemCore?.didPush7800Button(.right, forPlayer: 0)
            case .downLeft:
                proSystemCore?.didPush7800Button(.down, forPlayer: 0)
                proSystemCore?.didPush7800Button(.left, forPlayer: 0)
            case .down:
                proSystemCore?.didPush7800Button(.down, forPlayer: 0)
            case .downRight:
                proSystemCore?.didPush7800Button(.down, forPlayer: 0)
                proSystemCore?.didPush7800Button(.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let proSystemCore = emulatorCore
        proSystemCore?.didRelease7800Button(.up, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.down, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.left, forPlayer: 0)
        proSystemCore?.didRelease7800Button(.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let proSystemCore = emulatorCore
        proSystemCore?.didPush7800Button(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let proSystemCore = emulatorCore
        proSystemCore?.didRelease7800Button(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let proSystemCore = emulatorCore
        proSystemCore?.didPush7800Button(.reset, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let proSystemCore = emulatorCore
        proSystemCore?.didRelease7800Button(.reset, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let proSystemCore = emulatorCore
        proSystemCore?.didPush7800Button(.select, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let proSystemCore = emulatorCore
        proSystemCore?.didRelease7800Button(.select, forPlayer: UInt(player))
    }
}
