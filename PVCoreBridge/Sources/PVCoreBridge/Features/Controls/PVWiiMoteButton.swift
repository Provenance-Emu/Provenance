//
//  PVWiiMoteButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//


// MARK: - Wii

@objc public enum PVWiiMoteButton: Int, EmulatorCoreButton {
    // D-Pad
    case wiiDPadUp
    case wiiDPadDown
    case wiiDPadLeft
    case wiiDPadRight
    // wiimote buttons
    case wiiA
    case wiiB
    case wiiMinus
    case wiiPlus
    case wiiHome
    case wiiOne
    case wiiTwo
    // wiimote motion
    case wiiIrUp
    case wiiIrDown
    case wiiIrLeft
    case wiiIrRight
    case wiiIrForward
    case wiiIrBackward
    case wiiIrHide
    case wiiSwingUp
    case wiiSwingDown
    case wiiSwingLeft
    case wiiSwingRight
    case wiiTiltForward
    case wiiTiltBackward
    case wiiTiltLeft
    case wiiTiltRight
    case wiiTiltModifier
    case wiiShakeX
    case wiiShakeY
    case wiiShakeZ
    // nunchuk
    case nunchukC
    case nunchukZ
    case nunchukStickUp
    case nunchukStickDown
    case nunchukStickLeft
    case nunchukStickRight
    case nunchukSwingUp
    case nunchukSwingDown
    case nunchukSwingLeft
    case nunchukSwingRight
    case nunchukTiltForward
    case nunchukTiltBackward
    case nunchukTiltLeft
    case nunchukTiltRight
    case nunchukTiltModifier
    case nunchukShakeX
    case nunchukShakeY
    case nunchukShakeZ
    // classic
    case classicA
    case classicB
    case classicX
    case classicY
    case classicMinus
    case classicPlus
    case classicHome
    case classicZL
    case classicZR
    case classicDpadUp
    case classicDpadDown
    case classicDpadLeft
    case classicDpadRight
    case classicStickLeftUp
    case classicStickLeftDown
    case classicStickLeftLeft
    case classicStickLeftRight
    case classicStickRightUp
    case classicStickRightDown
    case classicStickRightLeft
    case classicStickRightRight
    case classicTriggerL
    case classicTriggerR
    case start
    case select
    case leftAnalog
    case rightAnalog
    case count

