//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVWonderSwanControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVWSButton {
        get {
            return PVWSButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVWonderSwanControllerViewController: PVControllerViewController<MednafenGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            if title == "A" {
                button.buttonTag = PVWSButton.A
            }
            else if title == "B" {
                button.buttonTag = PVWSButton.B
            }
        }
        
        selectButton?.buttonTag = PVWSButton.sound
        startButton?.buttonTag = PVWSButton.start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let wsCore = emulatorCore
        /*
             PVWSButton.X1 == Up
             PVWSButton.X2 == Right
             PVWSButton.X3 == Down
             PVWSButton.X4 == Left
             */
        if dPad == self.dPad {
            wsCore?.didRelease(PVWSButton.X1, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X2, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X3, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X4, forPlayer: 0)
            switch direction {
                case .upLeft:
                    wsCore?.didPush(PVWSButton.X1, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.X4, forPlayer: 0)
                case .up:
                    wsCore?.didPush(PVWSButton.X1, forPlayer: 0)
                case .upRight:
                    wsCore?.didPush(PVWSButton.X1, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.X2, forPlayer: 0)
                case .left:
                    wsCore?.didPush(PVWSButton.X4, forPlayer: 0)
                case .right:
                    wsCore?.didPush(PVWSButton.X2, forPlayer: 0)
                case .downLeft:
                    wsCore?.didPush(PVWSButton.X3, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.X4, forPlayer: 0)
                case .down:
                    wsCore?.didPush(PVWSButton.X3, forPlayer: 0)
                case .downRight:
                    wsCore?.didPush(PVWSButton.X3, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.X2, forPlayer: 0)
                default:
                    break
            }
        }
        else {
            wsCore?.didRelease(PVWSButton.Y1, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y2, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y3, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y4, forPlayer: 0)
            switch direction {
                case .upLeft:
                    wsCore?.didPush(PVWSButton.Y1, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.Y4, forPlayer: 0)
                case .up:
                    wsCore?.didPush(PVWSButton.Y1, forPlayer: 0)
                case .upRight:
                    wsCore?.didPush(PVWSButton.Y1, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.Y2, forPlayer: 0)
                case .left:
                    wsCore?.didPush(PVWSButton.Y4, forPlayer: 0)
                case .right:
                    wsCore?.didPush(PVWSButton.Y2, forPlayer: 0)
                case .downLeft:
                    wsCore?.didPush(PVWSButton.Y3, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.Y4, forPlayer: 0)
                case .down:
                    wsCore?.didPush(PVWSButton.Y3, forPlayer: 0)
                case .downRight:
                    wsCore?.didPush(PVWSButton.Y3, forPlayer: 0)
                    wsCore?.didPush(PVWSButton.Y2, forPlayer: 0)
                default:
                    break
            }
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let wsCore = emulatorCore
        if dPad == self.dPad {
            wsCore?.didRelease(PVWSButton.X1, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X2, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X3, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.X4, forPlayer: 0)
        }
        else {
            wsCore?.didRelease(PVWSButton.Y1, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y2, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y3, forPlayer: 0)
            wsCore?.didRelease(PVWSButton.Y4, forPlayer: 0)
        }
    }

    override func buttonPressed(_ button: JSButton) {
        let wsCore = emulatorCore
        wsCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let wsCore = emulatorCore
        wsCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let wsCore = emulatorCore
        wsCore?.didPush(PVWSButton.start, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let wsCore = emulatorCore
        wsCore?.didRelease(PVWSButton.start, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let wsCore = emulatorCore
        wsCore?.didPush(PVWSButton.sound, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let wsCore = emulatorCore
        wsCore?.didRelease(PVWSButton.sound, forPlayer: UInt(player))
    }
}
