//
//  StringROMTitleTests.swift
//  PVPrimitivesTests
//

import XCTest
@testable import PVPrimitives

final class StringROMTitleTests: XCTestCase {

    // MARK: - normalizedROMTitle documented examples

    func testNormalizedROMTitle_bomberman() {
        XCTAssertEqual("Bomberman (USA) [!]".normalizedROMTitle(), "Bomberman")
    }

    func testNormalizedROMTitle_finalFantasyDisc() {
        XCTAssertEqual("Final Fantasy VII (Disc 2) (USA)".normalizedROMTitle(), "Final Fantasy VII")
    }

    func testNormalizedROMTitle_versionSuffix() {
        XCTAssertEqual("Sonic the Hedgehog v1.0".normalizedROMTitle(), "Sonic the Hedgehog")
    }

    func testNormalizedROMTitle_betaTag() {
        XCTAssertEqual("Game (Beta)".normalizedROMTitle(), "Game")
    }

    // MARK: - Disc/disk variants

    func testNormalizedROMTitle_diskVariant() {
        XCTAssertEqual("Metal Gear Solid (Disk 1)".normalizedROMTitle(), "Metal Gear Solid")
    }

    func testNormalizedROMTitle_cdVariant() {
        XCTAssertEqual("Policenauts (CD2) (Japan)".normalizedROMTitle(), "Policenauts")
    }

    func testNormalizedROMTitle_trackVariant() {
        XCTAssertEqual("Snatcher (Track 1)".normalizedROMTitle(), "Snatcher")
    }

    // MARK: - Bracket tags

    func testNormalizedROMTitle_bracketsOnly() {
        XCTAssertEqual("Tetris [!]".normalizedROMTitle(), "Tetris")
    }

    func testNormalizedROMTitle_translationBracket() {
        XCTAssertEqual("Dragon Quest [T-En]".normalizedROMTitle(), "Dragon Quest")
    }

    // MARK: - Version suffix variants

    func testNormalizedROMTitle_upperCaseV() {
        XCTAssertEqual("Street Fighter V2".normalizedROMTitle(), "Street Fighter")
    }

    func testNormalizedROMTitle_multiPartVersion() {
        XCTAssertEqual("Doom v1.9".normalizedROMTitle(), "Doom")
    }

    // MARK: - Edge cases

    func testNormalizedROMTitle_alreadyClean() {
        XCTAssertEqual("Castlevania".normalizedROMTitle(), "Castlevania")
    }

    func testNormalizedROMTitle_emptyStringReturnsOriginal() {
        XCTAssertEqual("".normalizedROMTitle(), "")
    }

    func testNormalizedROMTitle_onlyTagsReturnsOriginal() {
        // Stripping everything would produce empty — return original unchanged
        XCTAssertEqual("(USA)".normalizedROMTitle(), "(USA)")
    }

    func testNormalizedROMTitle_collapseInternalSpaces() {
        // Multiple spaces that may appear after stripping should collapse
        let input = "Mega Man  [!]"
        XCTAssertEqual(input.normalizedROMTitle(), "Mega Man")
    }

    // MARK: - hasNormalizableROMTitle

    func testHasNormalizableROMTitle_true() {
        XCTAssertTrue("Bomberman (USA)".hasNormalizableROMTitle)
    }

    func testHasNormalizableROMTitle_false() {
        XCTAssertFalse("Castlevania".hasNormalizableROMTitle)
    }
}
