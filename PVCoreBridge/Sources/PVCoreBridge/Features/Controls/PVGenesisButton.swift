//
//  PVGenesisButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//



// MARK: - Genesis

@objc public enum PVGenesisButton: Int, EmulatorCoreButton {
    case b = 0
    case a
    case mode
    case start
    case up
    case down
    case left
    case right
    case c
    case y
    case x
    case z
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "b": self = .b
            case "a": self = .a
            case "mode": self = .mode
            case "start": self = .start
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "c": self = .c
            case "y": self = .y
            case "x": self = .x
            case "z": self = .z
            case "count": self = .count
            default: self = .b
        }
    }

    public var stringValue: String {
        switch self {
            case .b:
                return "b"
            case .a:
                return "a"
            case .mode:
                return "mode"
            case .start:
                return "start"
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .c:
                return "c"
            case .y:
                return "y"
            case .x:
                return "x"
            case .z:
                return "z"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVGenesisSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushGenesisButton:forPlayer:)
    func didPush(_ button: PVGenesisButton, forPlayer player: Int)
    @objc(didReleaseGenesisButton:forPlayer:)
    func didRelease(_ button: PVGenesisButton, forPlayer player: Int)
}
