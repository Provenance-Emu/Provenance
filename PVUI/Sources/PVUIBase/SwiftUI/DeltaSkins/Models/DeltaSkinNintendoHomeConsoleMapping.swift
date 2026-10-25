//
//  DeltaSkinNintendoHomeConsoleMapping.swift
//  PVUIBase
//
//  Skin-token -> core-button tables for GameCube and Wii (Dolphin). The
//  thumbstick-side resolver moved to SkinKitUI (`DeltaSkinThumbstickSide`).
//

import Foundation
import PVCoreBridge

/// Translates DeltaSkin / Manic EMU `info.json` input tokens into the Dolphin
/// bridge's button enums.
///
/// Manic EMU's GameCube and Wii skins (`public.aoshuang.game.ngc` /
/// `public.aoshuang.game.wii`) reuse one generic gamepad vocabulary
/// (`a b x y start select up down left right l1 r1 l2 r2 l3 r3 c z` plus
/// `leftThumbstick*` / `rightThumbstick*`). Those names are *not* the console's
/// own button names, so each system needs an explicit table; `PVGCButton.init(_:)`
/// is tuned for the legacy on-screen controller and mis-maps several of them
/// (`r1` -> R, `l2` -> Z, `r2` -> A by default fall-through).
enum DeltaSkinNintendoHomeConsoleMapping {

    // MARK: - GameCube

    /// Skin token -> GameCube button, or `nil` when the pad has no such control.
    ///
    /// Trigger / shoulder layout (matches Manic EMU's GameCube skins, e.g. the
    /// "GameCube Pocket" skin whose `r1` item draws `btn-z.pdf`, `l2` draws the
    /// left trigger and `r2` the right trigger):
    ///
    /// | Skin token                  | GameCube control                    |
    /// |-----------------------------|-------------------------------------|
    /// | `r1`, `z`                   | Z (digital)                         |
    /// | `l2`, `l1`, `l`, `lt`       | L trigger (analog axis, full press) |
    /// | `r2`, `r`, `rt`             | R trigger (analog axis, full press) |
    /// | `a` `b` `x` `y` `start`     | same-named button                   |
    /// | `up` `down` `left` `right`  | D-pad                               |
    /// | `select`, `l3`, `r3`        | none (GameCube has no such control) |
    ///
    /// The bridge sends L/R as a 0.0/1.0 trigger axis, so a skin tap is a full press.
    static func gameCubeButton(forSkinToken token: String) -> PVGCButton? {
        switch token.lowercased() {
        case "a": return .a
        case "b": return .b
        case "x": return .x
        case "y": return .y
        case "start": return .start
        case "up": return .up
        case "down": return .down
        case "left": return .left
        case "right": return .right
        case "r1", "z": return .z
        case "l2", "l1", "l", "lt": return .l
        case "r2", "r", "rt": return .r
        case "c▲", "cup", "c-up": return .cUp
        case "c▼", "cdown", "c-down": return .cDown
        case "c◀", "cleft", "c-left": return .cLeft
        case "c▶", "cright", "c-right": return .cRight
        default: return nil
        }
    }

    // MARK: - Wii

    /// Skin token -> Wiimote (+ Nunchuk) button, or `nil` when unmapped.
    ///
    /// Mirrors the scheme the Dolphin bridge already applies to a physical
    /// controller (Wiimote + Nunchuk extension is the bridge default), using the
    /// skin's printed labels where they have an obvious Wii counterpart.
    ///
    /// | Skin token                  | Wii control                         |
    /// |-----------------------------|-------------------------------------|
    /// | `a` / `b`                   | Wiimote A / B                       |
    /// | `x` / `y`                   | Wiimote 1 / 2                       |
    /// | `start` / `select`          | Wiimote + / -                       |
    /// | `up` `down` `left` `right`  | Wiimote D-pad                       |
    /// | `l1`, `l2`, `c`             | Nunchuk C                           |
    /// | `r1`, `r2`, `z`             | Nunchuk Z                           |
    /// | `r3`, `home`                | Wiimote Home                        |
    /// | `l3`                        | none                                |
    ///
    /// Classic Controller buttons are deliberately absent. Routing them is Phase 2
    /// work in the Dolphin bridge (`PVDolphinCore+Controls.mm sendWiiButtonInput`
    /// sends any `PVWiiMoteButton` it does not recognise to Home), so until then
    /// the programmatic overlay binds no Classic pad and these tokens stay `nil`.
    ///
    /// Left thumbstick drives the Nunchuk stick (and IR cursor); the right
    /// thumbstick drives Wiimote swing motion (see `analogStickMoved`).
    /// Anything unmapped returns `nil` instead of falling through to the
    /// bridge's default branch, which would press Home.
    static func wiiButton(forSkinToken token: String) -> PVWiiMoteButton? {
        switch token.lowercased() {
        case "a": return .wiiA
        case "b": return .wiiB
        case "x", "1": return .wiiOne
        case "y", "2": return .wiiTwo
        case "start", "+": return .wiiPlus
        case "select", "-": return .wiiMinus
        case "up": return .wiiDPadUp
        case "down": return .wiiDPadDown
        case "left": return .wiiDPadLeft
        case "right": return .wiiDPadRight
        case "l1", "l2", "c": return .nunchukC
        case "r1", "r2", "z": return .nunchukZ
        case "r3", "home": return .wiiHome
        default: return nil
        }
    }
}
