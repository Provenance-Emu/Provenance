// PVAtari800+CompanionController.swift
// PVAtari800
//
// Wires the Companion Controller's Atari5200Layout events into PV5200Button
// calls on the Atari800 core.
//
// Button mapping (Atari5200Layout → PV5200Button):
//   num1–num9  → number1–number9
//   num0       → number0
//   numStar    → asterisk
//   numHash    → pound
//   south      → fire1   (Fire 1)
//   east       → fire2   (Fire 2)
//   start      → start
//   select     → pause   (Pause button on the 5200 controller)
//   l1         → reset
//   leftX/leftY → joystick X/Y axis (single-axis calls)
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import CoreGraphics
import Foundation
import PVCoreBridge

// MARK: - CompanionControllerCapable

extension PVAtari800: CompanionControllerCapable {

    public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        switch event {
        case .buttonDown(let btn):
            if let pv = pv5200Button(from: btn) {
                didPush(pv, forPlayer: player)
            }
        case .buttonUp(let btn):
            if let pv = pv5200Button(from: btn) {
                didRelease(pv, forPlayer: player)
            }
        case .axisChanged(let axis, let value):
            handleAxisChange(axis, value: value, forPlayer: player)
        }
    }

    // MARK: - Button mapping

    private func pv5200Button(from btn: CompanionButton) -> PV5200Button? {
        switch btn {
        case .num1:    return .number1
        case .num2:    return .number2
        case .num3:    return .number3
        case .num4:    return .number4
        case .num5:    return .number5
        case .num6:    return .number6
        case .num7:    return .number7
        case .num8:    return .number8
        case .num9:    return .number9
        case .num0:    return .number0
        case .numStar: return .asterisk
        case .numHash: return .pound
        case .south:   return .fire1
        case .east:    return .fire2
        case .start:   return .start
        case .select:  return .pause
        case .l1:      return .reset
        default:       return nil
        }
    }

    // MARK: - Axis handling

    /// Maps companion X/Y axis values to single-axis joystick calls.
    ///
    /// A positive X value → right; negative → left.
    /// A positive Y value → down (screen-space); negative → up.
    private func handleAxisChange(
        _ axis: CompanionAxisID,
        value: Float,
        forPlayer player: Int
    ) {
        let magnitude = CGFloat(abs(value))
        switch axis {
        case .leftX:
            if value > 0.05 {
                didMoveJoystick(.right, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.left,  withValue: 0, forPlayer: player)
            } else if value < -0.05 {
                didMoveJoystick(.left,  withValue: magnitude, forPlayer: player)
                didMoveJoystick(.right, withValue: 0, forPlayer: player)
            } else {
                // Release both horizontal directions when near centre
                didMoveJoystick(.right, withValue: 0, forPlayer: player)
                didMoveJoystick(.left,  withValue: 0, forPlayer: player)
            }
        case .leftY:
            if value > 0.05 {
                didMoveJoystick(.down, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.up,   withValue: 0, forPlayer: player)
            } else if value < -0.05 {
                didMoveJoystick(.up,   withValue: magnitude, forPlayer: player)
                didMoveJoystick(.down, withValue: 0, forPlayer: player)
            } else {
                // Release both vertical directions when near centre
                didMoveJoystick(.up,   withValue: 0, forPlayer: player)
                didMoveJoystick(.down, withValue: 0, forPlayer: player)
            }
        default:
            break
        }
    }
}
