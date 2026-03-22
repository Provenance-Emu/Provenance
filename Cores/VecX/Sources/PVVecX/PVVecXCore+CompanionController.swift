// PVVecXCore+CompanionController.swift
// PVVecX
//
// Wires companion controller events (from a paired iPhone/iPad running the
// Vectrex companion layout) into the VecX emulator core.
//
// Button mapping — matches VectrexLayout:
//   CompanionButton.south  → PVVectrexButton.button1
//   CompanionButton.east   → PVVectrexButton.button2
//   CompanionButton.west   → PVVectrexButton.button3
//   CompanionButton.north  → PVVectrexButton.button4
//
// Analog joystick mapping (CompanionAxisID.leftX / .leftY → ±1.0):
//   leftX > 0  → analogRight (magnitude = |value|)
//   leftX < 0  → analogLeft  (magnitude = |value|)
//   leftX = 0  → both analogRight and analogLeft zeroed
//   leftY > 0  → analogDown  (screen-down = positive Y)
//   leftY < 0  → analogUp
//   leftY = 0  → both analogDown and analogUp zeroed
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Foundation
import PVCoreBridge

// MARK: - CompanionControllerCapable

extension PVVecXCore: CompanionControllerCapable {

    public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        switch event {
        case .buttonDown(let btn):
            guard let vectrexBtn = PVVectrexButton(companionButton: btn) else { return }
            didPush(vectrexBtn, forPlayer: player)

        case .buttonUp(let btn):
            guard let vectrexBtn = PVVectrexButton(companionButton: btn) else { return }
            didRelease(vectrexBtn, forPlayer: player)

        case .axisChanged(let axis, let value):
            handleCompanionAxis(axis, value: value, forPlayer: player)
        }
    }

    // MARK: - Private

    private func handleCompanionAxis(_ axis: CompanionAxisID, value: Float, forPlayer player: Int) {
        let magnitude = CGFloat(abs(value))

        switch axis {
        case .leftX:
            // Positive X = right, negative X = left.
            // Always send both directions so the opposite is zeroed when returning
            // to centre or crossing the neutral point.
            if value >= 0 {
                didMoveJoystick(.analogRight, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.analogLeft,  withValue: 0,         forPlayer: player)
            } else {
                didMoveJoystick(.analogLeft,  withValue: magnitude, forPlayer: player)
                didMoveJoystick(.analogRight, withValue: 0,         forPlayer: player)
            }

        case .leftY:
            // Positive Y = screen-down = analogDown.
            if value >= 0 {
                didMoveJoystick(.analogDown, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.analogUp,   withValue: 0,         forPlayer: player)
            } else {
                didMoveJoystick(.analogUp,   withValue: magnitude, forPlayer: player)
                didMoveJoystick(.analogDown, withValue: 0,         forPlayer: player)
            }

        default:
            // The Vectrex only has one analog stick; ignore other axes.
            break
        }
    }
}

// MARK: - PVVectrexButton + CompanionButton

private extension PVVectrexButton {
    /// Returns the Vectrex button corresponding to a companion face button,
    /// or `nil` when the button has no Vectrex equivalent.
    init?(companionButton: CompanionButton) {
        switch companionButton {
        case .south: self = .button1
        case .east:  self = .button2
        case .west:  self = .button3
        case .north: self = .button4
        default:     return nil
        }
    }
}
