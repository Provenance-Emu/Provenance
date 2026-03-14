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