    public init(_ value: String) {
        switch value.lowercased() {
            case "wiiDPadUp", "up": self = .wiiDPadUp
            case "wiiDPadDown", "down": self = .wiiDPadDown
            case "wiiDPadLeft", "left": self = .wiiDPadLeft
            case "wiiDPadRight", "right": self = .wiiDPadRight
            case "wiiA", "a": self = .wiiA
            case "wiiB", "b": self = .wiiB
            case "wiiMinus", "-": self = .wiiMinus
            case "wiiPlus", "+": self = .wiiPlus
            case "wiiHome", "home": self = .wiiHome
            case "wiiOne", "1": self = .wiiOne
            case "wiiTwo", "2": self = .wiiTwo
            case "wiiIrUp", "irUp": self = .wiiIrUp
            case "wiiIrDown", "irDown": self = .wiiIrDown
            case "wiiIrLeft", "irLeft": self = .wiiIrLeft
            case "wiiIrRight", "irRight": self = .wiiIrRight
            case "wiiIrForward", "irForward": self = .wiiIrForward
            case "wiiIrBackward", "irBackward": self = .wiiIrBackward
            case "wiiIrHide", "irHide": self = .wiiIrHide
            case "wiiSwingUp", "swingUp": self = .wiiSwingUp
            case "wiiSwingDown", "swingDown": self = .wiiSwingDown
            case "wiiSwingLeft", "swingLeft": self = .wiiSwingLeft
            case "wiiSwingRight", "swingRight": self = .wiiSwingRight
            case "wiiTiltForward", "tiltForward": self = .wiiTiltForward
            case "wiiTiltBackward", "tiltBackward": self = .wiiTiltBackward
            case "wiiTiltLeft", "tiltLeft": self = .wiiTiltLeft
            case "wiiTiltRight", "tiltRight": self = .wiiTiltRight
            case "wiiTiltModifier", "tiltModifier": self = .wiiTiltModifier
            case "wiiShakeX", "shakeX": self = .wiiShakeX
            case "wiiShakeY", "shakeY": self = .wiiShakeY
            case "wiiShakeZ", "shakeZ": self = .wiiShakeZ
            case "nunchukC", "c": self = .nunchukC
            case "nunchukZ", "z": self = .nunchukZ
            case "nunchukStickUp", "stickUp": self = .nunchukStickUp
            case "nunchukStickDown", "stickDown": self = .nunchukStickDown
            case "nunchukStickLeft", "stickLeft": self = .nunchukStickLeft
            case "nunchukStickRight", "stickRight": self = .nunchukStickRight
            case "nunchukSwingUp", "swingUp": self = .nunchukSwingUp
            case "nunchukSwingDown", "swingDown": self = .nunchukSwingDown
            case "nunchukSwingLeft", "swingLeft": self = .nunchukSwingLeft
            case "nunchukSwingRight", "swingRight": self = .nunchukSwingRight
            case "nunchukTiltForward", "tiltForward": self = .nunchukTiltForward
            case "nunchukTiltBackward", "tiltBackward": self = .nunchukTiltBackward
            case "nunchukTiltLeft", "tiltLeft": self = .nunchukTiltLeft
            case "nunchukTiltRight", "tiltRight": self = .nunchukTiltRight
            case "nunchukTiltModifier", "tiltModifier": self = .nunchukTiltModifier
            case "nunchukShakeX", "shakeX": self = .nunchukShakeX
            case "nunchukShakeY", "shakeY": self = .nunchukShakeY
            case "nunchukShakeZ", "shakeZ": self = .nunchukShakeZ
            case "classicA", "a": self = .classicA
            case "classicB", "b": self = .classicB
            case "classicX", "x": self = .classicX
            case "classicY", "y": self = .classicY
            case "classicMinus", "-": self = .classicMinus
            case "classicPlus", "+": self = .classicPlus
            case "classicHome", "home": self = .classicHome
            case "classicZL", "zl": self = .classicZL
            case "classicZR", "zr": self = .classicZR
            case "classicDpadUp", "dpadUp": self = .classicDpadUp
            case "classicDpadDown", "dpadDown": self = .classicDpadDown
            case "classicDpadLeft", "dpadLeft": self = .classicDpadLeft
            case "classicDpadRight", "dpadRight": self = .classicDpadRight
            case "classicStickLeftUp", "stickLeftUp": self = .classicStickLeftUp
            case "classicStickLeftDown", "stickLeftDown": self = .classicStickLeftDown
            case "classicStickLeftLeft", "stickLeftLeft": self = .classicStickLeftLeft
            case "classicStickLeftRight", "stickLeftRight": self = .classicStickLeftRight
            case "classicStickRightUp", "stickRightUp": self = .classicStickRightUp
            case "classicStickRightDown", "stickRightDown": self = .classicStickRightDown
            case "classicStickRightLeft", "stickRightLeft": self = .classicStickRightLeft
            case "classicStickRightRight", "stickRightRight": self = .classicStickRightRight
            case "classicTriggerL", "triggerL": self = .classicTriggerL
            case "classicTriggerR", "triggerR": self = .classicTriggerR
            case "start": self = .start
            case "select": self = .select
            case "leftAnalog": self = .leftAnalog
            case "rightAnalog": self = .rightAnalog
            case "count": self = .count
            default: self = .wiiDPadUp
        }
    }

