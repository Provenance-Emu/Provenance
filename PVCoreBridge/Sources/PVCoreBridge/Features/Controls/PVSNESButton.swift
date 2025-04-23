//
//  PVSNESButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - SNES

@objc public enum PVSNESButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case triggerLeft
    case triggerRight
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
            case "triggerLeft", "l": self = .triggerLeft
            case "triggerRight", "r": self = .triggerRight
            case "start": self = .start
            case "select": self = .select
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
            case .triggerLeft:
                return "l"
            case .triggerRight:
                return "r"
            case .start:
                return "start"
            case .select:
                return "select"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVSNESSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSNESButton:forPlayer:)
    func didPush(_ button: PVSNESButton, forPlayer player: Int)
    @objc(didReleaseSNESButton:forPlayer:)
    func didRelease(_ button: PVSNESButton, forPlayer player: Int)
}
