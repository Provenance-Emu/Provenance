//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  PViCadeController.swift
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//
#if canImport(UIKit) && canImport(GameController)

// MARK: - Imports

import GameController
import PVLogging

// MARK: - PViCadeController

public class PViCadeController: GCController {
    
    internal let iCadeGamepad: PViCadeGamepad = PViCadeGamepad()

    nonisolated public var isConnected: Bool {
        return iCadeGamepad.controller?.isAttachedToDevice ?? false
    }
    
    @MainActor
    public var reader: PViCadeReader.SharedPViCadeReader { PViCadeReader.shared }
    
    public var controllerPressedAnyKey: ((_ controller: PViCadeController?) -> Void)? = nil {
        didSet {
            controllerPressedAnyKey?(self)
        }
    }

    @MainActor
    public func refreshListener() async {
        reader.shared.stopListening()
        reader.shared.listenToKeyWindow()
    }

    deinit {
//        Task { @MainActor in
//            await reader.shared.stopListening()
//        }
    }

    func button(forState button: iCadeControllerState) -> PViCadeGamepadButtonInput? {
        switch button {
        case iCadeControllerState.buttonA:
            return iCadeGamepad.rightTrigger
        case iCadeControllerState.buttonB:
            return iCadeGamepad.leftShoulder
        case iCadeControllerState.buttonC:
            return iCadeGamepad.leftTrigger
        case iCadeControllerState.buttonD:
            return iCadeGamepad.rightShoulder
        case iCadeControllerState.buttonE:
            return iCadeGamepad.buttonY
        case iCadeControllerState.buttonF:
            return iCadeGamepad.buttonB
        case iCadeControllerState.buttonG:
            return iCadeGamepad.buttonX
        case iCadeControllerState.buttonH:
            return iCadeGamepad.buttonA
        case iCadeControllerState.buttonH:
            return iCadeGamepad.leftTrigger
        case iCadeControllerState.buttonH:
            return iCadeGamepad.rightTrigger
        default:
            return nil
        }
    }

    @preconcurrency
    public override init() {
        super.init()

//        Task { @MainActor in
//            await self.createButtonDownHandler()
//            await self.createButtonUpHandler()
//        }
    }
    
    @MainActor
    @preconcurrency
    private func createButtonDownHandler() {
        reader.shared.buttonDownHandler = { [weak self] button in
            guard let `self` = self else { return }

            let dpad = self.iCadeGamepad.dpad
            
            switch button {
            case iCadeControllerState.joystickDown, iCadeControllerState.joystickLeft, iCadeControllerState.joystickRight, iCadeControllerState.joystickUp:
                DLOG("Pad Changed: \(button)")
                Task {
                    await dpad.padChanged()
                }
            default:
                if let button = self.button(forState: button) {
                    DLOG("Pressed button: \(button)")
                    button.isPressed = true
                } else {
                    DLOG("Unsupported button: \(button)")
                }
            }

            self.controllerPressedAnyKey?(self)
        }
    }
    
    @MainActor
    private func createButtonUpHandler() {
        reader.shared.buttonUpHandler = { [weak self] button in
            guard let `self` = self else { return }

            let dpad = self.iCadeGamepad.dpad

            switch button {
            case iCadeControllerState.joystickDown, iCadeControllerState.joystickLeft, iCadeControllerState.joystickRight, iCadeControllerState.joystickUp:
                DLOG("Pad Changed: \(button)")
                Task {
                    await dpad.padChanged()
                }
            default:
                if let button = self.button(forState: button) {
                    DLOG("De-Pressed button: \(button)")
                    button.isPressed = false
                } else {
                    DLOG("Unsupported button: \(button)")
                }
            }
        }
    }

    @available(iOS, deprecated: 13.0, message: "controllerPausedHandler has been deprecated. Use the Menu button found on the controller's profile, if it exists.")
    public override var controllerPausedHandler: ((GCController) -> Void)? {
        get {
            return super.controllerPausedHandler
        }
        set(controllerPausedHandler) {
            // dummy method to avoid NSInternalInconsistencyException
        }
    }

    public override var vendorName: String? {
        return "iCade"
    }

    // don't know if it's nessesary but seems good
    public override var isAttachedToDevice: Bool {
        return false
    }

    // don't know if it's nessesary to set a specific index but without implementing this method the app crashes
    private var _playerIndex: GCControllerPlayerIndex = GCControllerPlayerIndex(rawValue: 0)!
    public override var playerIndex: GCControllerPlayerIndex {
        get {
            return _playerIndex
        }
        set {
            _playerIndex = newValue
        }
    }
}

#endif // CanImport UIKit, GCGameController
