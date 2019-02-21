//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeGamepad.swift
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

import GameController

public final class PViCadeGamepad: GCExtendedGamepad {
    public let _dpad: PViCadeGamepadDirectionPad = PViCadeGamepadDirectionPad()
    public let _buttonA: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _buttonB: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _buttonX: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _buttonY: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _leftShoulder: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _rightShoulder: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _leftTrigger: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _rightTrigger: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _start: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let _select: PViCadeGamepadButtonInput = PViCadeGamepadButtonInput()
    public let dummyThumbstick: PViCadeGamepadDirectionPad = PViCadeGamepadDirectionPad()

    public override var dpad: PViCadeGamepadDirectionPad {
        return _dpad
    }

    // iCade only support 1 dpad and 8 buttons :(,
    // thus these are dummies.
    public override var leftThumbstick: PViCadeGamepadDirectionPad {
        return dummyThumbstick
    }

    public override var rightThumbstick: PViCadeGamepadDirectionPad {
        return dummyThumbstick
    }

    public override var buttonA: PViCadeGamepadButtonInput {
        return _buttonA
    }

    public override var buttonB: PViCadeGamepadButtonInput {
        return _buttonB
    }

    public override var buttonX: PViCadeGamepadButtonInput {
        return _buttonX
    }

    public override var buttonY: PViCadeGamepadButtonInput {
        return _buttonY
    }

    public override var leftShoulder: PViCadeGamepadButtonInput {
        return _leftShoulder
    }

    public override var rightShoulder: PViCadeGamepadButtonInput {
        return _rightShoulder
    }

    public override var leftTrigger: PViCadeGamepadButtonInput {
        return _leftTrigger
    }

    public override var rightTrigger: PViCadeGamepadButtonInput {
        return _rightTrigger
    }
}
