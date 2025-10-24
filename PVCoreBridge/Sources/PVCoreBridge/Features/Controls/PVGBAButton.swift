//
//  PVGBAButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - Game Boy Advanced

@objc public enum PVGBAButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case l
    case r
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
            case "l": self = .l
            case "r": self = .r
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
            case .l:
                return "l"
            case .r:
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

@objc public protocol PVGBASystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushGBAButton:forPlayer:)
    func didPush(_ button: PVGBAButton, forPlayer player: Int)
    @objc(didReleaseGBAButton:forPlayer:)
    func didRelease(_ button: PVGBAButton, forPlayer player: Int)
}
