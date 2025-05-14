//
//  PVColecoVisionButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - ColecoVision

@objc public enum PVColecoVisionButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case leftAction
    case rightAction
    @objc(PVColecoVisionButton1)
    case button1
    @objc(PVColecoVisionButton2)
    case button2
    @objc(PVColecoVisionButton3)
    case button3
    @objc(PVColecoVisionButton4)
    case button4
    @objc(PVColecoVisionButton5)
    case button5
    @objc(PVColecoVisionButton6)
    case button6
    @objc(PVColecoVisionButton7)
    case button7
    @objc(PVColecoVisionButton8)
    case button8
    @objc(PVColecoVisionButton9)
    case button9
    @objc(PVColecoVisionButton0)
    case button0
    case asterisk
    case pound
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "leftAction": self = .leftAction
            case "rightAction": self = .rightAction
            case "button1", "1": self = .button1
            case "button2", "2": self = .button2
            case "button3", "3": self = .button3
            case "button4", "4": self = .button4
            case "button5", "5": self = .button5
            case "button6", "6": self = .button6
            case "button7", "7": self = .button7
            case "button8", "8": self = .button8
            case "button9", "9": self = .button9
            case "button0", "0": self = .button0
            case "asterisk", "*": self = .asterisk
            case "pound", "#": self = .pound
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
            case .leftAction:
                return "leftAction"
            case .rightAction:
                return "rightAction"
            case .button1:
                return "1"
            case .button2:
                return "2"
            case .button3:
                return "3"
            case .button4:
                return "4"
            case .button5:
                return "5"
            case .button6:
                return "6"
            case .button7:
                return "7"
            case .button8:
                return "8"
            case .button9:
                return "9"
            case .button0:
                return "0"
            case .asterisk:
                return "*"
            case .pound:
                return "#"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVColecoVisionSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushColecoVisionButton:forPlayer:)
    func didPush(_ button: PVColecoVisionButton, forPlayer player: Int)
    @objc(didReleaseColecoVisionButton:forPlayer:)
    func didRelease(_ button: PVColecoVisionButton, forPlayer player: Int)
}
