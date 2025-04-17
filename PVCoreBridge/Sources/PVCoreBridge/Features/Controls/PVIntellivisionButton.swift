//
//  PVIntellivisionButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Intellivision

@objc public enum PVIntellivisionButton: Int, EmulatorCoreButton {
    case up
    case down
    case left
    case right
    case topAction
    case bottomLeftAction
    case bottomRightAction
    @objc(PVIntellivisionButton1)
    case button1
    @objc(PVIntellivisionButton2)
    case button2
    @objc(PVIntellivisionButton3)
    case button3
    @objc(PVIntellivisionButton4)
    case button4
    @objc(PVIntellivisionButton5)
    case button5
    @objc(PVIntellivisionButton6)
    case button6
    @objc(PVIntellivisionButton7)
    case button7
    @objc(PVIntellivisionButton8)
    case button8
    @objc(PVIntellivisionButton9)
    case button9
    @objc(PVIntellivisionButton0)
    case button0
    @objc(PVIntellivisionButtonClear)
    case clear
    @objc(PVIntellivisionButtonEnter)
    case enter
    @objc(PVIntellivisionButtonCount)
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "up": self = .up
            case "down": self = .down
            case "left": self = .left
            case "right": self = .right
            case "topAction": self = .topAction
            case "bottomLeftAction": self = .bottomLeftAction
            case "bottomRightAction": self = .bottomRightAction
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
            case "clear": self = .clear
            case "enter": self = .enter
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
            case .topAction:
                return "topAction"
            case .bottomLeftAction:
                return "bottomLeftAction"
            case .bottomRightAction:
                return "bottomRightAction"
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
            case .clear:
                return "clear"
            case .enter:
                return "enter"
            case .count:
                return "count"
        }
    }
}

@objc public protocol PVIntellivisionSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushIntellivisionButton:forPlayer:)
    func didPush(_ button: PVIntellivisionButton, forPlayer player: Int)
    @objc(didReleaseIntellivisionButton:forPlayer:)
    func didRelease(_ button: PVIntellivisionButton, forPlayer player: Int)
}
