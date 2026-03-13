//
//  PVDOSButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - PC DOS

@objc public enum PVDOSButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case fire1
    case fire2
    case select
    case pause
    case reset
    case leftDiff
    case rightDiff
    // Doom-specific controls
    case strafeLeft    // L shoulder → RETRO_DEVICE_ID_JOYPAD_L (Strafe left in PrBoom)
    case strafeRight   // R shoulder → RETRO_DEVICE_ID_JOYPAD_R (Strafe right in PrBoom)
    case run           // X button → RETRO_DEVICE_ID_JOYPAD_X (Speed/Run in PrBoom)
    case weaponNext    // R2 trigger → RETRO_DEVICE_ID_JOYPAD_R2 (Next weapon in PrBoom)
    case weaponPrev    // L2 trigger → RETRO_DEVICE_ID_JOYPAD_L2 (Previous weapon in PrBoom)
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "fire1", "fire 1", "1", "i", "a", "fire", "shoot": self = .fire1
            case "fire2", "fire 2", "2", "ii", "b", "use": self = .fire2
            case "select", "s": self = .select
            case "pause", "p": self = .pause
            case "reset": self = .reset
            case "leftdiff": self = .leftDiff
            case "rightdiff": self = .rightDiff
            // Doom-specific: shoulder / trigger buttons
            case "strafeleft", "sl", "l", "l1": self = .strafeLeft
            case "straferight", "sr", "r", "r1": self = .strafeRight
            case "run", "speed", "shift": self = .run
            case "weaponnext", "wn", "nextweapon", "r2": self = .weaponNext
            case "weaponprev", "wp", "prevweapon", "l2": self = .weaponPrev
            case "count": self = .count
            default: self = .up
        }
    }

    public var stringValue: String {
        switch self {
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .fire1:
                return "1"
            case .fire2:
                return "2"
            case .select:
                return "select"
            case .pause:
                return "pause"
            case .reset:
                return "reset"
            case .leftDiff:
                return "leftdiff"
            case .rightDiff:
                return "rightdiff"
            case .strafeLeft:
                return "strafeleft"
            case .strafeRight:
                return "straferight"
            case .run:
                return "run"
            case .weaponNext:
                return "weaponnext"
            case .weaponPrev:
                return "weaponprev"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVDOSSystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
    @objc(didPushDOSButton:forPlayer:)
    func didPush(_ button: PVDOSButton, forPlayer player: Int)
    @objc(didReleaseDOSButton:forPlayer:)
    func didRelease(_ button: PVDOSButton, forPlayer player: Int)

    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
}
