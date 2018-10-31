//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeSteelSeriesController.swift
//  Provenance
//
//  Created by Simon Frost on 17/11/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

public final class PViCadeSteelSeriesController: PViCadeController {

    override func button(forState button: iCadeControllerState) -> PViCadeGamepadButtonInput? {
        switch button {
        case iCadeControllerState.buttonA:
            return self.iCadeGamepad.buttonX
        case iCadeControllerState.buttonB:
            return self.iCadeGamepad.buttonA
        case iCadeControllerState.buttonC:
            return self.iCadeGamepad.buttonY
        case iCadeControllerState.buttonD:
            return self.iCadeGamepad.buttonB
        case iCadeControllerState.buttonE:
            return self.iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonF:
            return self.iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonG:
            return self.iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonH:
            return self.iCadeGamepad.leftTrigger
        default:
            return nil
        }
    }

	public override var vendorName: String? {
		return "Steel Series"
	}
}
