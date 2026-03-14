//
//  PVJITRequirementTests.swift
//  PVCoreBridgeTests
//
//  Tests for the JIT Capability Matrix (PVJITPlistRequirement + PVJITRequirementRegistry).
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
        // Simulate what CoreLoader does at startup when it reads Core.plist files.
        // Dolphin uses .optional (not .required) because PVDolphinCore.jitRequirement
        // = .automaticWithFallback — it self-detects and never crashes without JIT.
        registry.register(.required, forCoreIdentifier: azaharID)
        registry.register(.required, forCoreIdentifier: emuThreeID)
        registry.register(.optional, forCoreIdentifier: dolphinID)
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
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: azaharID), .required)
    }

    func testEmuThreeRequiresJIT() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: emuThreeID), .required)
    }

    func testDolphinIsOptional() {
        // Dolphin auto-detects JIT at startup (PVDolphinCore.jitRequirement = .automaticWithFallback),
        // so it is classified as .optional at the plist registry level — not .required.
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: dolphinID), .optional)
    }

    func testPlayRequiresJIT() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: playID), .required)
    }

    // MARK: - Optional cores

    func testMupen64PlusIsOptional() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: mupen64PlusID), .optional)
    }

    func testMupen64PlusNXIsOptional() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: mupen64PlusNXID), .optional)
    }

    func testFlycastIsOptional() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: flycastID), .optional)
    }

    // MARK: - notRequired (default)

    func testUnknownCoreIsNotRequired() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: "com.provenance.core.unknown"), .notRequired)
    }

    func testNESCoreIsNotRequired() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: "com.provenance.core.fceu"), .notRequired)
    }

    func testEmptyStringIsNotRequired() {
        XCTAssertEqual(jitPlistRequirement(forCoreIdentifier: ""), .notRequired)
    }

    // MARK: - String extension

    func testStringExtensionMatchesFreeFunction() {
        XCTAssertEqual(azaharID.jitPlistRequirement, jitPlistRequirement(forCoreIdentifier: azaharID))
    }

    // MARK: - Case-insensitive lookup

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(
            jitPlistRequirement(forCoreIdentifier: azaharID.uppercased()),
            .required
        )
    }

    // MARK: - Plist value parsing

    func testPlistValueRequired() {
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "required"), .required)
    }

    func testPlistValueOptional() {
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "optional"), .optional)
    }

    func testPlistValueNotRequired() {
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "notRequired"), .notRequired)
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "not_required"), .notRequired)
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "none"), .notRequired)
    }

    func testPlistValueCaseInsensitive() {
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "REQUIRED"), .required)
        XCTAssertEqual(PVJITPlistRequirement(plistValue: "Optional"), .optional)
    }

    func testPlistValueUnknownReturnsNil() {
        XCTAssertNil(PVJITPlistRequirement(plistValue: "unknown"))
        XCTAssertNil(PVJITPlistRequirement(plistValue: ""))
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
