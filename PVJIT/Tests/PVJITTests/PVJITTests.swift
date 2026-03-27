//
//  PVJITTests.swift
//  PVJITTests
//
//  Tests for PVJIT JIT detection types.
//

import XCTest
@testable import PVJIT
import JITManager

final class JITSourceTests: XCTestCase {

    // MARK: - Happy-path tests

    func testJITSourceRawValues() {
        XCTAssertEqual(JITSource.altStore.rawValue, "AltStore")
        XCTAssertEqual(JITSource.stikDebug.rawValue, "StikDebug")
        XCTAssertEqual(JITSource.trollStore.rawValue, "TrollStore")
        XCTAssertEqual(JITSource.system.rawValue, "System")
        XCTAssertEqual(JITSource.unknown.rawValue, "Unknown")
        XCTAssertEqual(JITSource.none.rawValue, "None")
    }

    func testDisplayNameMatchesRawValue() {
        for source in JITSource.allCases {
            XCTAssertEqual(source.displayName, source.rawValue,
                           "displayName should equal rawValue for \(source)")
        }
    }

    func testJITSourceEquality() {
        XCTAssertEqual(JITSource.altStore, JITSource.altStore)
        XCTAssertNotEqual(JITSource.altStore, JITSource.stikDebug)
        XCTAssertNotEqual(JITSource.trollStore, JITSource.none)
    }

    // MARK: - Edge-case tests

    func testJITSourceNoneIsDistinctFromUnknown() {
        // .none = JIT not acquired; .unknown = acquired but source indeterminate
        XCTAssertNotEqual(JITSource.none, JITSource.unknown)
    }

    func testAllCasesArePresent() {
        // Ensure the allCases count matches the expected number of sources.
        // Update this assertion whenever a new case is added.
        XCTAssertEqual(JITSource.allCases.count, 6,
                       "Expected 6 JITSource cases: altStore, stikDebug, trollStore, system, unknown, none")
    }

    func testJITSourceSendableConformance() {
        // Verify we can pass JITSource across concurrency boundaries.
        let source: JITSource = .altStore
        let expectation = XCTestExpectation(description: "Sendable JITSource crosses concurrency boundary")
        Task.detached {
            let captured: JITSource = source
            XCTAssertEqual(captured, .altStore)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

// MARK: - DOLJitManager W×X enforcement tests

final class WXEnforcementTests: XCTestCase {

    func testSimulatorAlwaysReturnsFalse() {
        // The simulator never enforces W×X regardless of reported OS version.
        XCTAssertFalse(DOLJitManager._isWXEnforced(isSimulator: true))
    }

    func testNonSimulatorWXEnforcementMatchesPlatformVersion() throws {
        // On the simulator we cannot meaningfully test the non-simulator path.
#if targetEnvironment(simulator)
        throw XCTSkip("Non-simulator W×X enforcement is not testable on the simulator.")
#else
        // On a real device or non-simulator build host, the result must match
        // the platform availability: true on iOS/tvOS 26+, false on earlier versions.
#if os(iOS)
        if #available(iOS 26, *) {
            XCTAssertTrue(DOLJitManager._isWXEnforced(isSimulator: false),
                          "On iOS 26+ non-simulator, W×X should be reported as enforced.")
        } else {
            XCTAssertFalse(DOLJitManager._isWXEnforced(isSimulator: false),
                           "On iOS < 26 non-simulator, W×X should not be reported as enforced.")
        }
#elseif os(tvOS)
        if #available(tvOS 26, *) {
            XCTAssertTrue(DOLJitManager._isWXEnforced(isSimulator: false),
                          "On tvOS 26+ non-simulator, W×X should be reported as enforced.")
        } else {
            XCTAssertFalse(DOLJitManager._isWXEnforced(isSimulator: false),
                           "On tvOS < 26 non-simulator, W×X should not be reported as enforced.")
        }
#else
        // On non-iOS/tvOS platforms (e.g. macOS, Linux CI), W×X via DOLJitManager
        // should not be reported as enforced.
        XCTAssertFalse(DOLJitManager._isWXEnforced(isSimulator: false),
                       "On non-iOS/tvOS platforms, W×X enforcement should be reported as disabled.")
#endif
#endif
    }

    func testPublicPropertyMatchesHelperOnSimulator() {
        // On the simulator the public var and the helper must agree.
#if targetEnvironment(simulator)
        XCTAssertFalse(DOLJitManager.isWXEnforced)
        XCTAssertEqual(DOLJitManager.isWXEnforced, DOLJitManager._isWXEnforced(isSimulator: true))
#endif
    }
}

// MARK: - C-callable bridge tests

final class CCallableBridgeTests: XCTestCase {

