//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PV32XControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PicoDrive

fileprivate extension JSButton {
    var buttonTag : PVSega32XButton {
        get {
            return PVSega32XButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PV32XControllerViewController: PVControllerViewController<PicodriveGameCore> {
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
            else if title == "C" {
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
            else if title == "Mode" {
                button.buttonTag = .mode
            }
            else if title == "Start" {
                button.buttonTag = .start
            }
        }
        
        startButton?.buttonTag = .start
        selectButton?.buttonTag = .mode
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let three2xCore = emulatorCore
        three2xCore?.didRelease(.up, forPlayer: 0)
        three2xCore?.didRelease(.down, forPlayer: 0)
        three2xCore?.didRelease(.left, forPlayer: 0)
        three2xCore?.didRelease(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                three2xCore?.didPush(.up, forPlayer: 0)
                three2xCore?.didPush(.left, forPlayer: 0)
            case .up:
                three2xCore?.didPush(.up, forPlayer: 0)
            case .upRight:
                three2xCore?.didPush(.up, forPlayer: 0)
                three2xCore?.didPush(.right, forPlayer: 0)
            case .left:
                three2xCore?.didPush(.left, forPlayer: 0)
            case .right:
                three2xCore?.didPush(.right, forPlayer: 0)
            case .downLeft:
                three2xCore?.didPush(.down, forPlayer: 0)
                three2xCore?.didPush(.left, forPlayer: 0)
            case .down:
                three2xCore?.didPush(.down, forPlayer: 0)
            case .downRight:
                three2xCore?.didPush(.down, forPlayer: 0)
                three2xCore?.didPush(.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let three2xCore = emulatorCore
        three2xCore?.didRelease(.up, forPlayer: 0)
        three2xCore?.didRelease(.down, forPlayer: 0)
        three2xCore?.didRelease(.left, forPlayer: 0)
        three2xCore?.didRelease(.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let three2xCore = emulatorCore
        three2xCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let three2xCore = emulatorCore
        three2xCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let three2xCore = emulatorCore
        three2xCore?.didPush(.start, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let three2xCore = emulatorCore
        three2xCore?.didRelease(.start, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let three2xCore = emulatorCore
        three2xCore?.didPush(.mode, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let three2xCore = emulatorCore
        three2xCore?.didRelease(.mode, forPlayer: UInt(player))
    }
}
