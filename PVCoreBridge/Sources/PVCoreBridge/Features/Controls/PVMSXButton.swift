//
//  PVMSXButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - MSX

@objc public enum PVMSXButton: Int, EmulatorCoreButton {
	case up
	case down
	case left
	case right
	case fire1
	case fire2
	case select
	case pause
	case reset
	case leftDiff
	case rightDiff
	case count

	public init(_ value: String) {
		switch value.lowercased() {
			case "up": self = .up
			case "down": self = .down
			case "left": self = .left
			case "right": self = .right
			case "fire1", "1", "i": self = .fire1
			case "fire2", "2", "ii": self = .fire2
			case "select", "s": self = .select
			case "pause", "p": self = .pause
			case "reset", "r": self = .reset
			case "leftDiff", "l": self = .leftDiff
			case "rightDiff": self = .rightDiff
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
			case .fire1:
				return "1"
			case .fire2:
				return "2"
			case .select:
				return "select"
			case .pause:
				return "pause"
			case .reset:
				return "reset"
			case .leftDiff:
				return "leftDiff"
			case .rightDiff:
				return "rightDiff"
			case .count:
				return "count"
		}
	}
}

@objc public protocol PVMSXSystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
	@objc(didPushMSXButton:forPlayer:)
	func didPush(_ button: PVMSXButton, forPlayer player: Int)
	@objc(didReleaseMSXButton:forPlayer:)
	func didRelease(_ button: PVMSXButton, forPlayer player: Int)

	func mouseMoved(at point: CGPoint)
	func leftMouseDown(at point: CGPoint)
	func leftMouseUp()
}
