//
//  PVVBControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVVBButton {
        get {
            return PVVBButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVVBControllerViewController: PVControllerViewController<MednafenGameCore> {
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
        }

        leftShoulderButton?.buttonTag = .L
        rightShoulderButton?.buttonTag = .R
        selectButton?.buttonTag = .select
        startButton?.buttonTag = .start
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let vbCore = emulatorCore
        vbCore?.didRelease(PVVBButton.leftUp, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftDown, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftLeft, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftRight, forPlayer: 0)
        switch direction {
            case .upLeft:
                vbCore?.didPush(PVVBButton.leftUp, forPlayer: 0)
                vbCore?.didPush(PVVBButton.leftLeft, forPlayer: 0)
            case .up:
                vbCore?.didPush(PVVBButton.leftUp, forPlayer: 0)
            case .upRight:
                vbCore?.didPush(PVVBButton.leftUp, forPlayer: 0)
                vbCore?.didPush(PVVBButton.leftRight, forPlayer: 0)
            case .left:
                vbCore?.didPush(PVVBButton.leftLeft, forPlayer: 0)
            case .right:
                vbCore?.didPush(PVVBButton.leftRight, forPlayer: 0)
            case .downLeft:
                vbCore?.didPush(PVVBButton.leftDown, forPlayer: 0)
                vbCore?.didPush(PVVBButton.leftLeft, forPlayer: 0)
            case .down:
                vbCore?.didPush(PVVBButton.leftDown, forPlayer: 0)
            case .downRight:
                vbCore?.didPush(PVVBButton.leftDown, forPlayer: 0)
                vbCore?.didPush(PVVBButton.leftRight, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let vbCore = emulatorCore
        vbCore?.didRelease(PVVBButton.leftUp, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftDown, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftLeft, forPlayer: 0)
        vbCore?.didRelease(PVVBButton.leftRight, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let vbCore = emulatorCore
        vbCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let vbCore = emulatorCore
        vbCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let vbCore = emulatorCore
        vbCore?.didPush(PVVBButton.start, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let vbCore = emulatorCore
        vbCore?.didRelease(PVVBButton.start, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let vbCore = emulatorCore
        vbCore?.didPush(PVVBButton.select, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let vbCore = emulatorCore
        vbCore?.didRelease(PVVBButton.select, forPlayer: UInt(player))
    }
}
