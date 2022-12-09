//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCade8BitdoController.swift
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#if canImport(UIKit)
import Foundation

public final class PViCade8BitdoController: PViCadeController {
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
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonF:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonG:
            return iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.leftTrigger
        default:
            return nil
        }
    }

    public override var vendorName: String? {
        return "8Bitdo"
    }
}

public final class PViCade8BitdoSNES30Controller: PViCadeController {
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
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonF:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonG:
            return iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.leftTrigger
        default:
            return nil
        }
    }

    public override var vendorName: String? {
        return "8Bitdo SNES30"
    }
}

public final class PViCade8BitdoZeroController: PViCadeController {
    override func button(forState button: iCadeControllerState) -> PViCadeGamepadButtonInput? {
        switch button {
        case iCadeControllerState.buttonA:
            return iCadeGamepad.buttonY
        case iCadeControllerState.buttonB:
            return iCadeGamepad.buttonB
        case iCadeControllerState.buttonC:
            return iCadeGamepad.buttonA
        case iCadeControllerState.buttonD:
            return iCadeGamepad.buttonX
        case iCadeControllerState.buttonE:
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonF:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonG:
            return iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.leftTrigger
        default:
            return nil
        }
    }

    public override var vendorName: String? {
        return "8Bitdo Zero"
    }
}
#endif
