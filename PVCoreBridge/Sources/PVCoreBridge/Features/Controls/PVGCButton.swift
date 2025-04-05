//
//  PVGCButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - GameCube

@objc public enum PVGCButton: Int, EmulatorCoreButton {
	// D-Pad
	case up
	case down
    case left
	case right
    @objc(PVGCAnalogUp)
    case analogUp
    @objc(PVGCAnalogDown)
    case analogDown
    @objc(PVGCAnalogLeft)
    case analogLeft
    @objc(PVGCAnalogRight)
    case analogRight
	// C buttons
    @objc(PVGCAnalogCUp)
	case analogCUp
    @objc(PVGCAnalogCDown)
	case analogCDown
    @objc(PVGCAnalogCLeft)
	case analogCLeft
    @objc(PVGCAnalogCRight)
	case analogCRight
	case a
	case b
    case x
    case y
	// Shoulder buttons
	case l
	case r
	case z
	case start
    @objc(PVGCDigitalL)
    case digitalL
    @objc(PVGCDigitalR)
    case digitalR
	case count
    case cUp
    case cDown
    case cLeft
    case cRight
    @objc(PVGCLeftAnalog)
    case leftAnalog
    @objc(PVGCRightAnalog)
    case rightAnalog

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
            case "z": self = .z
            case "start": self = .start
            case "digitall", "dl": self = .digitalL
            case "digitalr", "dr": self = .digitalR
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
            case .z:
                return "z"
            case .start:
                return "start"
            case .digitalL:
                return "digitall"
            case .digitalR:
                return "digitalr"
            case .count:
                return "count"
        }
    }
}

// FIXME: analog stick (x,y), memory pack, rumble pack
@objc public protocol PVGameCubeSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveGameCubeJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVGCButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
	@objc(didPushGameCubeButton:forPlayer:)
	func didPush(_ button: PVGCButton, forPlayer player: Int)
	@objc(didReleaseGameCubeButton:forPlayer:)
	func didRelease(_ button: PVGCButton, forPlayer player: Int)
}
