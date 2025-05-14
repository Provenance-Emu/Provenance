//
//  PVDSButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - Game Boy DS

@objc public enum PVDSButton: Int, EmulatorCoreButton {
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
    case select
    case screenSwap
    case rotate
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
            case "l": self = .l
            case "r": self = .r
            case "start": self = .start
            case "select": self = .select
            case "screenSwap", "ss", "swap": self = .screenSwap
            case "rotate": self = .rotate
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
            case .select:
                return "select"
            case .screenSwap:
                return "swap"
            case .rotate:
                return "rotate"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVDSSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushDSButton:forPlayer:)
    func didPush(_ button: PVDSButton, forPlayer player: Int)
    @objc(didReleaseDSButton:forPlayer:)
    func didRelease(_ button: PVDSButton, forPlayer player: Int)
}
