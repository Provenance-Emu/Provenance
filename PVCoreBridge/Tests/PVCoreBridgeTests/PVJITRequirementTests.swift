//
//  PVJITRequirementTests.swift
//  PVCoreBridgeTests
//
//  Tests for the JIT Capability Matrix (PVJITRequirement + PVJITRequirementRegistry).
//  Part of issue #2793.
//
//  JIT requirements are now driven by `Core.plist` — each core declares its own
//  `PVJITRequirement` key. The registry is populated at runtime by `CoreLoader`.
//  These tests simulate that by registering known identifiers directly.
//

@testable import PVCoreBridge
import XCTest

final class PVJITRequirementTests: XCTestCase {

    private let registry = PVJITRequirementRegistry.shared

    // Real identifier strings from each core's Core.plist
    private let azaharID        = "com.provenance.core.azahar"
    private let emuThreeID      = "com.provenance.core.emuThree"
    private let dolphinID       = "com.provenance.core.dolphin"
    private let playID          = "com.provenance.core.play"
    private let mupen64PlusID   = "com.provenance.core.mupen64plus"
    private let mupen64PlusNXID = "com.provenance.core.mupen64plusnx"
    private let flycastID       = "com.provenance.core.flycast"

    override func setUp() {
        super.setUp()
        registry._resetForTesting()
        // Simulate what CoreLoader does at startup when it reads Core.plist files
        registry.register(.required, forCoreIdentifier: azaharID)
        registry.register(.required, forCoreIdentifier: emuThreeID)
        registry.register(.required, forCoreIdentifier: dolphinID)
        registry.register(.required, forCoreIdentifier: playID)
        registry.register(.optional, forCoreIdentifier: mupen64PlusID)
        registry.register(.optional, forCoreIdentifier: mupen64PlusNXID)
        registry.register(.optional, forCoreIdentifier: flycastID)
    }

    override func tearDown() {
        registry._resetForTesting()
        super.tearDown()
    }

    // MARK: - Required cores

    func testAzaharRequiresJIT() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: azaharID), .required)
    }

    func testEmuThreeRequiresJIT() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: emuThreeID), .required)
    }

    func testDolphinRequiresJIT() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: dolphinID), .required)
    }

    func testPlayRequiresJIT() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: playID), .required)
    }

    // MARK: - Optional cores

    func testMupen64PlusIsOptional() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: mupen64PlusID), .optional)
    }

    func testMupen64PlusNXIsOptional() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: mupen64PlusNXID), .optional)
    }

    func testFlycastIsOptional() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: flycastID), .optional)
    }

    // MARK: - notRequired (default)

    func testUnknownCoreIsNotRequired() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: "com.provenance.core.unknown"), .notRequired)
    }

    func testNESCoreIsNotRequired() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: "com.provenance.core.fceu"), .notRequired)
    }

    func testEmptyStringIsNotRequired() {
        XCTAssertEqual(jitRequirement(forCoreIdentifier: ""), .notRequired)
    }

    // MARK: - String extension

    func testStringExtensionMatchesFreeFunction() {
        XCTAssertEqual(azaharID.jitRequirement, jitRequirement(forCoreIdentifier: azaharID))
    }

    // MARK: - Case-insensitive lookup

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(
            jitRequirement(forCoreIdentifier: azaharID.uppercased()),
            .required
        )
    }

    // MARK: - Plist value parsing

    func testPlistValueRequired() {
        XCTAssertEqual(PVJITRequirement(plistValue: "required"), .required)
    }

    func testPlistValueOptional() {
        XCTAssertEqual(PVJITRequirement(plistValue: "optional"), .optional)
    }

    func testPlistValueNotRequired() {
        XCTAssertEqual(PVJITRequirement(plistValue: "notRequired"), .notRequired)
        XCTAssertEqual(PVJITRequirement(plistValue: "not_required"), .notRequired)
        XCTAssertEqual(PVJITRequirement(plistValue: "none"), .notRequired)
    }

    func testPlistValueCaseInsensitive() {
        XCTAssertEqual(PVJITRequirement(plistValue: "REQUIRED"), .required)
        XCTAssertEqual(PVJITRequirement(plistValue: "Optional"), .optional)
    }

    func testPlistValueUnknownReturnsNil() {
        XCTAssertNil(PVJITRequirement(plistValue: "unknown"))
        XCTAssertNil(PVJITRequirement(plistValue: ""))
    }

    // MARK: - Registry raw-value registration

    func testRegisterRawValueValid() {
        registry.register(rawValue: "required", forCoreIdentifier: "com.test.core")
        XCTAssertEqual(registry.requirement(forCoreIdentifier: "com.test.core"), .required)
    }

    func testRegisterRawValueInvalidIsIgnored() {
        registry.register(rawValue: "bogus", forCoreIdentifier: "com.test.core")
        XCTAssertEqual(registry.requirement(forCoreIdentifier: "com.test.core"), .notRequired)
    }
}
