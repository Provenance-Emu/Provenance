//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVNeoGeoPocketControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 03/06/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVNGPButton {
        get {
            return PVNGPButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVNeoGeoPocketControllerViewController: PVControllerViewController<MednafenGameCore> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let text = button.titleLabel?.text else {
                return
            }
            if text == "A" {
                button.buttonTag = .A
            }
            else if text == "B" {
                button.buttonTag = .B
            }
        }

        selectButton?.buttonTag = .option
        startButton?.buttonTag = .option
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let ngCore = emulatorCore
        ngCore?.didRelease(PVNGPButton.up, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.down, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.left, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                ngCore?.didPush(PVNGPButton.up, forPlayer: 0)
                ngCore?.didPush(PVNGPButton.left, forPlayer: 0)
            case .up:
                ngCore?.didPush(PVNGPButton.up, forPlayer: 0)
            case .upRight:
                ngCore?.didPush(PVNGPButton.up, forPlayer: 0)
                ngCore?.didPush(PVNGPButton.right, forPlayer: 0)
            case .left:
                ngCore?.didPush(PVNGPButton.left, forPlayer: 0)
            case .right:
                ngCore?.didPush(PVNGPButton.right, forPlayer: 0)
            case .downLeft:
                ngCore?.didPush(PVNGPButton.down, forPlayer: 0)
                ngCore?.didPush(PVNGPButton.left, forPlayer: 0)
            case .down:
                ngCore?.didPush(PVNGPButton.down, forPlayer: 0)
            case .downRight:
                ngCore?.didPush(PVNGPButton.down, forPlayer: 0)
                ngCore?.didPush(PVNGPButton.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let ngCore = emulatorCore
        ngCore?.didRelease(PVNGPButton.up, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.down, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.left, forPlayer: 0)
        ngCore?.didRelease(PVNGPButton.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let ngCore = emulatorCore
        ngCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let ngCore = emulatorCore
        ngCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let ngCore = emulatorCore
        ngCore?.didPush(PVNGPButton.option, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let ngCore = emulatorCore
        ngCore?.didRelease(PVNGPButton.option, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let ngCore = emulatorCore
        ngCore?.didPush(PVNGPButton.option, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let ngCore = emulatorCore
        ngCore?.didRelease(PVNGPButton.option, forPlayer: UInt(player))
    }
}
