//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVLynxControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVLynxButton {
        get {
            return PVLynxButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVLynxControllerViewController: PVControllerViewController<PVLynxSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "a":
                button.buttonTag = .a
            case "b":
                button.buttonTag = .b
            case "o1", "option1":
                button.buttonTag = .option1
            case "o2", "option2":
                button.buttonTag = .option2
            default:
                break
            }
        }

        selectButton?.buttonTag = .option2
        startButton?.buttonTag = .option1
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(LynxButton: .up, forPlayer: 0)
        emulatorCore.didRelease(LynxButton: .down, forPlayer: 0)
        emulatorCore.didRelease(LynxButton: .left, forPlayer: 0)
        emulatorCore.didRelease(LynxButton: .right, forPlayer: 0)
        switch direction {
        case .upLeft:
            emulatorCore.didPush(LynxButton: .up, forPlayer: 0)
            emulatorCore.didPush(LynxButton: .left, forPlayer: 0)
        case .up:
            emulatorCore.didPush(LynxButton: .up, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(LynxButton: .up, forPlayer: 0)
            emulatorCore.didPush(LynxButton: .right, forPlayer: 0)
        case .left:
            emulatorCore.didPush(LynxButton: .left, forPlayer: 0)
        case .right:
            emulatorCore.didPush(LynxButton: .right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didPush(LynxButton: .down, forPlayer: 0)
            emulatorCore.didPush(LynxButton: .left, forPlayer: 0)
        case .down:
            emulatorCore.didPush(LynxButton: .down, forPlayer: 0)
        case .downRight:
            emulatorCore.didPush(LynxButton: .down, forPlayer: 0)
            emulatorCore.didPush(LynxButton: .right, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

   override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(LynxButton: .up, forPlayer: 0)
            emulatorCore.didRelease(LynxButton: .left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(LynxButton: .up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(LynxButton: .up, forPlayer: 0)
            emulatorCore.didRelease(LynxButton: .right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(LynxButton: .left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(LynxButton: .right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(LynxButton: .down, forPlayer: 0)
            emulatorCore.didRelease(LynxButton: .left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(LynxButton: .down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(LynxButton: .down, forPlayer: 0)
            emulatorCore.didRelease(LynxButton: .right, forPlayer: 0)
        }
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(LynxButton: button.buttonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(LynxButton: button.buttonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(LynxButton: .option1, forPlayer: player)
        vibrate()
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(LynxButton: .option1, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(LynxButton: .option2, forPlayer: player)
        vibrate()
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(LynxButton: .option2, forPlayer: player)
    }
}
