// CompanionButtonBitsTests.swift
// PVCoreBridgeTests
//
// Validates that CompanionButton rawValues remain unique and are each
// a single-bit power-of-two flag.  This guards against accidental on-the-wire
// bitmask collisions with the DSU protocol.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

@testable import PVCoreBridge
import XCTest

final class CompanionButtonTests: XCTestCase {

    /// All rawValues must be distinct — no two buttons may share a bit position.
    func testAllBitsAreUnique() {
        let allValues = CompanionButton.allCases.map { $0.rawValue }
        XCTAssertEqual(
            Set(allValues).count, allValues.count,
            "CompanionButton has duplicate rawValues — DSU on-the-wire mapping will be broken"
        )
    }

    /// Each rawValue must be a non-zero power of two (exactly one bit set).
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
