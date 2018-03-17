//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVLynxControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVMednafen

fileprivate extension JSButton {
    var buttonTag : PVLynxButton {
        get {
            return PVLynxButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

class PVLynxControllerViewController: PVControllerViewController<MednafenGameCore> {
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

        leftShoulderButton?.buttonTag = PVLynxButton.option1
        rightShoulderButton?.buttonTag = PVLynxButton.option2
        selectButton?.buttonTag = PVLynxButton.option2
        startButton?.buttonTag = PVLynxButton.option1
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        let lynxCore = emulatorCore 
        lynxCore?.didRelease(PVLynxButton.up, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.down, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.left, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.right, forPlayer: 0)
        switch direction {
            case .upLeft:
                lynxCore?.didPush(PVLynxButton.up, forPlayer: 0)
                lynxCore?.didPush(PVLynxButton.left, forPlayer: 0)
            case .up:
                lynxCore?.didPush(PVLynxButton.up, forPlayer: 0)
            case .upRight:
                lynxCore?.didPush(PVLynxButton.up, forPlayer: 0)
                lynxCore?.didPush(PVLynxButton.right, forPlayer: 0)
            case .left:
                lynxCore?.didPush(PVLynxButton.left, forPlayer: 0)
            case .right:
                lynxCore?.didPush(PVLynxButton.right, forPlayer: 0)
            case .downLeft:
                lynxCore?.didPush(PVLynxButton.down, forPlayer: 0)
                lynxCore?.didPush(PVLynxButton.left, forPlayer: 0)
            case .down:
                lynxCore?.didPush(PVLynxButton.down, forPlayer: 0)
            case .downRight:
                lynxCore?.didPush(PVLynxButton.down, forPlayer: 0)
                lynxCore?.didPush(PVLynxButton.right, forPlayer: 0)
            default:
                break
        }
        vibrate()
    }

    override func dPadDidReleaseDirection(_ dPad: JSDPad) {
        let lynxCore = emulatorCore 
        lynxCore?.didRelease(PVLynxButton.up, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.down, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.left, forPlayer: 0)
        lynxCore?.didRelease(PVLynxButton.right, forPlayer: 0)
    }

    override func buttonPressed(_ button: JSButton) {
        let lynxCore = emulatorCore 
        lynxCore?.didPush(button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        let lynxCore = emulatorCore 
        lynxCore?.didRelease(button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        let lynxCore = emulatorCore 
        lynxCore?.didPush(PVLynxButton.option1, forPlayer: UInt(player))
    }

    override func releaseStart(forPlayer player: Int) {
        let lynxCore = emulatorCore 
        lynxCore?.didRelease(PVLynxButton.option1, forPlayer: UInt(player))
    }

    override func pressSelect(forPlayer player: Int) {
        let lynxCore = emulatorCore 
        lynxCore?.didPush(PVLynxButton.option2, forPlayer: UInt(player))
    }

    override func releaseSelect(forPlayer player: Int) {
        let lynxCore = emulatorCore 
        lynxCore?.didRelease(PVLynxButton.option2, forPlayer: UInt(player))
    }
}
