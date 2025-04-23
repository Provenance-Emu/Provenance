//
//  PVOdyssey2Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Magnavox Odyssey2/Videopac+

@objc public enum PVOdyssey2Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case action
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "action", "a", "i", "1": self = .action
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
            case .action:
                return "action"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVOdyssey2SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushOdyssey2Button:forPlayer:)
    func didPush(_ button: PVOdyssey2Button, forPlayer player: Int)
    @objc(didReleaseOdyssey2Button:forPlayer:)
    func didRelease(_ button: PVOdyssey2Button, forPlayer player: Int)
}
