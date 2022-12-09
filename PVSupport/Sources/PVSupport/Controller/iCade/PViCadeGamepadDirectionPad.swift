//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeGamepadDirectionPad.swift
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#if canImport(UIKit)
import GameController

// TODO: Make a class for gamepad and another for joystick to support dpad and joystick as seperate inputs
@objc @objcMembers
public final class PViCadeGamepadDirectionPad: GCControllerDirectionPad {
    var handler: GCControllerDirectionPadValueChangedHandler?
    let _xAxis: PViCadeAxisInput = PViCadeAxisInput()
    let _yAxis: PViCadeAxisInput = PViCadeAxisInput()
    let _up: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _down: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _left: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _right: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()

    func padChanged(_ controllerIndex: Int = 0) {
        let state: iCadeControllerState = PViCadeReader.shared.states[controllerIndex]

        let x: Float = state.contains(.joystickLeft) ? -1.0 : state.contains(.joystickRight) ? 1.0 : 0.0
        let y: Float = state.contains(.joystickDown) ? -1.0 : state.contains(.joystickUp) ? 1.0 : 0.0

        _xAxis.value = x
        _yAxis.value = y

        _up.isPressed = y == 1
        _down.isPressed = y == -1
        _left.isPressed = x == -1
        _right.isPressed = x == 1

        handler?(self, x, y)
    }

    public override var xAxis: GCControllerAxisInput {
        return _xAxis
    }

    public override var yAxis: GCControllerAxisInput {
        return _yAxis
    }

    public override var up: GCControllerButtonInput {
        return _up
    }

    public override var down: GCControllerButtonInput {
        return _down
    }

    public override var left: GCControllerButtonInput {
        return _left
    }

    public override var right: GCControllerButtonInput {
        return _right
    }

    public override var valueChangedHandler: GCControllerDirectionPadValueChangedHandler? {
        get {
            return super.valueChangedHandler
        }
        set(handler) {
            self.handler = handler
        }
    }
}
#endif
