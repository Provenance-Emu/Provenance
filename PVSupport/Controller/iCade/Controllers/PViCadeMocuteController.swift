//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeMocuteController.swift
//  Provenance
//
//  Created by Edgar Neto on 8/12/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

import Foundation

public final class PViCadeMocuteController: PViCadeController {
    override func button(forState button: iCadeControllerState) -> PViCadeGamepadButtonInput? {
        switch button {
        case iCadeControllerState.buttonA:
            return iCadeGamepad.buttonX
        case iCadeControllerState.buttonB:
            return iCadeGamepad.buttonA
        case iCadeControllerState.buttonC:
            return iCadeGamepad.buttonB
        case iCadeControllerState.buttonD:
            return iCadeGamepad.buttonY
        case iCadeControllerState.buttonE:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonF:
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonG:
            return iCadeGamepad.leftTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.rightTrigger
        default:
            return nil
        }
    }

    public override var vendorName: String? {
        return "Mocute"
    }
}
