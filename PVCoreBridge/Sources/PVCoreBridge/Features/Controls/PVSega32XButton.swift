//
//  PVSega32XButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - Sega 32X

@objc public enum PVSega32XButton: Int, EmulatorCoreButton {
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
    case start
    case mode
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
            case "start": self = .start
            case "mode": self = .mode
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
            case .start:
                return "start"
            case .mode:
                return "mode"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVSega32XSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSega32XButton:forPlayer:)
    func didPush(_ button: PVSega32XButton, forPlayer player: Int)
    @objc(didReleaseSega32XButton:forPlayer:)
    func didRelease(_ button: PVSega32XButton, forPlayer player: Int)
}
