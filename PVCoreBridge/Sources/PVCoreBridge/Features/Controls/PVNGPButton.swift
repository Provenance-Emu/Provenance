//
//  PVNGPButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Neo Geo Pocket + Color

@objc public enum PVNGPButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case a
    case b
    case option
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "a", "i", "1": self = .a
            case "b", "ii", "2": self = .b
            case "option": self = .option
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
            case .option:
                return "option"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVNeoGeoPocketSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushNGPButton:forPlayer:)
    func didPush(_ button: PVNGPButton, forPlayer player: Int)
    @objc(didReleaseNGPButton:forPlayer:)
    func didRelease(_ button: PVNGPButton, forPlayer player: Int)
}
