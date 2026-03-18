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
    case optionKey
    case selectKey
    case startKey
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "fire", "a", "b", "x", "y": self = .fire
            case "option", "optionkey": self = .optionKey
            case "select", "selectkey": self = .selectKey
            case "start", "startkey": self = .startKey
            default: self = .count
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
            case .optionKey:
                return "option"
            case .selectKey:
                return "select"
            case .startKey:
                return "start"
            case .count:
                return "count"
        }
    }
}

// MARK: - Hardware switches

extension PVA8Button: HardwareSwitchProvider {
    public static var hardwareSwitches: [HardwareSwitchDescriptor]? {
        [
            HardwareSwitchDescriptor(
                id: "option_key",
                title: "OPTION",
                offPosition: HardwareSwitchPosition(label: "OFF", buttonId: "option"),
                onPosition:  HardwareSwitchPosition(label: "ON", buttonId: "option"),
                defaultState: false
            ),
            HardwareSwitchDescriptor(
                id: "select_key",
                title: "SELECT",
                offPosition: HardwareSwitchPosition(label: "OFF", buttonId: "select"),
                onPosition:  HardwareSwitchPosition(label: "ON", buttonId: "select"),
                defaultState: false
            ),
            HardwareSwitchDescriptor(
                id: "start_key",
                title: "START",
                offPosition: HardwareSwitchPosition(label: "OFF", buttonId: "start"),
                onPosition:  HardwareSwitchPosition(label: "ON", buttonId: "start"),
                defaultState: false
            )
        ]
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
