// CompanionControllerCapableTests.swift
// PVCoreBridgeTests
//
// Verifies that CompanionControllerCapable protocol conformance works correctly
// and that CompanionInputEvent values round-trip as expected.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

@testable import PVCoreBridge
import XCTest

// MARK: - Mock core

/// Minimal mock that records received companion input events.
final class MockCompanionCapableCore: CompanionControllerCapable {

    struct RecordedEvent: Equatable {
        let event: CompanionInputEvent
        let player: Int
    }

    private(set) var receivedEvents: [RecordedEvent] = []

    func handleCompanionInput(_ event: CompanionInputEvent, forPlayer player: Int) {
        receivedEvents.append(RecordedEvent(event: event, player: player))
    }
}

extension CompanionInputEvent: Equatable {
    public static func == (lhs: CompanionInputEvent, rhs: CompanionInputEvent) -> Bool {
        switch (lhs, rhs) {
        case (.buttonDown(let a), .buttonDown(let b)):     return a == b
        case (.buttonUp(let a),   .buttonUp(let b)):       return a == b
        case (.axisChanged(let a, let va), .axisChanged(let b, let vb)):
            return a == b && va == vb
        default:
            return false
        }
    }
}

// MARK: - Tests

final class CompanionControllerCapableTests: XCTestCase {

    // MARK: Protocol conformance

    func testMockCoreConformsToProtocol() {
        let core: any CompanionControllerCapable = MockCompanionCapableCore()
        XCTAssertNotNil(core)
    }

    // MARK: Event delivery — happy path

    func testButtonDownEventIsDelivered() {
        let core = MockCompanionCapableCore()
        core.handleCompanionInput(.buttonDown(.south), forPlayer: 0)
        XCTAssertEqual(core.receivedEvents.count, 1)
        XCTAssertEqual(core.receivedEvents[0].event, .buttonDown(.south))
        XCTAssertEqual(core.receivedEvents[0].player, 0)
    }

    func testButtonUpEventIsDelivered() {
        let core = MockCompanionCapableCore()
        core.handleCompanionInput(.buttonUp(.north), forPlayer: 1)
        XCTAssertEqual(core.receivedEvents.count, 1)
        XCTAssertEqual(core.receivedEvents[0].event, .buttonUp(.north))
        XCTAssertEqual(core.receivedEvents[0].player, 1)
    }

    func testAxisEventIsDelivered() {
        let core = MockCompanionCapableCore()
        core.handleCompanionInput(.axisChanged(.leftX, 0.75), forPlayer: 0)
        XCTAssertEqual(core.receivedEvents.count, 1)
        XCTAssertEqual(core.receivedEvents[0].event, .axisChanged(.leftX, 0.75))
    }

    // MARK: Edge cases

    func testMultipleEventsAccumulate() {
        let core = MockCompanionCapableCore()
        core.handleCompanionInput(.buttonDown(.l1), forPlayer: 0)
        core.handleCompanionInput(.buttonDown(.r1), forPlayer: 0)
        core.handleCompanionInput(.buttonUp(.l1),   forPlayer: 0)
        XCTAssertEqual(core.receivedEvents.count, 3)
    }

    func testPlayerIndexIsPreserved() {
        let core = MockCompanionCapableCore()
        for player in 0..<4 {
            core.handleCompanionInput(.buttonDown(.start), forPlayer: player)
        }
        let players = core.receivedEvents.map { $0.player }
        XCTAssertEqual(players, [0, 1, 2, 3])
    }

    func testNumpadButtonsAreDistinct() {
        // Ensure the numpad bitmasks don't overlap with standard buttons.
        let numpadButtons: [CompanionButton] = [
            .num0, .num1, .num2, .num3, .num4,
            .num5, .num6, .num7, .num8, .num9,
            .numStar, .numHash
        ]
        let standardButtons: [CompanionButton] = [
            .south, .east, .west, .north,
            .l1, .r1, .l2, .r2,
            .select, .start, .l3, .r3,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight
        ]
        for numpad in numpadButtons {
            for standard in standardButtons {
                XCTAssertEqual(
                    numpad.rawValue & standard.rawValue,
                    0,
                    "Bitmask overlap between \(numpad) and \(standard)"
                )
            }
        }
    }

    func testAllCasesAreUnique() {
        let rawValues = CompanionButton.allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(
            rawValues.count,
            uniqueRawValues.count,
            "CompanionButton has duplicate rawValues"
        )
    }
}
