//
//  PVWolf3DControllerViewController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/12/26.
//  Copyright (c) 2026 Provenance Emu. All rights reserved.
//

import PVSupport
import PVEmulatorCore
import PVCoreBridge

private extension JSButton {
    var wolf3DButtonTag: PVWolf3DButton {
        get {
            guard let mapped = PVWolf3DButton(rawValue: tag) else {
                assertionFailure("Unexpected JSButton tag \(tag) for Wolf3D controller; defaulting to .fire")
                return .fire
            }
            return mapped
        }
        set { tag = newValue.rawValue }
    }
}

/// Dedicated Wolf3D / ECWolf controller view controller.
///
/// Button layout mirrors the ECWolf RetroArch core's libretro mapping:
///   - Fire  (south/JOYPAD_B)        → `fire`
///   - Open  (east/JOYPAD_A)         → `open`
///   - Strafe On (west/JOYPAD_Y)     → `strafeOn`
///   - Run   (north/JOYPAD_X)        → `run`
///   - L shoulder (JOYPAD_L)         → `strafeLeft`
///   - R shoulder (JOYPAD_R)         → `strafeRight`
///   - L2 trigger (JOYPAD_L2)        → `weaponPrev`
///   - R2 trigger (JOYPAD_R2)        → `weaponNext`
///   - Select (JOYPAD_SELECT)        → `map`
///   - Start  (JOYPAD_START)         → `menu`
final class PVWolf3DControllerViewController: PVControllerViewController<PVWolf3DSystemResponderClient> {

    override func layoutViews() {
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton, let title = button.titleLabel?.text else { return }
            switch title.lowercased() {
            case "fire", "shoot", "1":
                button.wolf3DButtonTag = .fire
            case "open", "use", "2":
                button.wolf3DButtonTag = .open
            case "strafe", "strafeon":
                button.wolf3DButtonTag = .strafeOn
            case "run", "speed":
                button.wolf3DButtonTag = .run
            default:
                break
            }
        }

        leftShoulderButton?.wolf3DButtonTag = .strafeLeft
        rightShoulderButton?.wolf3DButtonTag = .strafeRight
        leftShoulderButton2?.wolf3DButtonTag = .weaponPrev
        rightShoulderButton2?.wolf3DButtonTag = .weaponNext
        startButton?.wolf3DButtonTag = .menu
        selectButton?.wolf3DButtonTag = .map
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
        emulatorCore.didPush(button.wolf3DButtonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.wolf3DButtonTag, forPlayer: 0)
    }

    override func pressStart(forPlayer player: Int) {
        emulatorCore.didPush(.menu, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.menu, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        emulatorCore.didPush(.map, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.map, forPlayer: player)
    }
}
