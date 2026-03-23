// PVGearcolecoCore+CompanionController.swift
// PVGearcolecoCore
//
// Wires the Companion Controller's numpad events into the Gearcoleco
// (ColecoVision) core by conforming PVGearcolecoCore to
// CompanionControllerCapable and mapping CompanionButtonBits → PVColecoVisionButton.
//
// Layout handled here (matches ColecoVisionLayout.swift):
//   num1–num9   → button1–button9
//   num0        → button0
//   numStar     → asterisk
//   numHash     → pound
//   south       → leftAction   (left side fire button)
//   east        → rightAction  (right side fire button)
//   dpadUp/Down/Left/Right → up/down/left/right
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import PVCoreBridge

// MARK: - CompanionControllerCapable

extension PVGearcolecoCore: CompanionControllerCapable {

    /// Cached mapping from CompanionButtonBits to PVColecoVisionButton.
    /// Defined as a static let so the array is allocated once, not per call.
    private static let companionMapping: [(bit: UInt32, button: PVColecoVisionButton)] = [
        (CompanionButtonBits.dpadUp,    .up),
        (CompanionButtonBits.dpadDown,  .down),
        (CompanionButtonBits.dpadLeft,  .left),
        (CompanionButtonBits.dpadRight, .right),
        (CompanionButtonBits.south,     .leftAction),
        (CompanionButtonBits.east,      .rightAction),
        (CompanionButtonBits.num1,      .button1),
        (CompanionButtonBits.num2,      .button2),
        (CompanionButtonBits.num3,      .button3),
        (CompanionButtonBits.num4,      .button4),
        (CompanionButtonBits.num5,      .button5),
        (CompanionButtonBits.num6,      .button6),
        (CompanionButtonBits.num7,      .button7),
        (CompanionButtonBits.num8,      .button8),
        (CompanionButtonBits.num9,      .button9),
        (CompanionButtonBits.num0,      .button0),
        (CompanionButtonBits.numStar,   .asterisk),
        (CompanionButtonBits.numHash,   .pound),
    ]

    /// Maps companion-controller bitmask deltas to ColecoVision button events.
    ///
    /// Only `pressed` and `released` bits are acted on so that the core
    /// receives exactly one `didPush` / `didRelease` per state transition,
    /// regardless of how many state snapshots the router sends.
    @MainActor
    public func companionButtonsChanged(
        held: UInt32,
        pressed: UInt32,
        released: UInt32,
        forPlayer player: Int
    ) {
        for (bit, button) in Self.companionMapping {
            if pressed & bit != 0 {
                didPush(button, forPlayer: player)
            } else if released & bit != 0 {
                didRelease(button, forPlayer: player)
            }
        }
    }
}
