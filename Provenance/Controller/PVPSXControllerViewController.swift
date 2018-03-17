//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVPSXControllerViewController.swift
//  Provenance
//
//  Created by shruglins on 26/8/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVPSXButton {
        get {
            return PVPSXButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVPSXControllerViewController: PVControllerViewController<MednafenGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            if (button.titleLabel?.text == "✖") {
                button.buttonTag = .cross
            }
            else if (button.titleLabel?.text == "●") {
                button.buttonTag = .circle
            }
            else if (button.titleLabel?.text == "◼") {
                button.buttonTag = .square
            }
            else if (button.titleLabel?.text == "▲") {
                button.buttonTag = .triangle
            }
        }

        leftShoulderButton?.buttonTag = .L1
        rightShoulderButton?.buttonTag = .R1
        leftShoulderButton2?.buttonTag = .L2
        rightShoulderButton2?.buttonTag = .R2
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let psxCore = emulatorCore
        psxCore?.didRelease(PVPSXButton.up, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.down, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.left, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                psxCore?.didPush(PVPSXButton.up, forPlayer: 0)
                psxCore?.didPush(PVPSXButton.left, forPlayer: 0)
            case .up:
                psxCore?.didPush(PVPSXButton.up, forPlayer: 0)
            case .upRight:
                psxCore?.didPush(PVPSXButton.up, forPlayer: 0)
                psxCore?.didPush(PVPSXButton.right, forPlayer: 0)
            case .left:
                psxCore?.didPush(PVPSXButton.left, forPlayer: 0)
            case .right:
                psxCore?.didPush(PVPSXButton.right, forPlayer: 0)
            case .downLeft:
                psxCore?.didPush(PVPSXButton.down, forPlayer: 0)
                psxCore?.didPush(PVPSXButton.left, forPlayer: 0)
            case .down:
                psxCore?.didPush(PVPSXButton.down, forPlayer: 0)
            case .downRight:
                psxCore?.didPush(PVPSXButton.down, forPlayer: 0)
                psxCore?.didPush(PVPSXButton.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let psxCore = emulatorCore
        psxCore?.didRelease(PVPSXButton.up, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.down, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.left, forPlayer: 0)
        psxCore?.didRelease(PVPSXButton.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let psxCore = emulatorCore
        psxCore?.didPush(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        let psxCore = emulatorCore
        psxCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let psxCore = emulatorCore
        psxCore?.didPush(PVPSXButton.start, forPlayer: UInt(player))
        psxCore?.isStartPressed = true
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        let psxCore = emulatorCore
        psxCore?.didRelease(PVPSXButton.start, forPlayer: UInt(player))
        psxCore?.isStartPressed = false
    }

    override func pressSelect(forPlayer player: Int) {
        let psxCore = emulatorCore
        psxCore?.didPush(PVPSXButton.select, forPlayer: UInt(player))
        psxCore?.isSelectPressed = true
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        let psxCore = emulatorCore
        psxCore?.didRelease(PVPSXButton.select, forPlayer: UInt(player))
        psxCore?.isSelectPressed = false
    }
}
