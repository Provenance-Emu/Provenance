//
//  PVTIC80Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 3/28/26.
//

// MARK: - TIC-80

/// Button enumeration for the TIC-80 fantasy computer.
/// TIC-80 uses a standard 8-button gamepad: D-Pad + A/B/X/Y + L/R shoulders + Start/Select.
@objc public enum PVTIC80Button: Int, EmulatorCoreButton {
    case up = 0
    case down
    case left
    case right
    case a       // RETRO_DEVICE_ID_JOYPAD_A  → GCController buttonB (east)
    case b       // RETRO_DEVICE_ID_JOYPAD_B  → GCController buttonA (south)
    case x       // RETRO_DEVICE_ID_JOYPAD_X  → GCController buttonY (north)
    case y       // RETRO_DEVICE_ID_JOYPAD_Y  → GCController buttonX (west)
    case l       // RETRO_DEVICE_ID_JOYPAD_L  → left shoulder
    case r       // RETRO_DEVICE_ID_JOYPAD_R  → right shoulder
    case start
    case select
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a": self = .a
            case "b": self = .b
            case "x": self = .x
            case "y": self = .y
            case "l", "l1": self = .l
            case "r", "r1": self = .r
            case "start": self = .start
            case "select": self = .select
            case "count": self = .count
            default: self = .b
        }
    }

    public var stringValue: String {
        switch self {
            case .up: return "up"
            case .down: return "down"
            case .left: return "left"
            case .right: return "right"
            case .a: return "a"
            case .b: return "b"
            case .x: return "x"
            case .y: return "y"
            case .l: return "l"
            case .r: return "r"
            case .start: return "start"
            case .select: return "select"
            case .count: return "count"
        }
    }
}

@objc public protocol PVTIC80SystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder {
    @objc(didPushTIC80Button:forPlayer:)
    func didPush(_ button: PVTIC80Button, forPlayer player: Int)
    @objc(didReleaseTIC80Button:forPlayer:)
    func didRelease(_ button: PVTIC80Button, forPlayer player: Int)
}
