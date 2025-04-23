//
//  PVPMButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Pokemon Mini

@objc public enum PVPMButton: Int, EmulatorCoreButton {
    case menu
    case a
    case b
    case c
    case up
    case down
    case left
    case right
    case power
    case shake

    public init(_ value: String) {
        switch value.lowercased() {
            case "menu": self = .menu
            case "a": self = .a
            case "b": self = .b
            case "c": self = .c
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "power": self = .power
            case "shake": self = .shake
            default: self = .menu
        }
    }

    public var stringValue: String {
        switch self {
            case .menu:
                return "menu"
            case .a:
                return "a"
            case .b:
                return "b"
            case .c:
                return "c"
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .power:
                return "power"
            case .shake:
                return "shake"
        }
    }
}

@objc public protocol PVPokeMiniSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPMButton:forPlayer:)
    func didPush(_ button: PVPMButton, forPlayer player: Int)
    @objc(didReleasePMButton:forPlayer:)
    func didRelease(_ button: PVPMButton, forPlayer player: Int)
}
