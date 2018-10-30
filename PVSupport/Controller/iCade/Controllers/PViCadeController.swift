//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeController.swift
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

import GameController

public class PViCadeController: GCController {
	
    public private(set) var iCadeGamepad: PViCadeGamepad = PViCadeGamepad()
    public let reader: PViCadeReader = PViCadeReader.shared
    public var controllerPressedAnyKey: ((_ controller: PViCadeController?) -> Void)?

    public func refreshListener() {
        reader.stopListening()
        reader.listenToKeyWindow()
    }

    deinit {
        reader.stopListening()
    }

    public override init() {
        super.init()

		reader.buttonDownHandler = { [weak self] button in
			guard let self = self else {
				return
			}
			
			switch button {
			case iCadeControllerState.buttonA.rawValue:
				self.iCadeGamepad.rightTrigger.isPressed = true
			case iCadeControllerState.buttonB.rawValue:
				self.iCadeGamepad.leftShoulder.isPressed = true
			case iCadeControllerState.buttonC.rawValue:
				self.iCadeGamepad.leftTrigger.isPressed = true
			case iCadeControllerState.buttonD.rawValue:
				self.iCadeGamepad.rightShoulder.isPressed = true
			case iCadeControllerState.buttonE.rawValue:
				self.iCadeGamepad.buttonY.isPressed = true
			case iCadeControllerState.buttonF.rawValue:
				self.iCadeGamepad.buttonB.isPressed = true
			case iCadeControllerState.buttonG.rawValue:
				self.iCadeGamepad.buttonX.isPressed = true
			case iCadeControllerState.buttonH.rawValue:
				self.iCadeGamepad.buttonA.isPressed = true
			case iCadeControllerState.buttonI.rawValue:
				self.iCadeGamepad.leftTrigger.isPressed = true
			case iCadeControllerState.buttonJ.rawValue:
				self.iCadeGamepad.rightTrigger.isPressed = true
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
				self.iCadeGamepad.rightTrigger.isPressed = false
			case iCadeControllerState.buttonB.rawValue:
				self.iCadeGamepad.leftShoulder.isPressed = false
			case iCadeControllerState.buttonC.rawValue:
				self.iCadeGamepad.leftTrigger.isPressed = false
			case iCadeControllerState.buttonD.rawValue:
				self.iCadeGamepad.rightShoulder.isPressed = false
			case iCadeControllerState.buttonE.rawValue:
				self.iCadeGamepad.buttonY.isPressed = false
			case iCadeControllerState.buttonF.rawValue:
				self.iCadeGamepad.buttonB.isPressed = false
			case iCadeControllerState.buttonG.rawValue:
				self.iCadeGamepad.buttonX.isPressed = false
			case iCadeControllerState.buttonH.rawValue:
				self.iCadeGamepad.buttonA.isPressed = false
			case iCadeControllerState.buttonI.rawValue:
				self.iCadeGamepad.leftTrigger.isPressed = false
			case iCadeControllerState.buttonJ.rawValue:
				self.iCadeGamepad.rightTrigger.isPressed = false
			case iCadeControllerState.joystickDown.rawValue, iCadeControllerState.joystickLeft.rawValue, iCadeControllerState.joystickRight.rawValue, iCadeControllerState.joystickUp.rawValue:
				self.iCadeGamepad.dpad.padChanged()
			default:
				break
			}
		}
    }

	override public var controllerPausedHandler: ((GCController) -> Void)? {
        get {
            return super.controllerPausedHandler
        }
        set(controllerPausedHandler) {
            // dummy method to avoid NSInternalInconsistencyException
        }
    }

	override public var gamepad: GCGamepad? {
        return nil
    }

	override public var extendedGamepad: GCExtendedGamepad? {
        return iCadeGamepad
    }

	override public var vendorName: String? {
        return "iCade"
    }

    // don't know if it's nessesary but seems good
	public override var isAttachedToDevice: Bool {
		return false
	}

    // don't know if it's nessesary to set a specific index but without implementing this method the app crashes
	private var _playerIndex: GCControllerPlayerIndex = GCControllerPlayerIndex(rawValue: 0)!
	override public var playerIndex: GCControllerPlayerIndex {
		get {
			return _playerIndex
		}
		set {
			_playerIndex = newValue
		}
	}
}

extension PViCadeController: iCadeEventDelegate {
	public func stateChanged(state: iCadeControllerState) {
		fatalError("Must Override")
	}

	public func buttonDown(button: Int) {
		fatalError("Must Override")
	}

	public func buttonUp(button: Int) {
		fatalError("Must Override")
	}
}
