//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeSteelSeriesController.swift
//  Provenance
//
//  Created by Simon Frost on 17/11/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#if canImport(UIKit)
public final class PViCadeSteelSeriesController: PViCadeController {
    override func button(forState button: iCadeControllerState) -> PViCadeGamepadButtonInput? {
        switch button {
        case iCadeControllerState.buttonA:
            return iCadeGamepad.buttonX
        case iCadeControllerState.buttonB:
            return iCadeGamepad.buttonA
        case iCadeControllerState.buttonC:
            return iCadeGamepad.buttonY
        case iCadeControllerState.buttonD:
            return iCadeGamepad.buttonB
        case iCadeControllerState.buttonE:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonF:
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonG:
            return iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.leftTrigger
        default:
            return nil
        }
    }

    public override var vendorName: String? {
        return "Steel Series"
    }
}
#endif
