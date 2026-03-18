//
//  LightGunSystemRegistryTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class LightGunSystemRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to a clean slate for each test so tests are independent.
        LightGunSystemRegistry.shared._reset(to: [])
    }

    // MARK: - Baseline

    func testBaselineContainsExpectedSystems() {
        // Reset to the actual baseline seeded by init() to verify the registry
        // correctly includes all known lightgun-capable systems.
        LightGunSystemRegistry.shared._reset(to: LightGunSystemRegistry.baseline)

        for system in LightGunSystemRegistry.baseline {
            XCTAssertTrue(
                LightGunSystemRegistry.shared.supportsLightGun(system),
                "\(system) should be in the baseline"
            )
        }
    }

    func testInitBaselineIsNonEmpty() {
        // The static baseline constant must contain at least the well-known systems.
        XCTAssertFalse(LightGunSystemRegistry.baseline.isEmpty)
        XCTAssertTrue(LightGunSystemRegistry.baseline.contains(.NES))
        XCTAssertTrue(LightGunSystemRegistry.baseline.contains(.SNES))
        XCTAssertTrue(LightGunSystemRegistry.baseline.contains(.PSX))
    }

    func testUnknownSystemReturnsFalse() {
        XCTAssertFalse(LightGunSystemRegistry.shared.supportsLightGun(.GameBoy))
    }

    // MARK: - register(system:)

    func testRegisterSingleSystem() {
        LightGunSystemRegistry.shared.register(system: .NES)
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.NES))
    }

    func testRegisterSameSystemTwiceIsIdempotent() {
        LightGunSystemRegistry.shared.register(system: .SNES)
        LightGunSystemRegistry.shared.register(system: .SNES)
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.SNES))
        XCTAssertEqual(LightGunSystemRegistry.shared.registeredSystems.filter { $0 == .SNES }.count, 1)
    }

    // MARK: - register(systems:)

    func testRegisterSetOfSystems() {
        let systems: Set<SystemIdentifier> = [.Genesis, .Saturn]
        LightGunSystemRegistry.shared.register(systems: systems)
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.Genesis))
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.Saturn))
    }

    // MARK: - registerProvider

    func testRegisterProviderAddsItsSystems() {
        LightGunSystemRegistry.shared.registerProvider(MockLightGunProvider.self)
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.PSX))
        XCTAssertTrue(LightGunSystemRegistry.shared.supportsLightGun(.NES))
        XCTAssertFalse(LightGunSystemRegistry.shared.supportsLightGun(.GameBoy))
    }

    // MARK: - registeredSystems snapshot

    func testRegisteredSystemsIsSnapshot() {
        LightGunSystemRegistry.shared.register(system: .Atari2600)
        let snapshot = LightGunSystemRegistry.shared.registeredSystems
        LightGunSystemRegistry.shared.register(system: .MAME)
        // The snapshot must not reflect the later addition.
        XCTAssertFalse(snapshot.contains(.MAME))
        XCTAssertTrue(LightGunSystemRegistry.shared.registeredSystems.contains(.MAME))
    }
}

// MARK: - Test helpers

private final class MockLightGunProvider: LightGunSystemsProvider {
    static var lightGunSupportedSystemIdentifiers: Set<SystemIdentifier> { [.PSX, .NES] }
}
