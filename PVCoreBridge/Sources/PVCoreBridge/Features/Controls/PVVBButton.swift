//
//  PVVBButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - VirtualBoy

@objc public enum PVVBButton: Int, EmulatorCoreButton  {
    case leftUp
    case leftDown
    case leftLeft
    case leftRight
    case rightUp
    case rightDown
    case rightLeft
    case rightRight
    case l
    case r
    case a
    case b
    case start
    case select
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "leftUp", "up": self = .leftUp
            case "leftDown", "down": self = .leftDown
            case "leftLeft", "left": self = .leftLeft
            case "leftRight", "right": self = .leftRight
            case "rightUp": self = .rightUp
            case "rightDown": self = .rightDown
            case "rightLeft": self = .rightLeft
            case "rightRight": self = .rightRight
            case "l": self = .l
            case "r": self = .r
            case "a": self = .a
            case "b": self = .b
            case "start": self = .start
            case "select": self = .select
            case "count": self = .count
            default: self = .leftUp
        }
    }

    public var stringValue: String {
        switch self {
            case .leftUp:
                return "up"
            case .leftDown:
                return "down"
            case .leftLeft:
                return "left"
            case .leftRight:
                return "right"
            case .rightUp:
                return "rightUp"
            case .rightDown:
                return "rightDown"
            case .rightLeft:
                return "rightLeft"
            case .rightRight:
                return "rightRight"
            case .l:
                return "l"
            case .r:
                return "r"
            case .a:
                return "a"
            case .b:
                return "b"
            case .start:
                return "start"
            case .select:
                return "select"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVVirtualBoySystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushVBButton:forPlayer:)
    func didPush(_ button: PVVBButton, forPlayer player: Int)
    @objc(didReleaseVBButton:forPlayer:)
    func didRelease(_ button: PVVBButton, forPlayer player: Int)
}
