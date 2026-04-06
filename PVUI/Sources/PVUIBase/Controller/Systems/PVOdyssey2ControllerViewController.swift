//
//  PVOdyssey2ControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 12/15/2021.
//  Copyright (c) 2021 Joe Mattiello. All rights reserved.
//

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var buttonTag: PVOdyssey2Button {
        get {
            guard let mapped = PVOdyssey2Button(rawValue: tag) else {
                assertionFailure("Unexpected JSButton tag \(tag) for Odyssey2 controller; defaulting to .up")
                return .up
            }
            return mapped
        }
        set { tag = newValue.rawValue }
    }
}

final class PVOdyssey2ControllerViewController: PVControllerViewController<PVOdyssey2SystemResponderClient> {
    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else {
                return
            }
            switch title.lowercased() {
            case "action":
                button.buttonTag = .action
            case "0":
                button.buttonTag = .key0
            case "1":
                button.buttonTag = .key1
            case "2":
                button.buttonTag = .key2
            case "3":
                button.buttonTag = .key3
            case "4":
                button.buttonTag = .key4
            case "5":
                button.buttonTag = .key5
            case "6":
                button.buttonTag = .key6
            case "7":
                button.buttonTag = .key7
            case "8":
                button.buttonTag = .key8
            case "9":
                button.buttonTag = .key9
            default:
                break
            }
        }

//        startButton?.buttonTag = .pause
//        selectButton?.buttonTag = .option
    }

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
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

   override func dPad(_ dPad: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.up, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .left:
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .none:
            break
        case .right:
            emulatorCore.didRelease(.right, forPlayer: 0)
        case .downLeft:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .down:
            emulatorCore.didRelease(.down, forPlayer: 0)
        case .downRight:
            emulatorCore.didRelease(.down, forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
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
//        emulatorCore.didPush(.pause, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
//        emulatorCore.didRelease(.pause, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
//        emulatorCore.didPush(.option, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
//        emulatorCore.didRelease(.option, forPlayer: player)
    }
}
