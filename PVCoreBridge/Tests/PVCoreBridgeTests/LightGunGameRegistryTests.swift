//
//  LightGunGameRegistryTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class LightGunGameRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear persisted user overrides so tests don't bleed into each other.
        let prefix = "LightGunGameRegistry.lightGunEnabled."
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        LightGunGameRegistry.shared._reset()
    }

    // MARK: - Baseline

    func testConditionalLightGunSystemsAreNonEmpty() {
        XCTAssertFalse(LightGunGameRegistry.conditionalLightGunSystems.isEmpty)
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.NES))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.SNES))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.PSX))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.Saturn))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.SegaCD))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.Genesis))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.MasterSystem))
        XCTAssertTrue(LightGunGameRegistry.conditionalLightGunSystems.contains(.FDS))
    }

    func testAlwaysAndConditionalSetsAreDisjoint() {
        let intersection = LightGunGameRegistry.alwaysLightGunSystems.intersection(
            LightGunGameRegistry.conditionalLightGunSystems
        )
        XCTAssertTrue(intersection.isEmpty,
                      "A system cannot be both always-gun and conditional: \(intersection)")
    }

    // MARK: - Non-gun systems

    func testNonGunSystemReturnsFalse() {
        // GB / GBC / GBA never had a gun peripheral.
        XCTAssertFalse(
            LightGunGameRegistry.shared.gameSupportsLightGun(systemIdentifier: .GB, md5: nil, title: "anything")
        )
        XCTAssertFalse(
            LightGunGameRegistry.shared.gameSupportsLightGun(systemIdentifier: .GBA, md5: nil, title: nil)
        )
        XCTAssertFalse(
            LightGunGameRegistry.shared.gameSupportsLightGun(systemIdentifier: .N64, md5: nil, title: nil)
        )
    }

    // MARK: - Title pattern matching

    func testNESDuckHuntMatchesByTitle() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: nil, title: "Duck Hunt (USA)"
            )
        )
    }

    func testNESBombermanReturnsFalse() {
        // The exact NES regression that motivated the registry: Bomberman II
        // must NOT trigger the cursor overlay even though NES has the Zapper.
        XCTAssertFalse(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: "deadbeef", title: "Bomberman II (USA)"
            )
        )
    }

    func testSNESSuperScopeTitleMatches() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .SNES, md5: nil, title: "Yoshi's Safari (USA)"
            )
        )
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .SNES, md5: nil, title: "Battle Clash (USA)"
            )
        )
    }

    func testPSXGunConTitleMatches() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .PSX, md5: nil, title: "Time Crisis"
            )
        )
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .PSX, md5: nil, title: "Point Blank (USA)"
            )
        )
    }

    func testSaturnStunnerTitleMatches() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .Saturn, md5: nil, title: "Virtua Cop (USA)"
            )
        )
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .Saturn, md5: nil, title: "The House of the Dead"
            )
        )
    }

    func testGenesisMenacerTitleMatches() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .Genesis, md5: nil, title: "Menacer 6-Game Cartridge"
            )
        )
    }

    func testMasterSystemLightPhaserTitleMatches() {
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .MasterSystem, md5: nil, title: "Operation Wolf"
            )
        )
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .MasterSystem, md5: nil, title: "Space Gun"
            )
        )
    }

    // MARK: - MD5 matching

    func testMD5MatchOverridesTitleMiss() {
        let duckHuntUSA = "fbc23a35a4ad8c1f10b9b9cea48f95a3"
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: duckHuntUSA, title: "Some Renamed File"
            )
        )
    }

    func testMD5MatchIsCaseInsensitive() {
        let duckHuntUSA = "FBC23A35A4AD8C1F10B9B9CEA48F95A3"
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: duckHuntUSA, title: nil
            )
        )
    }

    // MARK: - User override

    func testUserOverrideForcesOn() {
        let md5 = "newgamemd5"
        LightGunGameRegistry.shared.setUserOverride(true, forMD5: md5)
        defer { LightGunGameRegistry.shared.setUserOverride(nil, forMD5: md5) }
        // NES with an unknown title — would normally return false.
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: md5, title: "Some Homebrew Zapper Game"
            )
        )
    }

    func testUserOverrideForcesOff() {
        let md5 = "fbc23a35a4ad8c1f10b9b9cea48f95a3"
        LightGunGameRegistry.shared.setUserOverride(false, forMD5: md5)
        defer { LightGunGameRegistry.shared.setUserOverride(nil, forMD5: md5) }
        // Duck Hunt would normally return true.
        XCTAssertFalse(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .NES, md5: md5, title: "Duck Hunt"
            )
        )
    }

    // MARK: - Dynamic registration

    func testRegisterTitlePatternMatchesAfterReset() {
        LightGunGameRegistry.shared.registerTitlePattern("plumbers don't wear ties", forSystem: .PSX)
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .PSX, md5: nil, title: "Plumbers Don't Wear Ties"
            )
        )
    }

    func testRegisterMD5MatchesAfterReset() {
        LightGunGameRegistry.shared.registerKnownLightGunGameMD5("cafef00d")
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .SNES, md5: "cafef00d", title: nil
            )
        )
    }

    func testRegisterConditionalSystem() {
        // Atari 2600 has Sears Light Gun support (Booby Trap, etc.) but isn't
        // in the default conditional set. Add it dynamically and verify.
        LightGunGameRegistry.shared.registerConditionalLightGunSystem(.Atari2600)
        LightGunGameRegistry.shared.registerTitlePattern("booby trap", forSystem: .Atari2600)
        XCTAssertTrue(
            LightGunGameRegistry.shared.gameSupportsLightGun(
                systemIdentifier: .Atari2600, md5: nil, title: "Booby Trap (Sears)"
            )
        )
    }
}
