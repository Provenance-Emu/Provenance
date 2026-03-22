// TrackballGameRegistryTests.swift
// PVCoreBridgeTests
//
// Unit tests for TrackballGameRegistry — per-game trackball detection.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

@testable import PVCoreBridge
import PVSystems
import XCTest

final class TrackballGameRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any persisted user overrides from previous test runs.
        let prefix = "TrackballGameRegistry.trackballEnabled."
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        TrackballGameRegistry.shared._reset()
    }

    // MARK: - Baseline data

    func testConditionalSystemsIncludesAtari2600() {
        XCTAssertTrue(TrackballGameRegistry.conditionalTrackballSystems.contains(.Atari2600))
    }

    func testAlwaysSystemsIsEmpty() {
        // No system requires a trackball for every game.
        XCTAssertTrue(TrackballGameRegistry.alwaysTrackballSystems.isEmpty)
    }

    // MARK: - Known MD5 matches

    func testKnownMD5CentipedeMatchesAtari2600() {
        // Centipede (USA) MD5
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: "8fba5f7b8ad75179290e5c8c3ac86095",
            title: nil
        )
        XCTAssertTrue(result, "Centipede (USA) should be detected as trackball game by MD5")
    }

    func testKnownMD5MissileCommandMatchesAtari2600() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: "ddaeff25bdf5b82d5ee9b4fb41e45d89",
            title: nil
        )
        XCTAssertTrue(result, "Missile Command (USA) should be detected as trackball game by MD5")
    }

    func testUnknownMD5ReturnsFalse() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: "00000000000000000000000000000000",
            title: nil
        )
        XCTAssertFalse(result, "Unknown MD5 should not be treated as trackball game")
    }

    // MARK: - Title keyword matches

    func testTitleCentipedeMatchesAtari2600() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "Centipede (USA)"
        )
        XCTAssertTrue(result, "Title containing 'centipede' should match")
    }

    func testTitleMissileCommandMatchesAtari2600() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "Missile Command"
        )
        XCTAssertTrue(result, "Title containing 'missile command' should match")
    }

    func testTitleCrystalCastlesMatchesAtari2600() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "Crystal Castles (USA)"
        )
        XCTAssertTrue(result, "Title containing 'crystal castles' should match")
    }

    func testTitleCaseInsensitiveMatch() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "CENTIPEDE"
        )
        XCTAssertTrue(result, "Title matching should be case-insensitive")
    }

    func testUnknownTitleReturnsFalse() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "Pitfall!"
        )
        XCTAssertFalse(result, "Pitfall! is a joystick game and should not be treated as trackball")
    }

    // MARK: - Non-Atari2600 system returns false

    func testNESReturnsFalseForTrackball() {
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .NES,
            md5: nil,
            title: "Centipede"
        )
        XCTAssertFalse(result, "NES is not a trackball system")
    }

    // MARK: - Dynamic registration

    func testDynamicMD5Registration() {
        let fakeMD5 = "aaabbbccc111222333"
        TrackballGameRegistry.shared.registerKnownTrackballGameMD5(fakeMD5)
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: fakeMD5,
            title: nil
        )
        XCTAssertTrue(result, "Dynamically registered MD5 should be recognised")
    }

    func testDynamicTitlePatternRegistration() {
        TrackballGameRegistry.shared.registerTitlePattern("super trackball", forSystem: .Atari2600)
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: nil,
            title: "Super Trackball Deluxe"
        )
        XCTAssertTrue(result, "Dynamically registered title pattern should match")
    }

    // MARK: - User override

    func testUserOverrideForceEnablesTrackball() {
        let md5 = "pitfall_md5"
        TrackballGameRegistry.shared.setUserOverride(true, forMD5: md5)
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: md5,
            title: "Pitfall!"
        )
        XCTAssertTrue(result, "User override=true should force trackball on for any game")
    }

    func testUserOverrideForceDisablesTrackball() {
        let md5 = "8fba5f7b8ad75179290e5c8c3ac86095" // Centipede USA
        TrackballGameRegistry.shared.setUserOverride(false, forMD5: md5)
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: md5,
            title: "Centipede"
        )
        XCTAssertFalse(result, "User override=false should suppress trackball for known title")
    }

    func testUserOverrideClearRestoresAutoDetection() {
        let md5 = "8fba5f7b8ad75179290e5c8c3ac86095" // Centipede USA
        TrackballGameRegistry.shared.setUserOverride(false, forMD5: md5)
        TrackballGameRegistry.shared.setUserOverride(nil, forMD5: md5)  // clear
        let result = TrackballGameRegistry.shared.gameUsesTrackball(
            systemIdentifier: .Atari2600,
            md5: md5,
            title: "Centipede"
        )
        XCTAssertTrue(result, "After clearing user override, auto-detection should resume")
    }

    // MARK: - systemHasAnyTrackballSupport

    func testSystemHasAnyTrackballSupportForAtari2600() {
        XCTAssertTrue(TrackballGameRegistry.shared.systemHasAnyTrackballSupport(.Atari2600))
    }

    func testSystemHasNoTrackballSupportForNES() {
        XCTAssertFalse(TrackballGameRegistry.shared.systemHasAnyTrackballSupport(.NES))
    }
}
