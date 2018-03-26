//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVWonderSwanControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport

fileprivate extension JSButton {
    var buttonTag: PVWSButton {
        get {
            return PVWSButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVWonderSwanControllerViewController: PVControllerViewController<PVWonderSwanSystemResponderClient> {

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
        selectButton?.buttonTag = .sound
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        /*
             .x1 == Up
             .x2 == Right
             .x3 == Down
             .x4 == Left
             */
        if dPad == self.dPad {
            emulatorCore.didRelease(.x1, forPlayer: 0)
            emulatorCore.didRelease(.x2, forPlayer: 0)
            emulatorCore.didRelease(.x3, forPlayer: 0)
            emulatorCore.didRelease(.x4, forPlayer: 0)
            switch direction {
                case .upLeft:
                    emulatorCore.didPush(.x1, forPlayer: 0)
                    emulatorCore.didPush(.x4, forPlayer: 0)
                case .up:
                    emulatorCore.didPush(.x1, forPlayer: 0)
                case .upRight:
                    emulatorCore.didPush(.x1, forPlayer: 0)
                    emulatorCore.didPush(.x2, forPlayer: 0)
                case .left:
                    emulatorCore.didPush(.x4, forPlayer: 0)
                case .right:
                    emulatorCore.didPush(.x2, forPlayer: 0)
                case .downLeft:
                    emulatorCore.didPush(.x3, forPlayer: 0)
                    emulatorCore.didPush(.x4, forPlayer: 0)
                case .down:
                    emulatorCore.didPush(.x3, forPlayer: 0)
                case .downRight:
                    emulatorCore.didPush(.x3, forPlayer: 0)
                    emulatorCore.didPush(.x2, forPlayer: 0)
                default:
                    break
            }
        } else {
            emulatorCore.didRelease(.y1, forPlayer: 0)
            emulatorCore.didRelease(.y2, forPlayer: 0)
            emulatorCore.didRelease(.y3, forPlayer: 0)
            emulatorCore.didRelease(.y4, forPlayer: 0)
            switch direction {
                case .upLeft:
                    emulatorCore.didPush(.y1, forPlayer: 0)
                    emulatorCore.didPush(.y4, forPlayer: 0)
                case .up:
                    emulatorCore.didPush(.y1, forPlayer: 0)
                case .upRight:
                    emulatorCore.didPush(.y1, forPlayer: 0)
                    emulatorCore.didPush(.y2, forPlayer: 0)
                case .left:
                    emulatorCore.didPush(.y4, forPlayer: 0)
                case .right:
                    emulatorCore.didPush(.y2, forPlayer: 0)
                case .downLeft:
                    emulatorCore.didPush(.y3, forPlayer: 0)
                    emulatorCore.didPush(.y4, forPlayer: 0)
                case .down:
                    emulatorCore.didPush(.y3, forPlayer: 0)
                case .downRight:
                    emulatorCore.didPush(.y3, forPlayer: 0)
                    emulatorCore.didPush(.y2, forPlayer: 0)
                default:
                    break
            }
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        if dPad == self.dPad {
            emulatorCore.didRelease(.x1, forPlayer: 0)
            emulatorCore.didRelease(.x2, forPlayer: 0)
            emulatorCore.didRelease(.x3, forPlayer: 0)
            emulatorCore.didRelease(.x4, forPlayer: 0)
        } else {
            emulatorCore.didRelease(.y1, forPlayer: 0)
            emulatorCore.didRelease(.y2, forPlayer: 0)
            emulatorCore.didRelease(.y3, forPlayer: 0)
            emulatorCore.didRelease(.y4, forPlayer: 0)
        }
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.start, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.sound, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.sound, forPlayer: player)
    }
}
