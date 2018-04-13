//
//  PViCadeMocuteController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/12/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

public class PViCadeMocuteController : PViCadeController {

	override init() {
        super.init()

		reader.buttonDown = {[weak self] (_ button: iCadeState) -> Void in
            switch button {
                case iCadeButtonA:
                    self?.iCadeGamepad.buttonX.buttonPressed()
                case iCadeButtonB:
                    self?.iCadeGamepad.buttonA.buttonPressed()
                case iCadeButtonC:
                    self?.iCadeGamepad.buttonB.buttonPressed()
                case iCadeButtonD:
                    self?.iCadeGamepad.buttonY.buttonPressed()
                case iCadeButtonE:
                    self?.iCadeGamepad.rightShoulder.buttonPressed()
                case iCadeButtonF:
                    self?.iCadeGamepad.leftShoulder.buttonPressed()
                case iCadeButtonG:
                    self?.iCadeGamepad.leftTrigger.buttonPressed()
                case iCadeButtonH:
                    self?.iCadeGamepad.rightTrigger.buttonPressed()
                case iCadeJoystickDown, iCadeJoystickLeft, iCadeJoystickRight, iCadeJoystickUp:
                    self?.iCadeGamepad.dpad().padChanged()
                default:
                    break
            }
            if self?.controllerPressedAnyKey != nil {
                self?.controllerPressedAnyKey(self)
            }
        }

        reader.buttonUp = {[weak self] (_ button: iCadeState) -> Void in
            switch button {
                case iCadeButtonA:
                    self?.iCadeGamepad.buttonX.buttonReleased()
                case iCadeButtonB:
                    self?.iCadeGamepad.buttonA.buttonReleased()
                case iCadeButtonC:
                    self?.iCadeGamepad.buttonB.buttonReleased()
                case iCadeButtonD:
                    self?.iCadeGamepad.buttonY.buttonReleased()
                case iCadeButtonE:
                    self?.iCadeGamepad.rightShoulder.buttonReleased()
                case iCadeButtonF:
                    self?.iCadeGamepad.leftShoulder.buttonReleased()
                case iCadeButtonG:
                    self?.iCadeGamepad.leftTrigger.buttonReleased()
                case iCadeButtonH:
                    self?.iCadeGamepad.rightTrigger.buttonReleased()
                case iCadeJoystickDown, iCadeJoystickLeft, iCadeJoystickRight, iCadeJoystickUp:
                    self?.iCadeGamepad.dpad().padChanged()
                default:
                    break
            }
        }
    
    }
    func vendorName() -> String? {
        return "Mocute"
    }
}
