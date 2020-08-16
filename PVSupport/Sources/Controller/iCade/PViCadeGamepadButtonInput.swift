//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeGamepadInputButton.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

//
//  PViCadeGamepadInputButton.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

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