    /// Verifies that `PVJITManagerIsAcquired()` stays in sync with
    /// `DOLJitManager.acquired` so that changes to the acquisition state
    /// are always reflected through the C bridge used by the RetroArch core.
    func testPVJITManagerIsAcquiredMatchesDOLJitManagerAcquired() {
        XCTAssertEqual(PVJITManagerIsAcquired(), DOLJitManager.acquired,
                       "PVJITManagerIsAcquired() must mirror DOLJitManager.acquired")
    }

    /// Verifies that `PVJITHasNativeJITEntitlement()` is callable and returns a Bool.
    /// The actual value depends on the build's code signature; we just verify it
    /// doesn't crash and returns consistently across two calls.
    func testPVJITHasNativeJITEntitlementIsStable() {
        let first = PVJITHasNativeJITEntitlement()
        let second = PVJITHasNativeJITEntitlement()
        XCTAssertEqual(first, second,
                       "PVJITHasNativeJITEntitlement() must return a consistent value")
    }

    /// Verifies that `PVJITIsInstalledViaTrollStore()` is callable and returns false
    /// in the test environment (no TrollStore markers present on CI runners or simulators).
    func testPVJITIsInstalledViaTrollStoreReturnsFalseInTestEnvironment() {
        // TrollStore markers won't be present on simulators or CI runners,
        // so this should always be false in those environments.
        #if targetEnvironment(simulator)
        XCTAssertFalse(PVJITIsInstalledViaTrollStore(),
                       "TrollStore detection must return false on the simulator")
        #endif
        // On real devices we only verify the call doesn't crash.
        _ = PVJITIsInstalledViaTrollStore()
    }
}

// MARK: - DOLJitType tests

final class DOLJitTypeTests: XCTestCase {

    // MARK: - New cases

    func testNewCasesExist() {
        // Verify the three new cases compile and are distinct.
        let stikDebug: DOLJitType = .stikDebug
        let trollStore: DOLJitType = .trollStore
        let nativeEntitlement: DOLJitType = .nativeEntitlement

        XCTAssertNotEqual(stikDebug, trollStore)
        XCTAssertNotEqual(trollStore, nativeEntitlement)
        XCTAssertNotEqual(stikDebug, nativeEntitlement)
    }

    func testNewCasesDistinctFromLegacy() {
        XCTAssertNotEqual(DOLJitType.stikDebug, .debugger)
        XCTAssertNotEqual(DOLJitType.trollStore, .notRestricted)
        XCTAssertNotEqual(DOLJitType.nativeEntitlement, .allowUnsigned)
    }

    func testAllLegacyCasesUnchanged() {
        // Ensure legacy raw values are stable (they map to ObjC enum values
        // used across the bridge, so changing them would be ABI-breaking).
        XCTAssertEqual(DOLJitType.none.rawValue, 0)
        XCTAssertEqual(DOLJitType.debugger.rawValue, 1)
        XCTAssertEqual(DOLJitType.allowUnsigned.rawValue, 2)
        XCTAssertEqual(DOLJitType.notRestricted.rawValue, 3)
        XCTAssertEqual(DOLJitType.ptrace.rawValue, 4)
    }

    func testNewCaseRawValues() {
        // New cases follow on from legacy values; verify they are distinct.
        XCTAssertEqual(DOLJitType.stikDebug.rawValue, 5)
        XCTAssertEqual(DOLJitType.trollStore.rawValue, 6)
        XCTAssertEqual(DOLJitType.nativeEntitlement.rawValue, 7)
    }

    func testDOLJitTypeSendableConformance() {
        let jitType: DOLJitType = .stikDebug
        let expectation = XCTestExpectation(description: "Sendable DOLJitType crosses concurrency boundary")
        Task.detached {
            let captured: DOLJitType = jitType
            XCTAssertEqual(captured, .stikDebug)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
