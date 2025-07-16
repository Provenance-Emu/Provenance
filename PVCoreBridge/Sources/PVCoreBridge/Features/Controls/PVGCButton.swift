//
//  PVGCButton.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 4/5/25.
//

// MARK: - GameCube

/*
 // Copyright 2022 DolphiniOS Project
 // SPDX-License-Identifier: GPL-2.0-or-later

 #pragma once

 namespace ciface::iOS
 {
 enum ButtonType
 {
   // GC
   BUTTON_A = 0,
   BUTTON_B = 1,
   BUTTON_START = 2,
   BUTTON_X = 3,
   BUTTON_Y = 4,
   BUTTON_Z = 5,
   BUTTON_UP = 6,
   BUTTON_DOWN = 7,
   BUTTON_LEFT = 8,
   BUTTON_RIGHT = 9,
   STICK_MAIN = 10,
   STICK_MAIN_UP = 11,
   STICK_MAIN_DOWN = 12,
   STICK_MAIN_LEFT = 13,
   STICK_MAIN_RIGHT = 14,
   STICK_C = 15,
   STICK_C_UP = 16,
   STICK_C_DOWN = 17,
   STICK_C_LEFT = 18,
   STICK_C_RIGHT = 19,
   TRIGGER_L = 20,
   TRIGGER_R = 21,
   // Wiimote
   WIIMOTE_BUTTON_A = 100,
   WIIMOTE_BUTTON_B = 101,
   WIIMOTE_BUTTON_MINUS = 102,
   WIIMOTE_BUTTON_PLUS = 103,
   WIIMOTE_BUTTON_HOME = 104,
   WIIMOTE_BUTTON_1 = 105,
   WIIMOTE_BUTTON_2 = 106,
   WIIMOTE_UP = 107,
   WIIMOTE_DOWN = 108,
   WIIMOTE_LEFT = 109,
   WIIMOTE_RIGHT = 110,
   WIIMOTE_IR = 111,
   WIIMOTE_IR_UP = 112,
   WIIMOTE_IR_DOWN = 113,
   WIIMOTE_IR_LEFT = 114,
   WIIMOTE_IR_RIGHT = 115,
   WIIMOTE_IR_FORWARD = 116,
   WIIMOTE_IR_BACKWARD = 117,
   WIIMOTE_IR_HIDE = 118,
   WIIMOTE_SWING = 119,
   WIIMOTE_SWING_UP = 120,
   WIIMOTE_SWING_DOWN = 121,
   WIIMOTE_SWING_LEFT = 122,
   WIIMOTE_SWING_RIGHT = 123,
   WIIMOTE_SWING_FORWARD = 124,
   WIIMOTE_SWING_BACKWARD = 125,
   WIIMOTE_TILT = 126,
   WIIMOTE_TILT_FORWARD = 127,
   WIIMOTE_TILT_BACKWARD = 128,
   WIIMOTE_TILT_LEFT = 129,
   WIIMOTE_TILT_RIGHT = 130,
   WIIMOTE_TILT_MODIFIER = 131,
   WIIMOTE_SHAKE_X = 132,
   WIIMOTE_SHAKE_Y = 133,
   WIIMOTE_SHAKE_Z = 134,
   // Nunchuk
   NUNCHUK_BUTTON_C = 200,
   NUNCHUK_BUTTON_Z = 201,
   NUNCHUK_STICK = 202,
   NUNCHUK_STICK_UP = 203,
   NUNCHUK_STICK_DOWN = 204,
   NUNCHUK_STICK_LEFT = 205,
   NUNCHUK_STICK_RIGHT = 206,
   NUNCHUK_SWING = 207,
   NUNCHUK_SWING_UP = 208,
   NUNCHUK_SWING_DOWN = 209,
   NUNCHUK_SWING_LEFT = 210,
   NUNCHUK_SWING_RIGHT = 211,
   NUNCHUK_SWING_FORWARD = 212,
   NUNCHUK_SWING_BACKWARD = 213,
   NUNCHUK_TILT = 214,
   NUNCHUK_TILT_FORWARD = 215,
   NUNCHUK_TILT_BACKWARD = 216,
   NUNCHUK_TILT_LEFT = 217,
   NUNCHUK_TILT_RIGHT = 218,
   NUNCHUK_TILT_MODIFIER = 219,
   NUNCHUK_SHAKE_X = 220,
   NUNCHUK_SHAKE_Y = 221,
   NUNCHUK_SHAKE_Z = 222,
   // Classic
   CLASSIC_BUTTON_A = 300,
   CLASSIC_BUTTON_B = 301,
   CLASSIC_BUTTON_X = 302,
   CLASSIC_BUTTON_Y = 303,
   CLASSIC_BUTTON_MINUS = 304,
   CLASSIC_BUTTON_PLUS = 305,
   CLASSIC_BUTTON_HOME = 306,
   CLASSIC_BUTTON_ZL = 307,
   CLASSIC_BUTTON_ZR = 308,
   CLASSIC_DPAD_UP = 309,
   CLASSIC_DPAD_DOWN = 310,
   CLASSIC_DPAD_LEFT = 311,
   CLASSIC_DPAD_RIGHT = 312,
   CLASSIC_STICK_LEFT = 313,
   CLASSIC_STICK_LEFT_UP = 314,
   CLASSIC_STICK_LEFT_DOWN = 315,
   CLASSIC_STICK_LEFT_LEFT = 316,
   CLASSIC_STICK_LEFT_RIGHT = 317,
   CLASSIC_STICK_RIGHT = 318,
   CLASSIC_STICK_RIGHT_UP = 319,
   CLASSIC_STICK_RIGHT_DOWN = 320,
   CLASSIC_STICK_RIGHT_LEFT = 321,
   CLASSIC_STICK_RIGHT_RIGHT = 322,
   CLASSIC_TRIGGER_L = 323,
   CLASSIC_TRIGGER_R = 324,
   // Wiimote IMU
   WIIMOTE_ACCEL_LEFT = 625,
   WIIMOTE_ACCEL_RIGHT = 626,
   WIIMOTE_ACCEL_FORWARD = 627,
   WIIMOTE_ACCEL_BACKWARD = 628,
   WIIMOTE_ACCEL_UP = 629,
   WIIMOTE_ACCEL_DOWN = 630,
   WIIMOTE_GYRO_PITCH_UP = 631,
   WIIMOTE_GYRO_PITCH_DOWN = 632,
   WIIMOTE_GYRO_ROLL_LEFT = 633,
   WIIMOTE_GYRO_ROLL_RIGHT = 634,
   WIIMOTE_GYRO_YAW_LEFT = 635,
   WIIMOTE_GYRO_YAW_RIGHT = 636,
   // Rumble
   RUMBLE = 700,
   // Nunchuk IMU
   NUNCHUK_ACCEL_LEFT = 900,
   NUNCHUK_ACCEL_RIGHT = 901,
   NUNCHUK_ACCEL_FORWARD = 902,
   NUNCHUK_ACCEL_BACKWARD = 903,
   NUNCHUK_ACCEL_UP = 904,
   NUNCHUK_ACCEL_DOWN = 905
 };
 }  // namespace ciface::iOS

 */

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
            case "c▲": self = .cUp
            case "c▼": self = .cDown
            case "c◀": self = .cLeft
            case "c▶": self = .cRight
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
            case .analogUp:
                return "analogUp"
            case .analogDown:
                return "analogDown"
            case .analogLeft:
                return "analogLeft"
            case .analogRight:
                return "analogRight"
            case .analogCUp:
                return "analogCUp"
            case .analogCDown:
                return "analogCDown"
            case .analogCLeft:
                return "analogCLeft"
            case .analogCRight:
                return "analogCRight"
            case .cUp:
                return "c▲"
            case .cDown:
                return "c▼"
            case .cLeft:
                return "c◀"
            case .cRight:
                return "cRight"
            case .leftAnalog:
                return "leftAnalog"
            case .rightAnalog:
                return "rightAnalog"
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
