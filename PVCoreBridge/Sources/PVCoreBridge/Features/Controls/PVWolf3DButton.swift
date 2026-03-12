//
//  PVWolf3DButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 3/12/26.
//

// MARK: - Wolf3D (ECWolf / Wolf4SDL)

/// Button enum for Wolfenstein 3D via the ECWolf RetroArch core.
///
/// libretro button mapping (ecwolf):
///   JOYPAD_B (south/buttonA)   → Fire
///   JOYPAD_A (east/buttonB)    → Open / Use
///   JOYPAD_Y (west/buttonX)    → Strafe On (toggle strafe)
///   JOYPAD_X (north/buttonY)   → Run / Speed
///   JOYPAD_L (leftShoulder)    → Strafe Left
///   JOYPAD_R (rightShoulder)   → Strafe Right
///   JOYPAD_L2 (leftTrigger)    → Previous Weapon
///   JOYPAD_R2 (rightTrigger)   → Next Weapon
///   JOYPAD_SELECT (buttonOptions) → Automap
///   JOYPAD_START (buttonMenu)  → Menu / Pause
@objc public enum PVWolf3DButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    /// Fire / Shoot — JOYPAD_B → south/buttonA
    case fire
    /// Open door / Use — JOYPAD_A → east/buttonB
    case open
    /// Strafe On (hold) — JOYPAD_Y → west/buttonX
    case strafeOn
    /// Run / Speed — JOYPAD_X → north/buttonY
    case run
    /// Strafe Left — JOYPAD_L → leftShoulder
    case strafeLeft
    /// Strafe Right — JOYPAD_R → rightShoulder
    case strafeRight
    /// Previous Weapon — JOYPAD_L2 → leftTrigger
    case weaponPrev
    /// Next Weapon — JOYPAD_R2 → rightTrigger
    case weaponNext
    /// Automap — JOYPAD_SELECT → buttonOptions
    case map
    /// Menu / Pause — JOYPAD_START → buttonMenu
    case menu
    case count

    public init(_ value: String) {
        switch value.lowercased() {
        case "up": self = .up
        case "down": self = .down
        case "left": self = .left
        case "right": self = .right
        case "fire", "shoot", "1": self = .fire
        case "open", "use", "2": self = .open
        case "strafeon", "strafe": self = .strafeOn
        case "run", "speed": self = .run
        case "strafeleft", "sl", "l", "l1": self = .strafeLeft
        case "straferight", "sr", "r", "r1": self = .strafeRight
        case "weaponprev", "wp", "prevweapon", "l2": self = .weaponPrev
        case "weaponnext", "wn", "nextweapon", "r2": self = .weaponNext
        case "map", "automap", "select": self = .map
        case "menu", "pause", "start": self = .menu
        case "count": self = .count
        default: self = .up
        }
    }

    public var stringValue: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        case .fire: return "fire"
        case .open: return "open"
        case .strafeOn: return "strafeon"
        case .run: return "run"
        case .strafeLeft: return "strafeleft"
        case .strafeRight: return "straferight"
        case .weaponPrev: return "weaponprev"
        case .weaponNext: return "weaponnext"
        case .map: return "map"
        case .menu: return "menu"
        case .count: return "count"
        }
    }
}

@objc public protocol PVWolf3DSystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
    @objc(didPushWolf3DButton:forPlayer:)
    func didPush(_ button: PVWolf3DButton, forPlayer player: Int)
    @objc(didReleaseWolf3DButton:forPlayer:)
    func didRelease(_ button: PVWolf3DButton, forPlayer player: Int)

    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
}
