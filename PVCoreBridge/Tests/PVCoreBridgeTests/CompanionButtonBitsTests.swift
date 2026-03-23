// CompanionButtonBitsTests.swift
// PVCoreBridgeTests
//
// Validates that CompanionButtonBits constants remain unique and are each
// a single-bit power-of-two flag.  This guards against accidental on-the-wire
// bitmask collisions with the DSU protocol and PVUIBase's CompanionButton mapping.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

@testable import PVCoreBridge
import XCTest

final class CompanionButtonBitsTests: XCTestCase {

    private let allBits: [UInt32] = [
        CompanionButtonBits.south,
        CompanionButtonBits.east,
        CompanionButtonBits.west,
        CompanionButtonBits.north,
        CompanionButtonBits.l1,
        CompanionButtonBits.r1,
        CompanionButtonBits.l2,
        CompanionButtonBits.r2,
        CompanionButtonBits.select,
        CompanionButtonBits.start,
        CompanionButtonBits.l3,
        CompanionButtonBits.r3,
        CompanionButtonBits.dpadUp,
        CompanionButtonBits.dpadDown,
        CompanionButtonBits.dpadLeft,
        CompanionButtonBits.dpadRight,
        CompanionButtonBits.num0,
        CompanionButtonBits.num1,
        CompanionButtonBits.num2,
        CompanionButtonBits.num3,
        CompanionButtonBits.num4,
        CompanionButtonBits.num5,
        CompanionButtonBits.num6,
        CompanionButtonBits.num7,
        CompanionButtonBits.num8,
        CompanionButtonBits.num9,
        CompanionButtonBits.numStar,
        CompanionButtonBits.numHash,
    ]

    /// All bit constants must be distinct — no two buttons may share a bit position.
    func testAllBitsAreUnique() {
        XCTAssertEqual(
            Set(allBits).count, allBits.count,
            "CompanionButtonBits contains duplicate values — DSU on-the-wire mapping will be broken"
        )
    }

    /// Each constant must be a non-zero power of two (exactly one bit set).
    func testAllBitsAreSingleBitFlags() {
        for value in allBits {
            XCTAssertNotEqual(value, 0, "CompanionButtonBits constant must not be zero")
            XCTAssertEqual(
                value & (value - 1), 0,
                "CompanionButtonBits value 0x\(String(value, radix: 16)) is not a single-bit flag"
            )
        }
    }

    /// Smoke-test the debug-build validation hook (available in DEBUG builds only).
    func testDebugValidationHook() {
        // validateBitmaskLayoutForDebugging() runs the same precondition checks
        // via the lazy _bitValidation stored property — calling it from here
        // ensures the #if DEBUG block compiles and is reachable from the test target.
        #if DEBUG
        CompanionButtonBits.validateBitmaskLayoutForDebugging()
        #endif
    }
}
