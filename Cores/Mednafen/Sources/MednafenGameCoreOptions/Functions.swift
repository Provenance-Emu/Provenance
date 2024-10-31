//
//  Functions.swift
//  PVCoreMednafen
//
//  Created by Joseph Mattiello on 10/1/24.
//

import GameController

let DEADZONE: Float = 0.1
func OUTSIDE_DEADZONE(_ gamepad: GCController, _ x: KeyPath<GCControllerDirectionPad, GCControllerButtonInput>) -> Bool {
    gamepad.extendedGamepad?.leftThumbstick[keyPath: x].value ?? 0.0 > DEADZONE
}
func DPAD_PRESSED(_ gamepad: GCController, _ x: KeyPath<GCControllerDirectionPad, GCControllerButtonInput>) -> Bool {
    guard let extendedGamepad = gamepad.extendedGamepad else { return false }
    return extendedGamepad.dpad[keyPath: x].isPressed || OUTSIDE_DEADZONE(gamepad, x)
}
