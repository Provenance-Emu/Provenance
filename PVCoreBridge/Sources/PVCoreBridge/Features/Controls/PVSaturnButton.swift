//
//  PVSaturnButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Sega Saturn

@objc public enum PVSaturnButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case x
    case y
    case z
    case l
    case r
    case start
    case leftAnalog
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a": self = .a
            case "b": self = .b
            case "c": self = .c
            case "x": self = .x
            case "y": self = .y
            case "z": self = .z
            case "l": self = .l
            case "r": self = .r
            case "start": self = .start
            case "leftAnalog": self = .leftAnalog
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
            case .a:
                return "a"
            case .b:
                return "b"
            case .c:
                return "c"
            case .x:
                return "x"
            case .y:
                return "y"
            case .z:
                return "z"
            case .l:
                return "l"
            case .r:
                return "r"
            case .start:
                return "start"
            case .leftAnalog:
                return "leftAnalog"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVSaturnSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushSSButton:forPlayer:)
    func didPush(_ button: PVSaturnButton, forPlayer player: Int)
    @objc(didReleaseSSButton:forPlayer:)
    func didRelease(_ button: PVSaturnButton, forPlayer player: Int)
    @objc(didMoveSaturnJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}
