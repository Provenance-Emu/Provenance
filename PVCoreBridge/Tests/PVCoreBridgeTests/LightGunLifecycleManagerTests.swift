//
//  LightGunLifecycleManagerTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import XCTest

// MARK: - Mock core

/// Minimal mock that conforms to LightGunResponder for testing.
final class MockLightGunCore: NSObject, LightGunResponder {
    var gameSupportsLightGun: Bool
    var requiresLightGun: Bool = false

    var movedPoints: [(CGPoint, Bool)] = []
    var triggerDownCount = 0
    var triggerUpCount = 0

    init(supportsLightGun: Bool = true) {
        self.gameSupportsLightGun = supportsLightGun
    }

    func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool) {
        movedPoints.append((point, isOffscreen))
    }

    func lightGunTriggerDown() { triggerDownCount += 1 }
    func lightGunTriggerUp()   { triggerUpCount += 1 }
}

// MARK: - Tests

@MainActor
final class LightGunLifecycleManagerTests: XCTestCase {

    var manager: LightGunLifecycleManager!

    override func setUp() {
        super.setUp()
        manager = LightGunLifecycleManager()
    }

    override func tearDown() {
        manager.detach()
        manager = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitiallyNotAttached() {
        XCTAssertFalse(manager.isAttached)
    }

    // MARK: - attach(to:)

    func testAttachToSupportingCoreMarksAttached() {
        let core = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: core)
        XCTAssertTrue(manager.isAttached)
    }

    func testAttachToNonSupportingCoreRemainsNotAttached() {
        let core = MockLightGunCore(supportsLightGun: false)
        manager.attach(to: core)
        XCTAssertFalse(manager.isAttached)
    }

    /// Passing a `gameSupportsLightGun == false` core to `attach` must first detach
    /// any previously-attached driver (it is not a pure no-op).
    func testAttachToNonSupportingCoreDetachesPreviousDriver() {
        let first = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: first)
        XCTAssertTrue(manager.isAttached, "precondition: attached to first core")

        let second = MockLightGunCore(supportsLightGun: false)
        manager.attach(to: second)
        XCTAssertFalse(manager.isAttached, "previous driver must be detached when new core doesn't support light gun")
    }

    func testDoubleAttachDetachesPreviousDriver() {
        let first = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: first)
        XCTAssertTrue(manager.isAttached)

        let second = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: second)
        // Still attached after re-attach
        XCTAssertTrue(manager.isAttached)
    }

    // MARK: - detach()

    func testDetachClearsAttachedState() {
        let core = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: core)
        manager.detach()
        XCTAssertFalse(manager.isAttached)
    }

    func testDetachWithoutAttachIsNoOp() {
        // Must not crash or throw
        manager.detach()
        XCTAssertFalse(manager.isAttached)
    }

    func testMultipleDetachCallsAreIdempotent() {
        let core = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: core)
        manager.detach()
        manager.detach()
        XCTAssertFalse(manager.isAttached)
    }

    // MARK: - isAttached weak reference behaviour

    func testIsAttachedReturnsFalseAfterCoreDeallocates() {
        var core: MockLightGunCore? = MockLightGunCore(supportsLightGun: true)
        manager.attach(to: core!)
        XCTAssertTrue(manager.isAttached)

        core = nil  // deallocate — weak ref in manager becomes nil
        XCTAssertFalse(manager.isAttached, "isAttached must reflect core deallocation")
    }
}
