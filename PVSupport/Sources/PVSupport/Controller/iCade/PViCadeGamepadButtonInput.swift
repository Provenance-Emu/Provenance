//
//  PViCadeGamepadInputButton.swift
//  Provenance
//
//  Created by Joseph Mattiello
//  Copyright (c) 2022 Joseph Mattiello. All rights reserved.
//

#if canImport(UIKit) && canImport(GameController)
import GameController

public final class PViCadeGamepadButtonInput: GCControllerButtonInput {
    var handler: GCControllerButtonValueChangedHandler?

    private var _value: Float = 0.0
    public override var value: Float {
        get {
            return _value
        }
        @objc(setButtonValue:)
        set {
            _value = newValue
        }
    }

    private var _isPressed: Bool = false
    public override var isPressed: Bool {
        get {
            return _isPressed
        }
        set {
            _isPressed = newValue
            _value = _isPressed ? 1.0 : 0.0
            handler?(self, _value, _isPressed)
        }
    }

    public override var valueChangedHandler: GCControllerButtonValueChangedHandler? {
        get {
            return super.valueChangedHandler
        }
        set(handler) {
            self.handler = handler
        }
    }

    public override var pressedChangedHandler: GCControllerButtonValueChangedHandler? {
        get {
            return super.pressedChangedHandler
        }
        set(handler) {
            self.handler = handler
        }
    }
}
#endif
