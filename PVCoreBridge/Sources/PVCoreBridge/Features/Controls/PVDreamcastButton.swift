//
//  PVDreamcastButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Deamcast

@objc public enum PVDreamcastButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case l
    case r
    case start
    // Joystick
    case analogUp
    case analogDown
    case analogLeft
    case analogRight
    case leftAnalog
    /// Arcade-only: NAOMI / NAOMI 2 / Atomiswave run on the same core and share
    /// this button set, but need a coin/credit input that the Dreamcast pad has
    /// no equivalent for. Harmless for Dreamcast itself (never emitted).
    /// Declared before `count` so `count` stays the last case.
    case coin
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
            case "analogup", "analog-up": self = .analogUp
            case "analogdown", "analog-down": self = .analogDown
            case "analogleft", "analog-left": self = .analogLeft
            case "analogright", "analog-right": self = .analogRight
            case "leftanalog", "left-analog": self = .leftAnalog
            case "coin", "insertcoin", "insert_coin", "insert coin", "credit": self = .coin
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
            case .x:
                return "x"
            case .y:
                return "y"
            case .l:
                return "l"
            case .r:
                return "r"
            case .start:
                return "start"
            case .analogUp:
                return "analogup"
            case .analogDown:
                return "analogdown"
            case .analogLeft:
                return "analogleft"
            case .analogRight:
                return "analogRight"
            case .leftAnalog:
                return "leftAnalog"
            case .coin:
                return "coin"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVDreamcastSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushDreamcastButton:forPlayer:)
    func didPush(_ button: PVDreamcastButton, forPlayer player: Int)
    @objc(didReleaseDreamcastButton:forPlayer:)
    func didRelease(_ button: PVDreamcastButton, forPlayer player: Int)

    @objc(didMoveDreamcastJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVDreamcastButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
}
