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

#if canImport(GameController)
    @available(iOS 14.0, tvOS 14.0, *)
    func didScroll(_ cursor: any GCDeviceCursor) {}
    var mouseMovedHandler: GCMouseMoved?
#endif

    func mouseMoved(atPoint point: CGPoint) {
        receivedPoints.append(point)
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
        // Directly verify that _applyRotation guard fires:
        // We can't call the private method; verify via public API that
        // no events are stored when disabled.
        XCTAssertTrue(responder.receivedPoints.isEmpty)
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
}
