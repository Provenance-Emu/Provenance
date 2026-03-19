//
//  MouseGameRegistryTests.swift
//  PVCoreBridgeTests
//
//  Created by Claude (Agent) on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class MouseGameRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MouseGameRegistry.shared._reset()
    }

    // MARK: - Baseline

    func testAlwaysMouseSystemsAreNonEmpty() {
        XCTAssertFalse(MouseGameRegistry.alwaysMouseSystems.isEmpty)
        XCTAssertTrue(MouseGameRegistry.alwaysMouseSystems.contains(.DOS))
        XCTAssertTrue(MouseGameRegistry.alwaysMouseSystems.contains(.Macintosh))
        XCTAssertTrue(MouseGameRegistry.alwaysMouseSystems.contains(.AtariST))
    }

    func testConditionalMouseSystemsAreNonEmpty() {
        XCTAssertFalse(MouseGameRegistry.conditionalMouseSystems.isEmpty)
        XCTAssertTrue(MouseGameRegistry.conditionalMouseSystems.contains(.SNES))
        XCTAssertTrue(MouseGameRegistry.conditionalMouseSystems.contains(.Saturn))
        XCTAssertTrue(MouseGameRegistry.conditionalMouseSystems.contains(.Dreamcast))
        XCTAssertTrue(MouseGameRegistry.conditionalMouseSystems.contains(.PSX))
    }

    func testAlwaysAndConditionalSetsAreDisjoint() {
        let intersection = MouseGameRegistry.alwaysMouseSystems.intersection(
            MouseGameRegistry.conditionalMouseSystems
        )
        XCTAssertTrue(intersection.isEmpty,
                      "A system cannot be both always-mouse and conditional: \(intersection)")
    }

    // MARK: - Always-mouse systems

    func testDOSAlwaysReturnsTrueRegardlessOfGame() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .DOS, md5: nil, title: nil)
        )
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .DOS, md5: "somemd5", title: "Some DOS Game")
        )
    }

    func testMacintoshAlwaysReturnsTrueRegardlessOfGame() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Macintosh, md5: nil, title: nil)
        )
    }

    // MARK: - Non-mouse systems

    func testNonMouseSystemReturnsFalse() {
        // NES has light gun support but not mouse support
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .NES, md5: nil, title: "Some NES Game")
        )
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .GB, md5: nil, title: nil)
        )
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .GBA, md5: nil, title: nil)
        )
    }

    // MARK: - SNES conditional detection

    func testSNESUnknownGameReturnsFalse() {
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Super Mario World")
        )
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Donkey Kong Country")
        )
    }

    func testSNESMarioPaintDetectedByTitle() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Mario Paint (USA)")
        )
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "MARIO PAINT")
        )
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Mario Paint (Japan)")
        )
    }

    func testSNESMarioAndWardioDetectedByTitle() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Mario & Wario (Japan)")
        )
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Mario and Wario")
        )
    }

    func testSNESUndeadLineDetectedByTitle() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Undead Line")
        )
    }

    func testSNESMarioPaintDetectedByMD5() {
        // Mario Paint (USA) MD5
        let md5 = "d6f64fd0642a514a5fba4707fca4f1ed"
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: md5, title: nil)
        )
    }

    func testMD5CaseInsensitive() {
        let md5Upper = "D6F64FD0642A514A5FBA4707FCA4F1ED"
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: md5Upper, title: nil)
        )
    }

    // MARK: - User override

    func testUserOverrideForcesMouseOnForUnknownGame() {
        let md5 = "unknownmd5hash"
        MouseGameRegistry.shared.setUserOverride(true, forMD5: md5)
        defer { MouseGameRegistry.shared.setUserOverride(nil, forMD5: md5) }

        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: md5, title: "Unknown SNES Game")
        )
    }

    func testUserOverrideForcesMouseOffForKnownGame() {
        let md5 = "d6f64fd0642a514a5fba4707fca4f1ed" // Mario Paint (USA)
        MouseGameRegistry.shared.setUserOverride(false, forMD5: md5)
        defer { MouseGameRegistry.shared.setUserOverride(nil, forMD5: md5) }

        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: md5, title: "Mario Paint (USA)")
        )
    }

    func testUserOverrideClearRestoresAutoDetection() {
        let md5 = "d6f64fd0642a514a5fba4707fca4f1ed" // Mario Paint (USA)
        MouseGameRegistry.shared.setUserOverride(false, forMD5: md5)
        MouseGameRegistry.shared.setUserOverride(nil, forMD5: md5)

        // After clearing, title-based detection should kick in
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: md5, title: "Mario Paint (USA)")
        )
    }

    func testUserOverrideReturnsNilWhenNotSet() {
        XCTAssertNil(MouseGameRegistry.shared.userOverride(forMD5: "neverseenmd5"))
    }

    // MARK: - Dynamic registration

    func testRegisterNewMD5() {
        let newMD5 = "cafebabe00000000000000000000cafe"
        MouseGameRegistry.shared.registerKnownMouseGameMD5(newMD5)
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: newMD5, title: nil)
        )
    }

    func testRegisterNewTitlePattern() {
        MouseGameRegistry.shared.registerTitlePattern("my mouse game", forSystem: .Saturn)
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Saturn, md5: nil, title: "My Mouse Game - Special Edition")
        )
    }

    func testRegisterAlwaysMouseSystem() {
        // Atari 2600 is not normally a mouse system
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Atari2600, md5: nil, title: nil)
        )
        MouseGameRegistry.shared.registerAlwaysMouseSystem(.Atari2600)
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Atari2600, md5: nil, title: nil)
        )
    }

    func testRegisterAlwaysSystemPromotesFromConditional() {
        // SNES starts as conditional
        XCTAssertTrue(MouseGameRegistry.conditionalMouseSystems.contains(.SNES))
        MouseGameRegistry.shared.registerAlwaysMouseSystem(.SNES)
        // After promotion, any SNES game should return true
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .SNES, md5: nil, title: "Super Mario World")
        )
    }

    // MARK: - Dreamcast / Saturn conditional detection

    func testSaturnUnknownGameReturnsFalse() {
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Saturn, md5: nil, title: "Virtua Fighter 2")
        )
    }

    func testSaturnTypingOfTheDeadDetectedByTitle() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Saturn, md5: nil, title: "Typing of the Dead (Japan)")
        )
    }

    func testDreamcastTypingOfTheDeadDetectedByTitle() {
        XCTAssertTrue(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Dreamcast, md5: nil, title: "Typing of the Dead")
        )
    }

    func testDreamcastUnknownGameReturnsFalse() {
        XCTAssertFalse(
            MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier: .Dreamcast, md5: nil, title: "Sonic Adventure 2")
        )
    }
}
