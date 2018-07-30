//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVLynxControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PVLynxButton {
        get {
            return PVLynxButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVLynxControllerViewController: PVControllerViewController<PVLynxSystemResponderClient> {

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "A" {
                button.buttonTag = .a
            } else if title == "B" {
                button.buttonTag = .b
            }
        }

        selectButton?.buttonTag = .option2
        startButton?.buttonTag = .option1
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
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.option1, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.option1, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.option2, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.option2, forPlayer: player)
    }
}
