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
import PVCoreBridge

// MARK: - Button mapping (free function — testable without instantiating the core)

/// Maps a `CompanionButton` to the corresponding `PV5200Button`, or `nil` for
/// buttons that have no Atari 5200 equivalent.
///
/// Extracted as a free function so unit tests can exercise the full mapping table
/// without needing to allocate an ObjC `PVAtari800` instance.
@inline(__always)
internal func mapCompanionButtonToPV5200(_ btn: CompanionButton) -> PV5200Button? {
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

// MARK: - CompanionControllerCapable

extension PVAtari800: CompanionControllerCapable {

    public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        switch event {
        case .buttonDown(let btn):
            if let pv = mapCompanionButtonToPV5200(btn) {
                didPush(pv, forPlayer: player)
            }
        case .buttonUp(let btn):
            if let pv = mapCompanionButtonToPV5200(btn) {
                didRelease(pv, forPlayer: player)
            }
        case .axisChanged(let axis, let value):
            handleAxisChange(axis, value: value, forPlayer: player)
        }
    }

    // MARK: - Axis handling

    /// Matches `kJoystickDeadzone` in PVAtari800Bridge.m so companion and physical
    /// controller input are treated identically by the core.
    internal static let joystickDeadzone: Float = 0.5

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
        let deadzone = PVAtari800.joystickDeadzone
        switch axis {
        case .leftX:
            if value > deadzone {
                didMoveJoystick(.right, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.left,  withValue: 0, forPlayer: player)
            } else if value < -deadzone {
                didMoveJoystick(.left,  withValue: magnitude, forPlayer: player)
                didMoveJoystick(.right, withValue: 0, forPlayer: player)
            } else {
                // Release both horizontal directions when near centre
                didMoveJoystick(.right, withValue: 0, forPlayer: player)
                didMoveJoystick(.left,  withValue: 0, forPlayer: player)
            }
        case .leftY:
            if value > deadzone {
                didMoveJoystick(.down, withValue: magnitude, forPlayer: player)
                didMoveJoystick(.up,   withValue: 0, forPlayer: player)
            } else if value < -deadzone {
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