    public var stringValue: String {
        switch self {
            case .wiiDPadUp: return "up"
            case .wiiDPadDown: return "down"
            case .wiiDPadLeft: return "left"
            case .wiiDPadRight: return "right"
            case .wiiA: return "a"
            case .wiiB: return "b"
            case .wiiMinus: return "-"
            case .wiiPlus: return "+"
            case .wiiHome: return "home"
            case .wiiOne: return "1"
            case .wiiTwo: return "2"
            case .wiiIrUp: return "irUp"
            case .wiiIrDown: return "irDown"
            case .wiiIrLeft: return "irLeft"
            case .wiiIrRight: return "irRight"
            case .wiiIrForward: return "irForward"
            case .wiiIrBackward: return "irBackward"
            case .wiiIrHide: return "irHide"
            case .wiiSwingUp: return "swingUp"
            case .wiiSwingDown: return "swingDown"
            case .wiiSwingLeft: return "swingLeft"
            case .wiiSwingRight: return "swingRight"
            case .wiiTiltForward: return "tiltForward"
            case .wiiTiltBackward: return "tiltBackward"
            case .wiiTiltLeft: return "tiltLeft"
            case .wiiTiltRight: return "tiltRight"
            case .wiiTiltModifier: return "tiltModifier"
            case .wiiShakeX: return "shakeX"
            case .wiiShakeY: return "shakeY"
            case .wiiShakeZ: return "shakeZ"
            case .nunchukC: return "nunchukC"
            case .nunchukZ: return "nunchukZ"
            case .nunchukStickUp: return "nunchukStickUp"
            case .nunchukStickDown: return "nunchukStickDown"
            case .nunchukStickLeft: return "nunchukStickLeft"
            case .nunchukStickRight: return "nunchukStickRight"
            case .nunchukSwingUp: return "nunchukSwingUp"
            case .nunchukSwingDown: return "nunchukSwingDown"
            case .nunchukSwingLeft: return "nunchukSwingLeft"
            case .nunchukSwingRight: return "nunchukSwingRight"
            case .nunchukTiltForward: return "nunchukTiltForward"
            case .nunchukTiltBackward: return "nunchukTiltBackward"
            case .nunchukTiltLeft: return "nunchukTiltLeft"
            case .nunchukTiltRight: return "nunchukTiltRight"
            case .nunchukTiltModifier: return "nunchukTiltModifier"
            case .nunchukShakeX: return "nunchukShakeX"
            case .nunchukShakeY: return "nunchukShakeY"
            case .nunchukShakeZ: return "nunchukShakeZ"
            case .classicA: return "a"
            case .classicB: return "b"
            case .classicX: return "x"
            case .classicY: return "y"
            case .classicMinus: return "-"
            case .classicPlus: return "+"
            case .classicHome: return "home"
            case .classicZL: return "zl"
            case .classicZR: return "zr"
            case .classicDpadUp: return "up"
            case .classicDpadDown: return "down"
            case .classicDpadLeft: return "left"
            case .classicDpadRight: return "right"
            case .classicStickLeftUp: return "leftup"
            case .classicStickLeftDown: return "leftdown"
            case .classicStickLeftLeft: return "leftleft"
            case .classicStickLeftRight: return "leftright"
            case .classicStickRightUp: return "rightup"
            case .classicStickRightDown: return "rightdown"
            case .classicStickRightLeft: return "classicStickRightLeft"
            case .classicStickRightRight: return "classicStickRightRight"
            case .classicTriggerL: return "l"
            case .classicTriggerR: return "r"
            case .start: return "start"
            case .select: return "select"
            case .leftAnalog: return "leftAnalog"
            case .rightAnalog: return "rightAnalog"
            case .count: return "count"
        }
    }
}

// FIXME: analog stick (x,y), memory pack, rumble pack
@objc public protocol PVWiiSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveWiiJoystickDirection:withXValue:withYValue:forPlayer:)
    func didMoveJoystick(_ button: PVWiiMoteButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int)
    @objc(didPushWiiButton:forPlayer:)
    func didPush(_ button: PVWiiMoteButton, forPlayer player: Int)
    @objc(didReleaseWiiButton:forPlayer:)
    func didRelease(_ button: PVWiiMoteButton, forPlayer player: Int)
}
