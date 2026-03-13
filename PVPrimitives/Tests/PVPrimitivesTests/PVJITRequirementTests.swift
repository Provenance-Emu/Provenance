// PVJITRequirementTests.swift
// PVPrimitivesTests
//
// Created by Provenance Emu on 2026-03-13.
// Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVPrimitives

final class PVJITRequirementTests: XCTestCase {

    // MARK: - isSafeWithoutJIT

    func testNotSupportedIsSafe() {
        XCTAssertTrue(PVJITRequirement.notSupported.isSafeWithoutJIT)
    }

    func testOptionalIsSafe() {
        XCTAssertTrue(PVJITRequirement.optional(fallback: "Interpreter").isSafeWithoutJIT)
    }

    func testAutomaticWithFallbackIsSafe() {
        XCTAssertTrue(PVJITRequirement.automaticWithFallback.isSafeWithoutJIT)
    }

    func testRequiredOrCrashIsNotSafe() {
        XCTAssertFalse(PVJITRequirement.requiredOrCrash.isSafeWithoutJIT)
    }

    // MARK: - hasJIT

    func testNotSupportedHasNoJIT() {
        XCTAssertFalse(PVJITRequirement.notSupported.hasJIT)
    }

    func testOptionalHasJIT() {
        XCTAssertTrue(PVJITRequirement.optional(fallback: "Interpreter").hasJIT)
    }

    func testRequiredOrCrashHasJIT() {
        XCTAssertTrue(PVJITRequirement.requiredOrCrash.hasJIT)
    }

    func testAutomaticWithFallbackHasJIT() {
        XCTAssertTrue(PVJITRequirement.automaticWithFallback.hasJIT)
    }

    // MARK: - displayDescription

    func testDisplayDescriptions() {
        XCTAssertEqual(PVJITRequirement.notSupported.displayDescription, "Not supported")
        XCTAssertEqual(PVJITRequirement.optional(fallback: "Interpreter").displayDescription, "Optional (fallback: Interpreter)")
        XCTAssertEqual(PVJITRequirement.requiredOrCrash.displayDescription, "Required — crashes without JIT")
        XCTAssertEqual(PVJITRequirement.automaticWithFallback.displayDescription, "Automatic with fallback")
    }

    // MARK: - Equatable

    func testEqualityNotSupported() {
        XCTAssertEqual(PVJITRequirement.notSupported, PVJITRequirement.notSupported)
    }

    func testEqualityOptionalSameFallback() {
        XCTAssertEqual(
            PVJITRequirement.optional(fallback: "Interpreter"),
            PVJITRequirement.optional(fallback: "Interpreter")
        )
    }

    func testInequalityOptionalDifferentFallback() {
        XCTAssertNotEqual(
            PVJITRequirement.optional(fallback: "Interpreter"),
            PVJITRequirement.optional(fallback: "Cached Interpreter")
        )
    }

    func testInequalityDifferentCases() {
        XCTAssertNotEqual(PVJITRequirement.notSupported, PVJITRequirement.requiredOrCrash)
        XCTAssertNotEqual(PVJITRequirement.optional(fallback: "Interpreter"), PVJITRequirement.requiredOrCrash)
        XCTAssertNotEqual(PVJITRequirement.automaticWithFallback, PVJITRequirement.requiredOrCrash)
    }

    func testEqualityAutomaticWithFallback() {
        XCTAssertEqual(PVJITRequirement.automaticWithFallback, PVJITRequirement.automaticWithFallback)
    }

    func testEqualityRequiredOrCrash() {
        XCTAssertEqual(PVJITRequirement.requiredOrCrash, PVJITRequirement.requiredOrCrash)
    }

    // MARK: - Edge cases

    func testFallbackStringIsPreserved() {
        let fallback = "Some Custom Fallback Mode"
        let req = PVJITRequirement.optional(fallback: fallback)
        if case .optional(let fb) = req {
            XCTAssertEqual(fb, fallback)
        } else {
            XCTFail("Expected .optional case")
        }
    }
}
