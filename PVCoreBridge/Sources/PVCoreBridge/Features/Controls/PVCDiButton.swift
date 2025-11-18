//
//  PVCDiButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//



// MARK: - CDi

@objc public enum PVCDiButton: Int, EmulatorCoreButton {
    case button1 = 0
    case button2
    case button3
    case up
    case down
    case left
    case right
    case reset
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "i", "1", "b", "button1": self = .button1
            case "ii", "2", "a", "button2": self = .button2
            case "iii", "3", "x", "button3": self = .button3
            case "start", "reset": self = .reset
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "count": self = .count
            default: self = .button1
        }
    }

    public var stringValue: String {
        switch self {
            case .button1:
                return "i"
            case .button2:
                return "ii"
            case .button3:
                return "iii"
            case .up:
                return "up"
            case .down:
                return "down"
            case .left:
                return "left"
            case .right:
                return "right"
            case .reset:
                return "reset"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVCDiSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushCDiButton:forPlayer:)
    func didPush(_ button: PVCDiButton, forPlayer player: Int)
    @objc(didReleaseCDiButton:forPlayer:)
    func didRelease(_ button: PVCDiButton, forPlayer player: Int)
}
