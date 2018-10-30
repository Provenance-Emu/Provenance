//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeSteelSeriesController.swift
//  Provenance
//
//  Created by Simon Frost on 17/11/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

public final class PViCadeSteelSeriesController: PViCadeController {
    public override init() {
        super.init()

		reader.buttonDownHandler = {[weak self] button in
			guard let self = self else {
				return
			}

            switch button {
                case iCadeControllerState.buttonA.rawValue:
                    self.iCadeGamepad.buttonX.isPressed = true
                case iCadeControllerState.buttonB.rawValue:
                    self.iCadeGamepad.buttonA.isPressed = true
                case iCadeControllerState.buttonC.rawValue:
                    self.iCadeGamepad.buttonY.isPressed = true
                case iCadeControllerState.buttonD.rawValue:
                    self.iCadeGamepad.buttonB.isPressed = true
                case iCadeControllerState.buttonE.rawValue:
                    self.iCadeGamepad.leftShoulder.isPressed = true
                case iCadeControllerState.buttonF.rawValue:
                    self.iCadeGamepad.rightShoulder.isPressed = true
                case iCadeControllerState.buttonG.rawValue:
                    self.iCadeGamepad.rightTrigger.isPressed = true
                case iCadeControllerState.buttonH.rawValue:
                    self.iCadeGamepad.leftTrigger.isPressed = true
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
                    self.iCadeGamepad.dpad.padChanged()
                default:
                    break
            }

			self.controllerPressedAnyKey?(self)
        }

		reader.buttonUpHandler = { [weak self] button in
			guard let self = self else {
				return
			}
			
            switch button {
                case iCadeControllerState.buttonA.rawValue:
                    self.iCadeGamepad.buttonX.isPressed = false
                case iCadeControllerState.buttonB.rawValue:
                    self.iCadeGamepad.buttonA.isPressed = false
                case iCadeControllerState.buttonC.rawValue:
                    self.iCadeGamepad.buttonY.isPressed = false
                case iCadeControllerState.buttonD.rawValue:
                    self.iCadeGamepad.buttonB.isPressed = false
                case iCadeControllerState.buttonE.rawValue:
                    self.iCadeGamepad.leftShoulder.isPressed = false
                case iCadeControllerState.buttonF.rawValue:
                    self.iCadeGamepad.rightShoulder.isPressed = false
                case iCadeControllerState.buttonG.rawValue:
                    self.iCadeGamepad.rightTrigger.isPressed = false
                case iCadeControllerState.buttonH.rawValue:
                    self.iCadeGamepad.leftTrigger.isPressed = false
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
                    self.iCadeGamepad.dpad.padChanged()
                default:
                    break
            }
        }
    
    }

	public override var vendorName: String? {
		return "Steel Series"
	}
}
