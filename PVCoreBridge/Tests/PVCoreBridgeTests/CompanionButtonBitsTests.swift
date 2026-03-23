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

    /// All bit constants must be distinct — no two buttons may share a bit position.
    func testAllBitsAreUnique() {
        let allBits = CompanionButtonBits.allBitValues
        XCTAssertEqual(
            Set(allBits).count, allBits.count,
            "CompanionButtonBits contains duplicate values — DSU on-the-wire mapping will be broken"
        )
    }

    /// Each constant must be a non-zero power of two (exactly one bit set).
    ///
    /// Uses a `guard` to skip the power-of-two check when the value is zero —
    /// this avoids a false-positive where `0 &- 1 == UInt32.max` and
    /// `0 & UInt32.max == 0` would incorrectly pass the single-bit assertion.
    func testAllBitsAreSingleBitFlags() {
        for value in CompanionButtonBits.allBitValues {
            guard value != 0 else {
                XCTFail("CompanionButtonBits constant must not be zero")
                continue
            }
            XCTAssertEqual(
                value & (value - 1), 0,
                "CompanionButtonBits value 0x\(String(value, radix: 16)) is not a single-bit flag"
            )
        }
    }

    /// Smoke-test the debug-build validation hook (available in DEBUG builds only).
    ///
    /// This relies on CompanionButtonBits' own canonical validation logic, which
    /// checks that all button bit constants are unique and single-bit flags.
    func testDebugValidationHook() {
        // validateBitmaskLayoutForDebugging() runs the same precondition checks
        // via the lazy _bitValidation stored property — calling it from here
        // ensures the #if DEBUG block compiles and is reachable from the test target.
        #if DEBUG
        CompanionButtonBits.validateBitmaskLayoutForDebugging()
        #endif
    }
}
