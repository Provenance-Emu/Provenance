//
//  PVN64Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//



// MARK: - N64

@objc public enum PVN64Button: Int, EmulatorCoreButton {
    // D-Pad
    case dPadUp
    case dPadDown
    case dPadLeft
    case dPadRight
    // C buttons
    case cUp
    case cDown
    case cLeft
    case cRight
    case a
    case b
    // Shoulder buttons
    case l
    case r
    case z
    case start
    case analogUp
    case analogDown
    case analogLeft
    case analogRight
    case leftAnalog
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .dPadUp
            case "down": self = .dPadDown
            case "left": self = .dPadLeft
            case "right": self = .dPadRight
            case "c▲", "cup", "c-up": self = .cUp
            case "c▼", "cdown", "c-down": self = .cDown
            case "c◀", "cleft", "c-left": self = .cLeft
            case "c▶", "cright", "c-right": self = .cRight
            case "a": self = .a
            case "b": self = .b
            case "l": self = .l
            case "r": self = .r
            case "z", "x": self = .z
            case "start": self = .start
            case "analog-up", "analogup": self = .analogUp
            case "analog-down", "analogdown": self = .analogDown
            case "analog-left", "analogleft": self = .analogLeft
            case "analog-right", "analogright": self = .analogRight
            case "left-analog", "leftanalog": self = .leftAnalog
            case "count": self = .count
            default: self = .dPadUp
        }
    }

    public var stringValue: String {
        switch self {
            case .dPadUp:
                return "up"
            case .dPadDown:
                return "down"
            case .dPadLeft:
                return "left"
            case .dPadRight:
                return "right"
            case .cUp:
                return "c▲"
            case .cDown:
                return "c▼"
            case .cLeft:
                return "c◀"
            case .cRight:
                return "c▶"
            case .a:
                return "a"
            case .b:
                return "b"
            case .l:
                return "l"
            case .r:
                return "r"
            case .z:
                return "z"
            case .start:
                return "start"
            case .analogUp:
                return "analog-up"
            case .analogDown:
                return "analog-down"
            case .analogLeft:
                return "analog-left"
            case .analogRight:
                return "analog-right"
            case .leftAnalog:
                return "left-analog"
            case .count:
                return "count"
        }
    }
}

// FIXME: analog stick (x,y), memory pack, rumble pack
@objc public protocol PVN64SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveN64JoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
    @objc(didPushN64Button:forPlayer:)
    func didPush(_ button: PVN64Button, forPlayer player: Int)
    @objc(didReleaseN64Button:forPlayer:)
    func didRelease(_ button: PVN64Button, forPlayer player: Int)
}
