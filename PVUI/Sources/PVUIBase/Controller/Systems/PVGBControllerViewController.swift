//
//  PVGBControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 17/03/2018.
//  Copyright (c) 2018 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVGBButton {
        get {
            return PVGBButton(rawValue: tag)!
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVGBControllerViewController: PVControllerViewController<PVGBSystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton else {
                return
            }
            switch button.titleLabel?.text?.lowercased() {
            case "a":
                button.buttonTag = .a
            case "b":
                button.buttonTag = .b
            default:
                break
            }
        }

        startButton?.buttonTag = .start
        selectButton?.buttonTag = .select
    }

    override func dPad(_ dPad: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.left, forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)
        emulatorCore.didRelease(.up, forPlayer: 0)
        emulatorCore.didRelease(.down, forPlayer: 0)
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
        super.dPad(dPad, didPress: direction)
    }

    override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(PVGBButton.up, forPlayer: 0)
            emulatorCore.didRelease(PVGBButton.left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(PVGBButton.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(PVGBButton.up, forPlayer: 0)
            emulatorCore.didRelease(PVGBButton.right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(PVGBButton.left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(PVGBButton.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(PVGBButton.down, forPlayer: 0)
            emulatorCore.didRelease(PVGBButton.left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(PVGBButton.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(PVGBButton.down, forPlayer: 0)
            emulatorCore.didRelease(PVGBButton.right, forPlayer: 0)
        }
        super.dPad(dPad, didRelease: direction)
    }

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.buttonTag, forPlayer: 0)
        super.buttonPressed(button)
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.buttonTag, forPlayer: 0)
        super.buttonReleased(button)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.start, forPlayer: player)
        super.pressStart(forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.start, forPlayer: player)
        super.releaseStart(forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.select, forPlayer: player)
        super.pressSelect(forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.select, forPlayer: player)
        super.releaseSelect(forPlayer: player)
    }
}
