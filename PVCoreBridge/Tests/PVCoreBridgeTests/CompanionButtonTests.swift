// CompanionButtonTests.swift
// PVCoreBridgeTests
//
// Validates that CompanionButton rawValues are each a non-zero single-bit
// (power-of-two) flag, guarding against accidental on-the-wire bitmask
// collisions with the DSU protocol.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

@testable import PVCoreBridge
import XCTest

final class CompanionButtonTests: XCTestCase {

    /// Each rawValue must be a non-zero power of two (exactly one bit set).
    ///
    /// Uniqueness of rawValues is verified separately in
    /// `CompanionControllerCapableTests.testAllCasesAreUnique()`.
    func testAllBitsAreSingleBitFlags() {
        for btn in CompanionButton.allCases {
            let value = btn.rawValue
            guard value != 0 else {
                XCTFail("CompanionButton.\(btn) rawValue must not be zero")
                continue
            }
            // Use wrapping subtraction (&-) to avoid UInt32 underflow trap if
            // a regression ever introduces a zero value that slips past the guard.
            XCTAssertEqual(
                value & (value &- 1), 0,
                "CompanionButton.\(btn) rawValue 0x\(String(value, radix: 16)) is not a single-bit flag"
            )
        }
    }
}
