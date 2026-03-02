//
//  ControllerProfileTests.swift
//  PVLibrary
//
//  Created by Copilot on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import XCTest
import RealmSwift
@testable import PVLibrary

/// Tests for `RomDatabase+ControllerProfiles` – profile creation, activation,
/// and the resolution priority order (game+core > game > system+core > system > global).
///
/// All tests use a per-test in-memory Realm so they never touch the real database.
final class ControllerProfileTests: XCTestCase {

    // MARK: - Constants

    private let vendor = "TestController"
    private let system = "com.provenance.nes"
    private let core   = "com.provenance.fceux"
    private let game   = "deadbeef01234567"

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Point every `try! Realm()` call in this test process at an isolated in-memory store.
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            inMemoryIdentifier: "ControllerProfileTests-\(name)"
        )
    }

    override func tearDown() {
        // Wipe all objects so state never leaks between tests.
        if let realm = try? Realm() {
            try? realm.write { realm.deleteAll() }
        }
        super.tearDown()
    }

    // MARK: - Helpers

    /// Returns a fresh database context backed by the current default (in-memory) Realm.
    private var db: RomDatabase { RomDatabase.sharedInstance }

    // MARK: - Creation tests

    func testAddControllerProfile_createsWithCorrectProperties() throws {
        let profile = try db.addControllerProfile(
            name: "TestProfile",
            controllerVendorName: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: game,
            mappings: [
                (source: "buttonA", destination: "buttonB"),
                (source: "buttonX", destination: "buttonY")
            ]
        )

        XCTAssertEqual(profile.name, "TestProfile")
        XCTAssertEqual(profile.controllerVendorName, vendor)
        XCTAssertEqual(profile.systemIdentifier, system)
        XCTAssertEqual(profile.coreIdentifier, core)
        XCTAssertEqual(profile.gameID, game)
        XCTAssertEqual(profile.mappings.count, 2)
        XCTAssertFalse(profile.isActive, "Newly created profiles should not be active by default")
    }

    func testAddControllerProfile_globalScope_hasNilScopeFields() throws {
        let profile = try db.addControllerProfile(
            name: "GlobalProfile",
            controllerVendorName: vendor
        )

        XCTAssertNil(profile.systemIdentifier)
        XCTAssertNil(profile.coreIdentifier)
        XCTAssertNil(profile.gameID)
    }

    // MARK: - Activation tests

    func testActivateControllerProfile_setsIsActive() throws {
        let profile = try db.addControllerProfile(name: "P1", controllerVendorName: vendor)
        XCTAssertFalse(profile.isActive)

        try db.activateControllerProfile(profile)

        XCTAssertTrue(profile.isActive)
    }

    func testActivateControllerProfile_deactivatesPreviousProfileInSameScope() throws {
        let first  = try db.addControllerProfile(name: "First",  controllerVendorName: vendor)
        let second = try db.addControllerProfile(name: "Second", controllerVendorName: vendor)

        try db.activateControllerProfile(first)
        XCTAssertTrue(first.isActive, "First profile should be active after activation")

        try db.activateControllerProfile(second)
        XCTAssertFalse(first.isActive,  "Previous active profile should be deactivated")
        XCTAssertTrue(second.isActive,  "New profile should now be active")
    }

    func testActivateControllerProfile_doesNotDeactivateProfilesInDifferentScope() throws {
        let global = try db.addControllerProfile(name: "Global", controllerVendorName: vendor)
        let system = try db.addControllerProfile(name: "System", controllerVendorName: vendor, systemIdentifier: self.system)

        try db.activateControllerProfile(global)
        try db.activateControllerProfile(system)

        // System-scope activation should NOT have deactivated the global-scope profile
        // because they are in different scopes.
        XCTAssertTrue(global.isActive, "Global-scope profile should remain active when a different-scope profile is activated")
        XCTAssertTrue(system.isActive, "System-scope profile should be active")
    }

    // MARK: - Resolution priority tests

    /// Priority 1: game + core beats everything else.
    func testActiveProfileResolution_gamePlusCoreTakesPrecedence() throws {
        let global      = try makeActive(name: "global",      system: nil,        core: nil,       game: nil)
        let systemOnly  = try makeActive(name: "systemOnly",  system: self.system, core: nil,       game: nil)
        let systemCore  = try makeActive(name: "systemCore",  system: self.system, core: self.core, game: nil)
        let gameOnly    = try makeActive(name: "gameOnly",    system: nil,        core: nil,       game: self.game)
        let gameCore    = try makeActive(name: "gameCore",    system: nil,        core: self.core, game: self.game)

        _ = (global, systemOnly, systemCore, gameOnly) // suppress unused warnings

        let resolved = db.activeControllerProfile(
            forVendor: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: game
        )

        XCTAssertEqual(resolved?.name, gameCore.name,
                       "game+core profile must beat all less-specific profiles")
    }

    /// Priority 2: game (no core) beats system+core, system, and global.
    func testActiveProfileResolution_gameWithoutCoreBeatsSmallerScopes() throws {
        let global      = try makeActive(name: "global",      system: nil,        core: nil,       game: nil)
        let systemOnly  = try makeActive(name: "systemOnly",  system: self.system, core: nil,       game: nil)
        let systemCore  = try makeActive(name: "systemCore",  system: self.system, core: self.core, game: nil)
        let gameOnly    = try makeActive(name: "gameOnly",    system: nil,        core: nil,       game: self.game)

        _ = (global, systemOnly, systemCore) // suppress unused warnings

        let resolved = db.activeControllerProfile(
            forVendor: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: game
        )

        XCTAssertEqual(resolved?.name, gameOnly.name,
                       "game-only profile must beat system+core, system-only and global profiles")
    }

    /// Priority 3: system + core beats system-only and global.
    func testActiveProfileResolution_systemPlusCoreBeatsSmallerScopes() throws {
        let global      = try makeActive(name: "global",     system: nil,        core: nil,       game: nil)
        let systemOnly  = try makeActive(name: "systemOnly", system: self.system, core: nil,       game: nil)
        let systemCore  = try makeActive(name: "systemCore", system: self.system, core: self.core, game: nil)

        _ = (global, systemOnly) // suppress unused warnings

        let resolved = db.activeControllerProfile(
            forVendor: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: nil
        )

        XCTAssertEqual(resolved?.name, systemCore.name,
                       "system+core profile must beat system-only and global profiles")
    }

    /// Priority 4: system (no core) beats global.
    func testActiveProfileResolution_systemOnlyBeatsGlobal() throws {
        let global     = try makeActive(name: "global",     system: nil,        core: nil, game: nil)
        let systemOnly = try makeActive(name: "systemOnly", system: self.system, core: nil, game: nil)

        _ = global // suppress unused warning

        let resolved = db.activeControllerProfile(
            forVendor: vendor,
            systemIdentifier: system,
            coreIdentifier: nil,
            gameID: nil
        )

        XCTAssertEqual(resolved?.name, systemOnly.name,
                       "system-only profile must beat global profile")
    }

    /// Priority 5: global is the final fallback.
    func testActiveProfileResolution_globalFallback() throws {
        let global = try makeActive(name: "global", system: nil, core: nil, game: nil)

        let resolved = db.activeControllerProfile(
            forVendor: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: game
        )

        XCTAssertEqual(resolved?.name, global.name,
                       "global profile must be returned when no more-specific active profile exists")
    }

    /// When no active profile exists, `activeControllerProfile` should return nil.
    func testActiveProfileResolution_returnsNilWhenNoneActive() throws {
        _ = try db.addControllerProfile(name: "Inactive", controllerVendorName: vendor)
        // Do NOT activate it.

        let resolved = db.activeControllerProfile(forVendor: vendor)

        XCTAssertNil(resolved, "Should return nil when no profile is active")
    }

    // MARK: - Private helpers

    /// Convenience: create a profile with the given scope and immediately activate it.
    @discardableResult
    private func makeActive(
        name: String,
        system: String?,
        core: String?,
        game: String?
    ) throws -> PVControllerProfile {
        let profile = try db.addControllerProfile(
            name: name,
            controllerVendorName: vendor,
            systemIdentifier: system,
            coreIdentifier: core,
            gameID: game
        )
        try db.activateControllerProfile(profile)
        return profile
    }
}
