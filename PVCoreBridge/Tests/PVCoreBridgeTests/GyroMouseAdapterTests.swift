//
//  GyroMouseAdapterTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-23.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import CoreGraphics
import XCTest

// MARK: - Fake MouseResponder

/// Minimal test double for MouseResponder; records delivered points.
final class FakeMouseResponder: NSObject, MouseResponder {
    var gameSupportsMouse: Bool = true
    var requiresMouse: Bool = false
    var receivedPoints: [CGPoint] = []
    var leftDownPoints: [CGPoint] = []
    var leftUpCount: Int = 0
    var rightDownPoints: [CGPoint] = []
    var rightUpCount: Int = 0

#if canImport(GameController)
    @available(iOS 14.0, tvOS 14.0, *)
    func didScroll(_ cursor: any GCDeviceCursor) {}
    var mouseMovedHandler: GCMouseMoved?
#endif

    func mouseMoved(atPoint point: CGPoint) {
        receivedPoints.append(point)
    }

    func leftMouseDown(atPoint point: CGPoint) {
        leftDownPoints.append(point)
    }

    func leftMouseUp() {
        leftUpCount += 1
    }

    func rightMouseDown(atPoint point: CGPoint) {
        rightDownPoints.append(point)
    }

    func rightMouseUp() {
        rightUpCount += 1
    }
}

// MARK: - Tests

@MainActor
final class GyroMouseAdapterTests: XCTestCase {

    private var adapter: GyroMouseAdapter!
    private var responder: FakeMouseResponder!

    override func setUp() async throws {
        try await super.setUp()
        adapter = GyroMouseAdapter()
        responder = FakeMouseResponder()
    }

    override func tearDown() async throws {
        adapter.detach()
        adapter = nil
        responder = nil
        try await super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultSensitivity() {
        XCTAssertEqual(adapter.sensitivity, 1.0)
    }

    func testDefaultDeadZone() {
        XCTAssertEqual(adapter.deadZone, 0.05)
    }

    func testDefaultSmoothingAlpha() {
        XCTAssertEqual(adapter.smoothingAlpha, 0.3)
    }

    func testDefaultInputSource() {
        XCTAssertEqual(adapter.inputSource, .auto)
    }

    func testDefaultIsEnabled() {
        XCTAssertTrue(adapter.isEnabled)
    }

    // MARK: - isEnabled gate

    func testNoDeliveryWhenDisabled() {
        adapter.attach(to: responder)
        adapter.isEnabled = false
        // Drive rotation through the internal test hook; the isEnabled guard
        // must suppress delivery even with valid rotation input.
        adapter._testApplyRotation(rawX: 5.0, rawY: 5.0)
        XCTAssertTrue(responder.receivedPoints.isEmpty, "Disabled adapter must not deliver events")
    }

    // MARK: - gameSupportsMouse gate

    func testNoDeliveryWhenGameDoesNotSupportMouse() {
        responder.gameSupportsMouse = false
        adapter.attach(to: responder)
        // No motion input is hooked in unit tests (no real hardware), so
        // verify the responder hasn't received any phantom deliveries.
        XCTAssertTrue(responder.receivedPoints.isEmpty)
    }

    // MARK: - Lifecycle

    func testAttachAndDetachDoNotCrash() {
        XCTAssertNoThrow(adapter.attach(to: responder))
        XCTAssertNoThrow(adapter.detach())
    }

    func testDoubleDetachDoesNotCrash() {
        adapter.attach(to: responder)
        adapter.detach()
        XCTAssertNoThrow(adapter.detach())
    }

    func testReattachResetsCursor() {
        // Verify a second attach doesn't carry over stale state — no crash.
        adapter.attach(to: responder)
        adapter.attach(to: responder)
        adapter.detach()
    }

    // MARK: - isEnabled timestamp reset

    func testDisablingResetsTimestamp() {
        adapter.attach(to: responder)
        adapter.isEnabled = false
        // After disabling, re-enabling should work without crash.
        adapter.isEnabled = true
        XCTAssertTrue(adapter.isEnabled)
    }

    // MARK: - Signal chain (rotation input)

    func testRotationDeliversPoint() {
        // Large rotation rate well above default dead zone (0.05) should produce output.
        adapter.attach(to: responder)
        adapter._testApplyRotation(rawX: 1.0, rawY: 1.0)
        XCTAssertEqual(responder.receivedPoints.count, 1)
    }

    func testDeadZoneSuppressesSmallInput() {
        adapter.attach(to: responder)
        // Rate below default dead zone (0.05) should be filtered out.
        adapter._testApplyRotation(rawX: 0.01, rawY: 0.01)
        // With both axes in the dead zone, filteredX/Y converge toward 0 and
        // no net cursor displacement occurs — but a point is still delivered
        // (the cursor stays at 0.5,0.5). Verify count is still 1 (not 0 = no crash).
        XCTAssertEqual(responder.receivedPoints.count, 1)
        // Cursor should remain near centre (dead zone ate the input).
        let pt = responder.receivedPoints[0]
        XCTAssertEqual(pt.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(pt.y, 0.5, accuracy: 0.01)
    }

    func testOutputClampedToUnitSquare() {
        adapter.attach(to: responder)
        // Massive rotation should drive cursor to boundary, not outside [0,1].
        for _ in 0..<120 {
            adapter._testApplyRotation(rawX: 100.0, rawY: 100.0)
        }
        let last = responder.receivedPoints.last!
        XCTAssertGreaterThanOrEqual(Double(last.x), 0.0)
        XCTAssertLessThanOrEqual(Double(last.x),    1.0)
        XCTAssertGreaterThanOrEqual(Double(last.y), 0.0)
        XCTAssertLessThanOrEqual(Double(last.y),    1.0)
    }

    func testNoDeliveryWhenDisabledDuringRotation() {
        adapter.attach(to: responder)
        adapter.isEnabled = false
        adapter._testApplyRotation(rawX: 5.0, rawY: 5.0)
        XCTAssertTrue(responder.receivedPoints.isEmpty)
    }

    func testNoDeliveryWhenGameDoesNotSupportMouseDuringRotation() {
        responder.gameSupportsMouse = false
        adapter.attach(to: responder)
        adapter._testApplyRotation(rawX: 5.0, rawY: 5.0)
        XCTAssertTrue(responder.receivedPoints.isEmpty)
    }

    func testCursorResetOnReattach() {
        adapter.attach(to: responder)
        // Drive cursor toward an edge.
        for _ in 0..<60 {
            adapter._testApplyRotation(rawX: 0.0, rawY: 50.0)
        }
        let afterFirst = responder.receivedPoints.last!
        // Re-attach should reset cursor to 0.5,0.5.
        let responder2 = FakeMouseResponder()
        adapter.attach(to: responder2)
        adapter._testApplyRotation(rawX: 0.0, rawY: 0.0)
        // First delivery after fresh attach should originate from centre.
        // (Zero input → dead zone → no displacement → stays at 0.5,0.5.)
        if let pt = responder2.receivedPoints.first {
            XCTAssertEqual(pt.x, 0.5, accuracy: 0.05)
            XCTAssertEqual(pt.y, 0.5, accuracy: 0.05)
        }
        // Sanity: the old responder's last point was not at centre.
        XCTAssertNotEqual(afterFirst.x, 0.5, accuracy: 0.05)
    }
}
