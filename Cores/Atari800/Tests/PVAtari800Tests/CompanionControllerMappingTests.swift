// CompanionControllerMappingTests.swift
// PVAtari800Tests
//
// Unit tests for the Atari 5200 companion controller button and axis mapping.
// These tests exercise `mapCompanionButtonToPV5200(_:)` directly — no ObjC
// core allocation required — keeping the suite fast and dependency-free.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

import Testing
@testable import PVAtari800
import PVCoreBridge

// MARK: - Button mapping

@Suite("Atari 5200 companion button mapping")
struct CompanionButtonMappingTests {

    // MARK: Numpad

    @Test("numpad digits map to the corresponding PV5200Button numbers")
    func numpadDigits() {
        let expected: [(CompanionButton, PV5200Button)] = [
            (.num0, .number0), (.num1, .number1), (.num2, .number2),
            (.num3, .number3), (.num4, .number4), (.num5, .number5),
            (.num6, .number6), (.num7, .number7), (.num8, .number8),
            (.num9, .number9),
        ]
        for (companion, pv) in expected {
            #expect(mapCompanionButtonToPV5200(companion) == pv,
                    "Expected \(companion) → \(pv)")
        }
    }

    @Test("numStar maps to asterisk")
    func numStar() {
        #expect(mapCompanionButtonToPV5200(.numStar) == .asterisk)
    }

    @Test("numHash maps to pound")
    func numHash() {
        #expect(mapCompanionButtonToPV5200(.numHash) == .pound)
    }

    // MARK: Fire buttons

    @Test("south face button maps to fire1")
    func southToFire1() {
        #expect(mapCompanionButtonToPV5200(.south) == .fire1)
    }

    @Test("east face button maps to fire2")
    func eastToFire2() {
        #expect(mapCompanionButtonToPV5200(.east) == .fire2)
    }

    // MARK: System buttons

    @Test("start maps to start")
    func startButton() {
        #expect(mapCompanionButtonToPV5200(.start) == .start)
    }

    @Test("select maps to pause")
    func selectToPause() {
        #expect(mapCompanionButtonToPV5200(.select) == .pause)
    }

    @Test("l1 maps to reset")
    func l1ToReset() {
        #expect(mapCompanionButtonToPV5200(.l1) == .reset)
    }

    // MARK: Unmapped buttons

    @Test("buttons with no 5200 equivalent return nil")
    func unmappedButtonsReturnNil() {
        let unmapped: [CompanionButton] = [
            .west, .north, .r1, .r2, .l2, .l3, .r3,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        ]
        for btn in unmapped {
            #expect(mapCompanionButtonToPV5200(btn) == nil,
                    "\(btn) should have no PV5200Button mapping")
        }
    }
}

// MARK: - Axis mapping (deadzone)

@Suite("Atari 5200 companion axis deadzone")
struct CompanionAxisDeadzoneTests {

    @Test("joystickDeadzone constant matches kJoystickDeadzone in PVAtari800Bridge.m (0.5)")
    func deadzoneValue() {
        // Mirror of PVAtari800.joystickDeadzone; if the bridge constant changes,
        // update both to keep companion and physical controller behaviour in sync.
        let expected: Float = 0.5
        #expect(PVAtari800.joystickDeadzone == expected)
    }
}
