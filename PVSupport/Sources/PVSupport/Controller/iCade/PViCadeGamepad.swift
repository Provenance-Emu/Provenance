//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeGamepad.swift
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//
#if canImport(UIKit)
import GameController

internal final class PViCadeGamepad: GCExtendedGamepad {
    private let _dpad: PViCadeGamepadDirectionPad = PViCadeGamepadDirectionPad()
    private let _buttonA: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _buttonB: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _buttonX: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _buttonY: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _leftShoulder: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _rightShoulder: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _leftTrigger: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _rightTrigger: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _start: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let _select: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    private let dummyThumbstick: PViCadeGamepadDirectionPad = PViCadeGamepadDirectionPad()

    override var dpad: PViCadeGamepadDirectionPad {
        return _dpad
    }

    // iCade only support 1 dpad and 8 buttons :(,
    // thus these are dummies.
    override var leftThumbstick: PViCadeGamepadDirectionPad {
        return dummyThumbstick
    }

    override var rightThumbstick: PViCadeGamepadDirectionPad {
        return dummyThumbstick
    }

    override var buttonA: PViCadeGamepadButtonInput {
        return _buttonA
    }

    override var buttonB: PViCadeGamepadButtonInput {
        return _buttonB
    }

    override var buttonX: PViCadeGamepadButtonInput {
        return _buttonX
    }

    override var buttonY: PViCadeGamepadButtonInput {
        return _buttonY
    }

    override var leftShoulder: PViCadeGamepadButtonInput {
        return _leftShoulder
    }

    override var rightShoulder: PViCadeGamepadButtonInput {
        return _rightShoulder
    }

    override var leftTrigger: PViCadeGamepadButtonInput {
        return _leftTrigger
    }

    override var rightTrigger: PViCadeGamepadButtonInput {
        return _rightTrigger
    }
}
#endif
