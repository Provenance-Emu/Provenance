//
//  PVJITTests.swift
//  PVJITTests
//
//  Tests for PVJIT JIT detection types.
//

import XCTest
@testable import JITManager

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
