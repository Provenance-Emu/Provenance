//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPSXControllerViewController.swift
//  Provenance
//
//  Created by shruglins on 26/8/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PVPSXButton {
        get {
            return PVPSXButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVPSXControllerViewController: PVControllerViewController<PVPSXSystemResponderClient> {

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let text = button.titleLabel.text else {
                return
            }
            if text == "✖" || text == "✕" {
                button.buttonTag = .cross
            } else if text == "●" || text == "○" {
                button.buttonTag = .circle
            } else if text == "◼" || text == "□" {
                button.buttonTag = .square
            } else if text == "▲" || text == "▵" {
                button.buttonTag = .triangle
            }
        }

        leftShoulderButton?.buttonTag = .l1
        rightShoulderButton?.buttonTag = .r1
        leftShoulderButton2?.buttonTag = .l2
        rightShoulderButton2?.buttonTag = .r2
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                emulatorCore.didPush(.up, forPlayer: 0)
                emulatorCore.didPush(.left, forPlayer: 0)
            case .up:
                emulatorCore.didPush(.up, forPlayer: 0)
            case .upRight:
                emulatorCore.didPush(.up, forPlayer: 0)
                emulatorCore.didPush(.right, forPlayer: 0)
            case .left:
                emulatorCore.didPush(.left, forPlayer: 0)
            case .right:
                emulatorCore.didPush(.right, forPlayer: 0)
            case .downLeft:
                emulatorCore.didPush(.down, forPlayer: 0)
                emulatorCore.didPush(.left, forPlayer: 0)
            case .down:
                emulatorCore.didPush(.down, forPlayer: 0)
            case .downRight:
                emulatorCore.didPush(.down, forPlayer: 0)
                emulatorCore.didPush(.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
    }
}
