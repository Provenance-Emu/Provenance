//
//  PViCadeInputAxis.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/29/18.
//  Copyright (c) 2018 Joseph Mattiello. All rights reserved.
//

import GameController

public final class PViCadeAxisInput: GCControllerAxisInput {
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
}
