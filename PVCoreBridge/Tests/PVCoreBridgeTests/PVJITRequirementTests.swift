//
//  PVJITRequirementTests.swift
//  PVCoreBridgeTests
//
//  Tests for the JIT Capability Matrix (PVJITRequirement).
//  Part of issue #2793.
//

@testable import PVCoreBridge
import XCTest

final class PVJITRequirementTests: XCTestCase {

    // MARK: - Required cores

    func testAzaharRequiresJIT() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.azahar),
            .required
        )
    }

    func testEmuThreeRequiresJIT() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.emuThree),
            .required
        )
    }

    func testDolphinRequiresJIT() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.dolphin),
            .required
        )
    }

    func testPlayRequiresJIT() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.play),
            .required
        )
    }

    // MARK: - Optional cores

    func testMupen64PlusIsOptional() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.mupen64Plus),
            .optional
        )
    }

    func testMupen64PlusNXIsOptional() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.mupen64PlusNX),
            .optional
        )
    }

    func testFlycastIsOptional() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: PVCoreIdentifiers.flycast),
            .optional
        )
    }

    // MARK: - notRequired (default)

    func testUnknownCoreIsNotRequired() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: "com.provenance.core.unknown"),
            .notRequired
        )
    }

    func testNESCoreIsNotRequired() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: "com.provenance.core.fceu"),
            .notRequired
        )
    }

    func testEmptyStringIsNotRequired() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: ""),
            .notRequired
        )
    }

    // MARK: - String extension

    func testStringExtensionMatchesFreeFunction() {
        let id = PVCoreIdentifiers.azahar
        XCTAssertEqual(id.jitRequirement, jitRequirement(forCoreIdentifier: id))
    }
}
