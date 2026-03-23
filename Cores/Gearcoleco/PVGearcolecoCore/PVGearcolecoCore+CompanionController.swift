// PVGearcolecoCore+CompanionController.swift
// PVGearcolecoCore
//
// Wires the Companion Controller's numpad events into the Gearcoleco
// (ColecoVision) core by conforming PVGearcolecoCore to
// CompanionControllerCapable and mapping CompanionButton → PVColecoVisionButton.
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

    /// Maps a `CompanionButton` to the corresponding `PVColecoVisionButton`,
    /// or returns `nil` for buttons that have no ColecoVision equivalent.
    private static func colecoButton(for companion: CompanionButton) -> PVColecoVisionButton? {
        switch companion {
        case .dpadUp:    return .up
        case .dpadDown:  return .down
        case .dpadLeft:  return .left
        case .dpadRight: return .right
        case .south:     return .leftAction
        case .east:      return .rightAction
        case .num1:      return .button1
        case .num2:      return .button2
        case .num3:      return .button3
        case .num4:      return .button4
        case .num5:      return .button5
        case .num6:      return .button6
        case .num7:      return .button7
        case .num8:      return .button8
        case .num9:      return .button9
        case .num0:      return .button0
        case .numStar:   return .asterisk
        case .numHash:   return .pound
        @unknown default: return nil
        }
    }

    /// Handles a companion controller input event by forwarding button
    /// presses and releases to the ColecoVision button responder.
    public func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        switch event {
        case .buttonDown(let btn):
            if let colecoBtn = Self.colecoButton(for: btn) {
                didPush(colecoBtn, forPlayer: player)
            }
        case .buttonUp(let btn):
            if let colecoBtn = Self.colecoButton(for: btn) {
                didRelease(colecoBtn, forPlayer: player)
            }
        case .axisChanged:
            // ColecoVision uses d-pad only; analogue axes are not mapped.
            break
        }
    }
}
