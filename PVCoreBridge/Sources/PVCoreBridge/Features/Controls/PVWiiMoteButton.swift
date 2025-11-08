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
            case "wiidpadup", "up": self = .wiiDPadUp
            case "wiidpaddown", "down": self = .wiiDPadDown
            case "wiidpadleft", "left": self = .wiiDPadLeft
            case "wiidpadright", "right": self = .wiiDPadRight
            case "wiia", "a": self = .wiiA
            case "wiib", "b": self = .wiiB
            case "wiiminus", "-": self = .wiiMinus
            case "wiiplus", "+": self = .wiiPlus
            case "wiihome", "home": self = .wiiHome
            case "wiione", "1": self = .wiiOne
            case "wiitwo", "2": self = .wiiTwo
            case "wiiirup", "irup": self = .wiiIrUp
            case "wiiirdown", "irdown": self = .wiiIrDown
            case "wiiirleft", "irleft": self = .wiiIrLeft
            case "wiiirright", "irright": self = .wiiIrRight
            case "wiiirforward", "irforward": self = .wiiIrForward
            case "wiiirbackward", "irbackward": self = .wiiIrBackward
            case "wiiirhide", "irhide": self = .wiiIrHide
            case "wiiswingup", "swingup": self = .wiiSwingUp
            case "wiiswingdown", "swingdown": self = .wiiSwingDown
            case "wiiswingleft", "swingleft": self = .wiiSwingLeft
            case "wiiswingright", "swingright": self = .wiiSwingRight
            case "wiitiltforward", "tiltforward": self = .wiiTiltForward
            case "wiitiltbackward", "tiltbackward": self = .wiiTiltBackward
            case "wiitiltleft", "tiltleft": self = .wiiTiltLeft
            case "wiitiltright", "tiltright": self = .wiiTiltRight
            case "wiitiltmodifier", "tiltmodifier": self = .wiiTiltModifier
            case "wiishakex", "shakex": self = .wiiShakeX
            case "wiishakey", "shakey": self = .wiiShakeY
            case "wiishakez", "shakez": self = .wiiShakeZ
            case "nunchukc", "c": self = .nunchukC
            case "nunchukz", "z": self = .nunchukZ
            case "nunchukstickup", "stickup": self = .nunchukStickUp
            case "nunchukstickdown", "stickdown": self = .nunchukStickDown
            case "nunchukstickleft", "stickleft": self = .nunchukStickLeft
            case "nunchukstickright", "stickright": self = .nunchukStickRight
            case "nunchukswingup", "swingup": self = .nunchukSwingUp
            case "nunchukswingdown", "swingdown": self = .nunchukSwingDown
            case "nunchukswingleft", "swingleft": self = .nunchukSwingLeft
            case "nunchukswingright", "swingright": self = .nunchukSwingRight
            case "nunchuktiltforward", "tiltforward": self = .nunchukTiltForward
            case "nunchuktiltbackward", "tiltbackward": self = .nunchukTiltBackward
            case "nunchuktiltleft", "tiltleft": self = .nunchukTiltLeft
            case "nunchuktiltright", "tiltright": self = .nunchukTiltRight
            case "nunchuktiltmodifier", "tiltmodifier": self = .nunchukTiltModifier
            case "nunchukshakex", "shakex": self = .nunchukShakeX
            case "nunchukshakey", "shakey": self = .nunchukShakeY
            case "nunchukshakez", "shakez": self = .nunchukShakeZ
            case "classica", "a": self = .classicA
            case "classicb", "b": self = .classicB
            case "classicx", "x": self = .classicX
            case "classicy", "y": self = .classicY
            case "classicminus", "-": self = .classicMinus
            case "classicplus", "+": self = .classicPlus
            case "classichome", "home": self = .classicHome
            case "classiczl", "zl": self = .classicZL
            case "classiczr", "zr": self = .classicZR
            case "classicdpadup", "dpadup": self = .classicDpadUp
            case "classicdpaddown", "dpaddown": self = .classicDpadDown
            case "classicdpadleft", "dpadleft": self = .classicDpadLeft
            case "classicdpadright", "dpadright": self = .classicDpadRight
            case "classicstickleftup", "stickleftup": self = .classicStickLeftUp
            case "classicstickleftdown", "stickleftdown": self = .classicStickLeftDown
            case "classicstickleftleft", "stickleftleft": self = .classicStickLeftLeft
            case "classicstickleftright", "stickleftright": self = .classicStickLeftRight
            case "classicstickrightup", "stickrightup": self = .classicStickRightUp
            case "classicstickrightdown", "stickrightdown": self = .classicStickRightDown
            case "classicstickrightleft", "stickrightleft": self = .classicStickRightLeft
            case "classicstickrightright", "stickrightright": self = .classicStickRightRight
            case "classictriggerl", "triggerl": self = .classicTriggerL
            case "classictriggerr", "triggerr": self = .classicTriggerR
            case "start": self = .start
            case "select": self = .select
            case "leftanalog": self = .leftAnalog
            case "rightanalog": self = .rightAnalog
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
