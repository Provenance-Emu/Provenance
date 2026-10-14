//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeGamepadDirectionPad.swift
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#if canImport(UIKit) && canImport(GameController)
import GameController

// TODO: Make a class for gamepad and another for joystick to support dpad and joystick as seperate inputs
//@objc @objcMembers

public final class PViCadeGamepadDirectionPad: GCControllerDirectionPad {
    var handler: GCControllerDirectionPadValueChangedHandler?
    let _xAxis: PViCadeAxisInput = PViCadeAxisInput()
    let _yAxis: PViCadeAxisInput = PViCadeAxisInput()
    let _up: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _down: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _left: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    let _right: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()

    func padChanged(_ controllerIndex: Int = 0) async {
        typealias ButtonTuple = (x: Float, y: Float)

        let values: Task<ButtonTuple , Never > = Task { @MainActor in
            let state: iCadeControllerState = PViCadeReader.shared.shared.states[controllerIndex]
            let x: Float = state.contains(.joystickLeft) ? -1.0 : state.contains(.joystickRight) ? 1.0 : 0.0
            let y: Float = state.contains(.joystickDown) ? -1.0 : state.contains(.joystickUp) ? 1.0 : 0.0
            return (x,y)
        }

        let x = await values.value.0
        let y = await values.value.1
        _xAxis.value = x
        _yAxis.value = y

        _up.isPressed = y == 1
        _down.isPressed = y == -1
        _left.isPressed = x == -1
        _right.isPressed = x == 1

        handler?(self, x, y)
    }

    /// Sets the pad from axis values in -1...1 (y up), updating the four direction
    /// buttons (digital at 0.5) and firing the pad handler.
    func update(x: Float, y: Float) {
        _xAxis.value = x
        _yAxis.value = y
        for (button, pressed, value) in [(_up, y > 0.5, max(0, y)), (_down, y < -0.5, max(0, -y)),
                                         (_left, x < -0.5, max(0, -x)), (_right, x > 0.5, max(0, x))] {
            if button.isPressed != pressed { button.isPressed = pressed }
            button.value = value
        }
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

/// iCade direction state is only driven from main-thread input (`PViCadeReader`); treat as sendable for Swift concurrency boundaries.
extension PViCadeGamepadDirectionPad: @unchecked Sendable {}
#endif
