//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCade8BitdoController.swift
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

import Foundation

public final class PViCade8BitdoController: PViCadeController {
    public override init() {
		super.init()

        reader.buttonDownHandler = { button in
            print(String(format: "Button Down %04lx", Int(button)))
            switch button {
                case iCadeControllerState.buttonA.rawValue:
					self.iCadeGamepad.buttonX.isPressed = true
                case iCadeControllerState.buttonB.rawValue:
					self.iCadeGamepad.buttonA.isPressed = true
                case iCadeControllerState.buttonC.rawValue:
					self.iCadeGamepad.buttonB.isPressed = true
                case iCadeControllerState.buttonD.rawValue:
					self.iCadeGamepad.buttonY.isPressed = true
                case iCadeControllerState.buttonE.rawValue:
					self.iCadeGamepad.rightShoulder.isPressed = true
                case iCadeControllerState.buttonF.rawValue:
					self.iCadeGamepad.leftShoulder.isPressed = true
                case iCadeControllerState.buttonG.rawValue:
					self.iCadeGamepad.rightTrigger.isPressed = true
                case iCadeControllerState.buttonH.rawValue:
					self.iCadeGamepad.leftTrigger.isPressed = true
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
					self.iCadeGamepad.dpad.padChanged()
                default:
                    print(String(format: "Button Unknown %04lx", Int(button)))
            }

			self.controllerPressedAnyKey?(self)
		}

        reader.buttonUpHandler = { button in
            print(String(format: "Button Up %04lx", Int(button)))

            switch button {
                case iCadeControllerState.buttonA.rawValue:
					self.iCadeGamepad.buttonX.isPressed = false
                case iCadeControllerState.buttonB.rawValue:
					self.iCadeGamepad.buttonA.isPressed = false
                case iCadeControllerState.buttonC.rawValue:
					self.iCadeGamepad.buttonB.isPressed = false
                case iCadeControllerState.buttonD.rawValue:
					self.iCadeGamepad.buttonY.isPressed = false
                case iCadeControllerState.buttonE.rawValue:
					self.iCadeGamepad.rightShoulder.isPressed = false
                case iCadeControllerState.buttonF.rawValue:
					self.iCadeGamepad.leftShoulder.isPressed = false
                case iCadeControllerState.buttonG.rawValue:
					self.iCadeGamepad.rightTrigger.isPressed = false
                case iCadeControllerState.buttonH.rawValue:
					self.iCadeGamepad.leftTrigger.isPressed = false
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
					self.iCadeGamepad.dpad.padChanged()
                default:
                    print(String(format: "Button Unknown %04lx", Int(button)))
            }
        }
    
    }

    public override var vendorName: String? {
        return "8Bitdo"
    }
}

public final class PViCade8BitdoZeroController: PViCadeController {
    public override init() {
        super.init()

		reader.buttonDownHandler = { [weak self] button in
			guard let self = self else {
				print("nil self")
				return
			}

            print(String(format: "Button Dpwn %04lx", Int(button)))
            switch button {
                case iCadeControllerState.buttonA.rawValue:
					self.iCadeGamepad.buttonY.isPressed = true
                case iCadeControllerState.buttonB.rawValue:
					self.iCadeGamepad.buttonB.isPressed = true
                case iCadeControllerState.buttonC.rawValue:
					self.iCadeGamepad.buttonA.isPressed = true
                case iCadeControllerState.buttonD.rawValue:
					self.iCadeGamepad.buttonX.isPressed = true
                case iCadeControllerState.buttonE.rawValue:
					self.iCadeGamepad.rightShoulder.isPressed = true
                case iCadeControllerState.buttonF.rawValue:
					self.iCadeGamepad.leftShoulder.isPressed = true
                case iCadeControllerState.buttonG.rawValue:
					self.iCadeGamepad.rightTrigger.isPressed = true
                case iCadeControllerState.buttonH.rawValue:
					self.iCadeGamepad.leftTrigger.isPressed = true
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
					self.iCadeGamepad.dpad.padChanged()
                default:
					print("Unknown button code: %@i", button)
            }

			self.controllerPressedAnyKey?(self)
        }

		reader.buttonUpHandler = { [weak self] button in
			guard let self = self else {
				print("nil self")
				return
			}

            print(String(format: "Button Up %04lx", Int(button)))
            switch button {
                case iCadeControllerState.buttonA.rawValue:
					self.iCadeGamepad.buttonY.isPressed = false
                case iCadeControllerState.buttonB.rawValue:
					self.iCadeGamepad.buttonB.isPressed = false
                case iCadeControllerState.buttonC.rawValue:
					self.iCadeGamepad.buttonA.isPressed = false
                case iCadeControllerState.buttonD.rawValue:
					self.iCadeGamepad.buttonX.isPressed = false
                case iCadeControllerState.buttonE.rawValue:
					self.iCadeGamepad.rightShoulder.isPressed = false
                case iCadeControllerState.buttonF.rawValue:
					self.iCadeGamepad.leftShoulder.isPressed = false
                case iCadeControllerState.buttonG.rawValue:
					self.iCadeGamepad.rightTrigger.isPressed = false
                case iCadeControllerState.buttonH.rawValue:
					self.iCadeGamepad.leftTrigger.isPressed = false
                case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
					self.iCadeGamepad.dpad.padChanged()
                default:
					print("Unknown button code: %@i", button)
            }
        }
    }

	override public var vendorName: String? {
        return "8Bitdo Zero"
    }
}
