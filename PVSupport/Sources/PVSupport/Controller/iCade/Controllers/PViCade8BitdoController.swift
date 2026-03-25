//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCade8BitdoController.swift
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#if canImport(UIKit) && canImport(GameController)
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

/// 8BitDo SN30 Pro / Pro+ in iCade mode.
///
/// The SN30 Pro uses the same physical iCade button protocol as the SNES30.
/// Pair in iCade mode (hold Start + R1 at power-on until LED blinks) then select
/// this profile in Settings > Controllers > iCade Controller.
///
/// For better button coverage (including analog sticks and triggers) use
/// Switch mode (S) instead — pair with Start+Y and Provenance will detect it
/// automatically as a standard GCController without iCade configuration.
///
/// iCade mode button matrix (SN30 Pro):
/// ```
/// iCade → Gamepad
/// A  →  X  (West face button)
/// B  →  A  (South face button)
/// C  →  B  (East face button)
/// D  →  Y  (North face button)
/// E  →  R1 (Right Shoulder)
/// F  →  L1 (Left Shoulder)
/// G  →  R2 (Right Trigger)
/// H  →  L2 (Left Trigger)
/// ```
/// Note: Start, Select, analog sticks, and L3/R3 are NOT available in iCade mode.
public final class PViCade8BitdoSN30ProController: PViCadeController {
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
        return "8BitDo SN30 Pro"
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
