//
//  PVDoomButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 3/12/26.
//

// MARK: - Doom / PrBoom (com.provenance.doom)

/// Button enum for Doom via the PrBoom RetroArch core.
///
/// PrBoom libretro Gamepad Classic (default) button mapping (RETRO_DEVICE_ID_JOYPAD_*):
///   JOYPAD_A (east/buttonB)     → Fire / Shoot
///   JOYPAD_B (south/buttonA)    → Use / Interact / Open door
///   JOYPAD_Y (west/buttonX)     → Run / Speed
///   JOYPAD_X (north/buttonY)    → Strafe (toggle)
///   JOYPAD_L (leftShoulder)     → Strafe Left
///   JOYPAD_R (rightShoulder)    → Strafe Right
///   JOYPAD_L2 (leftTrigger)     → Previous Weapon
///   JOYPAD_R2 (rightTrigger)    → Next Weapon
///   JOYPAD_SELECT (buttonOptions) → Automap / Map
///   JOYPAD_START (buttonMenu)   → Pause / Menu
@objc public enum PVDoomButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    /// Fire / Shoot — JOYPAD_A → east/buttonB
    case fire
    /// Use / Interact / Open door — JOYPAD_B → south/buttonA
    case use
    /// Run / Speed — JOYPAD_Y → west/buttonX
    case run
    /// Strafe Left — JOYPAD_L → leftShoulder
    case strafeLeft
    /// Strafe Right — JOYPAD_R → rightShoulder
    case strafeRight
    /// Previous Weapon — JOYPAD_L2 → leftTrigger
    case weaponPrev
    /// Next Weapon — JOYPAD_R2 → rightTrigger
    case weaponNext
    /// Automap / Map — JOYPAD_SELECT → buttonOptions
    case map
    /// Pause / Menu — JOYPAD_START → buttonMenu
    case pause
    case count

    public init(_ value: String) {
        switch value.lowercased() {
        case "up": self = .up
        case "down": self = .down
        case "left": self = .left
        case "right": self = .right
        case "fire", "fire1", "shoot", "1", "a": self = .fire
        case "use", "fire2", "interact", "open", "2", "b": self = .use
        case "run", "speed", "shift", "y": self = .run
        case "strafeleft", "sl", "l", "l1": self = .strafeLeft
        case "straferight", "sr", "r", "r1": self = .strafeRight
        case "weaponprev", "wp", "prevweapon", "l2", "prev": self = .weaponPrev
        case "weaponnext", "wn", "nextweapon", "r2", "next": self = .weaponNext
        case "map", "automap", "select", "x": self = .map
        case "pause", "start", "menu": self = .pause
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
        case .use: return "use"
        case .run: return "run"
        case .strafeLeft: return "strafeleft"
        case .strafeRight: return "straferight"
        case .weaponPrev: return "weaponprev"
        case .weaponNext: return "weaponnext"
        case .map: return "map"
        case .pause: return "pause"
        case .count: return "count"
        }
    }
}

extension PVDoomButton {
    /// Maps a Doom button to its equivalent PVDOSButton for forwarding through the DOS bridge.
    public var asDOSButton: PVDOSButton {
        switch self {
        case .up:         return .up
        case .down:       return .down
        case .left:       return .left
        case .right:      return .right
        case .fire:       return .fire1
        case .use:        return .fire2
        case .run:        return .run
        case .strafeLeft:  return .strafeLeft
        case .strafeRight: return .strafeRight
        case .weaponPrev: return .weaponPrev
        case .weaponNext: return .weaponNext
        case .map:        return .select
        case .pause:      return .pause
        case .count:      return .count
        }
    }
}

@objc public protocol PVDoomSystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
    @objc(didPushDoomButton:forPlayer:)
    func didPush(_ button: PVDoomButton, forPlayer player: Int)
    @objc(didReleaseDoomButton:forPlayer:)
    func didRelease(_ button: PVDoomButton, forPlayer player: Int)

    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
}
