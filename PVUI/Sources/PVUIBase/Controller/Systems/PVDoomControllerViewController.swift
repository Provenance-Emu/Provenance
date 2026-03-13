//
//  PVDoomControllerViewController.swift
//  Provenance
//
//  Created by Joe Mattiello on 2025.04.05
//  Copyright (c) 2025 Joe Mattiello. All rights reserved.
//
//  Dedicated OSD controller for PrBoom / Doom (com.provenance.doom).
//  Kept separate from the generic DOS controller so that Doom-specific
//  button semantics (fire, use, run, strafe, weapon cycling, map, pause)
//  do not leak into generic DOSBox sessions.
//
//  PrBoom RetroArch core default button mapping (RETRO_DEVICE_ID_JOYPAD_*):
//    B (south)  → Fire / Shoot
//    A (east)   → Use / Interact
//    X (north)  → Run / Speed
//    L / R      → Strafe Left / Right
//    L2 / R2    → Previous / Next Weapon
//    SELECT     → Automap (Map)
//    START      → Pause

import PVSupport
import PVEmulatorCore

private extension JSButton {
    var doomButtonTag: PVDoomButton {
        get {
            return PVDoomButton(rawValue: tag) ?? .up
        }
        set {
            tag = newValue.rawValue
        }
    }
}

final class PVDoomControllerViewController: PVControllerViewController<PVDoomSystemResponderClient> {
    override func layoutViews() {
        // Map face buttons by their OSD label (set in the Doom system plist).
        buttonGroup?.subviews.forEach {
            guard let button = $0 as? JSButton,
                  let title = button.titleLabel?.text else { return }

            // Delegate label→button mapping to PVDoomButton initializer to avoid duplicate logic.
            button.doomButtonTag = PVDoomButton(title)
        }

        // Shoulder buttons / triggers: map by displayed label so layout order (R vs R2) does not matter.
        [leftShoulderButton, rightShoulderButton, leftShoulderButton2, rightShoulderButton2].forEach {
            configureShoulderButton($0)
        }

        // Start = Pause (RETRO_JOYPAD_START in PrBoom)
        startButton?.doomButtonTag  = .pause
        // Select = Automap (RETRO_JOYPAD_SELECT in PrBoom)
        selectButton?.doomButtonTag = .map
    }

    private func configureShoulderButton(_ button: JSButton?) {
        guard let button = button,
              let title = button.titleLabel?.text else { return }
        switch title.lowercased() {
        case "l", "l1":   button.doomButtonTag = .strafeLeft    // L  → RETRO_JOYPAD_L
        case "r", "r1":   button.doomButtonTag = .strafeRight   // R  → RETRO_JOYPAD_R
        case "l2":        button.doomButtonTag = .weaponPrev    // L2 → RETRO_JOYPAD_L2
        case "r2":        button.doomButtonTag = .weaponNext    // R2 → RETRO_JOYPAD_R2
        default:          break
        }
    }

    // MARK: - D-Pad

    override func dPad(_: JSDPad, didPress direction: JSDPadDirection) {
        emulatorCore.didRelease(.up,    forPlayer: 0)
        emulatorCore.didRelease(.down,  forPlayer: 0)
        emulatorCore.didRelease(.left,  forPlayer: 0)
        emulatorCore.didRelease(.right, forPlayer: 0)

        switch direction {
        case .upLeft:
            emulatorCore.didPush(.up,   forPlayer: 0)
            emulatorCore.didPush(.left, forPlayer: 0)
        case .up:
            emulatorCore.didPush(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didPush(.up,    forPlayer: 0)
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
            emulatorCore.didPush(.down,  forPlayer: 0)
            emulatorCore.didPush(.right, forPlayer: 0)
        default:
            break
        }
        vibrate()
    }

    override func dPad(_: JSDPad, didRelease direction: JSDPadDirection) {
        switch direction {
        case .upLeft:
            emulatorCore.didRelease(.up,   forPlayer: 0)
            emulatorCore.didRelease(.left, forPlayer: 0)
        case .up:
            emulatorCore.didRelease(.up, forPlayer: 0)
        case .upRight:
            emulatorCore.didRelease(.up,    forPlayer: 0)
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
            emulatorCore.didRelease(.down,  forPlayer: 0)
            emulatorCore.didRelease(.right, forPlayer: 0)
        }
    }

    // MARK: - Face Buttons

    override func buttonPressed(_ button: JSButton) {
        emulatorCore.didPush(button.doomButtonTag, forPlayer: 0)
        vibrate()
    }

    override func buttonReleased(_ button: JSButton) {
        emulatorCore.didRelease(button.doomButtonTag, forPlayer: 0)
    }

    // MARK: - Start / Select

    override func pressStart(forPlayer player: Int) {
        // Pause game (RETRO_DEVICE_ID_JOYPAD_START in PrBoom)
        emulatorCore.didPush(.pause, forPlayer: player)
    }

    override func releaseStart(forPlayer player: Int) {
        emulatorCore.didRelease(.pause, forPlayer: player)
    }

    override func pressSelect(forPlayer player: Int) {
        // Toggle automap (RETRO_DEVICE_ID_JOYPAD_SELECT in PrBoom)
        emulatorCore.didPush(.map, forPlayer: player)
    }

    override func releaseSelect(forPlayer player: Int) {
        emulatorCore.didRelease(.map, forPlayer: player)
    }
}
