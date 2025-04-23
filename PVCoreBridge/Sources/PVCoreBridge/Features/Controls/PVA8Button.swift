//
//  PVA8Button.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


@objc public enum PVA8Button: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case fire
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "fire": self = .fire
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
            case .fire:
                return "fire"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVA8SystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
    func rightMouseDown(at point: CGPoint)
    func rightMouseUp()
    @objc(didPushA8Button:forPlayer:)
    func didPush(_ button: PVA8Button, forPlayer player: Int)
    @objc(didReleaseA8Button:forPlayer:)
    func didRelease(_ button: PVA8Button, forPlayer player: Int)
}
