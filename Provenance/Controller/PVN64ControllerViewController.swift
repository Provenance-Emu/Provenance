//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVN64ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 11/28/2016.
//  Copyright (c) 2016 James Addyman. All rights reserved.
//

import PVMupen64Plus

fileprivate extension JSButton {
    var buttonTag : OEN64Button {
        get {
            return OEN64Button(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVN64ControllerViewController: PVControllerViewController<MupenGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "A") {
                button.buttonTag = .A
            }
            else if (button.titleLabel?.text == "B") {
                button.buttonTag = .B
            }
            else if (button.titleLabel?.text == "C▲") {
                button.buttonTag = .cUp
            }
            else if (button.titleLabel?.text == "C▼") {
                button.buttonTag = .cDown
            }
            else if (button.titleLabel?.text == "C◀") {
                button.buttonTag = .cLeft
            }
            else if (button.titleLabel?.text == "C▶") {
                button.buttonTag = .cRight
            }
        }
       
        leftShoulderButton?.buttonTag = .L
        rightShoulderButton?.buttonTag = .R
        selectButton?.buttonTag = .Z
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let n64Core = emulatorCore
        n64Core?.didMoveN64JoystickDirection(.analogUp, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogLeft, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogRight, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogDown, withValue: 0, forPlayer: 0)
        switch direction {
            case .upLeft:
                n64Core?.didMoveN64JoystickDirection(.analogUp, withValue: 1, forPlayer: 0)
                n64Core?.didMoveN64JoystickDirection(.analogLeft, withValue: 1, forPlayer: 0)
            case .up:
                n64Core?.didMoveN64JoystickDirection(.analogUp, withValue: 1, forPlayer: 0)
            case .upRight:
                n64Core?.didMoveN64JoystickDirection(.analogUp, withValue: 1, forPlayer: 0)
                n64Core?.didMoveN64JoystickDirection(.analogRight, withValue: 1, forPlayer: 0)
            case .left:
                n64Core?.didMoveN64JoystickDirection(.analogLeft, withValue: 1, forPlayer: 0)
            case .right:
                n64Core?.didMoveN64JoystickDirection(.analogRight, withValue: 1, forPlayer: 0)
            case .downLeft:
                n64Core?.didMoveN64JoystickDirection(.analogDown, withValue: 1, forPlayer: 0)
                n64Core?.didMoveN64JoystickDirection(.analogLeft, withValue: 1, forPlayer: 0)
            case .down:
                n64Core?.didMoveN64JoystickDirection(.analogDown, withValue: 1, forPlayer: 0)
            case .downRight:
                n64Core?.didMoveN64JoystickDirection(.analogDown, withValue: 1, forPlayer: 0)
                n64Core?.didMoveN64JoystickDirection(.analogRight, withValue: 1, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let n64Core = emulatorCore
        n64Core?.didMoveN64JoystickDirection(.analogUp, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogLeft, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogRight, withValue: 0, forPlayer: 0)
        n64Core?.didMoveN64JoystickDirection(.analogDown, withValue: 0, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let n64Core = emulatorCore
        n64Core?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let n64Core = emulatorCore
        n64Core?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let n64Core = emulatorCore
        n64Core?.didPush(.start, forPlayer: UInt(player))
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        let n64Core = emulatorCore
        n64Core?.didRelease(.start, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let n64Core = emulatorCore
        n64Core?.didPush(.Z, forPlayer: UInt(player))
        vibrate()
    }

    override func releaseSelect(forPlayer player: Int) {
        let n64Core = emulatorCore
        n64Core?.didRelease(.Z, forPlayer: UInt(player))
    }
}
