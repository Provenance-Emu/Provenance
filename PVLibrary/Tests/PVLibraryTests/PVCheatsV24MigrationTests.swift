//
//  PVCheatsV24MigrationTests.swift
//  PVLibraryTests
//
//  Tests for the schema v24 migration that splits the legacy `-~-` separator
//  out of PVCheats.type into the dedicated codeType field.
//

import XCTest
import PVRealm

final class PVCheatsV24MigrationTests: XCTestCase {

    // MARK: Legacy format (contains -~-)

    func testLegacyFormatSplitsCorrectly() {
        let result = PVCheats.splitLegacyCombinedType("Infinite Lives-~-Game Shark")
        XCTAssertEqual(result.type, "Infinite Lives")
        XCTAssertEqual(result.codeType, "Game Shark")
    }

    func testLegacyFormatWithActionReplay() {
        let result = PVCheats.splitLegacyCombinedType("Max Money-~-Action Replay")
        XCTAssertEqual(result.type, "Max Money")
        XCTAssertEqual(result.codeType, "Action Replay")
    }

    func testLegacyFormatWithEmptyCheatName() {
        let result = PVCheats.splitLegacyCombinedType("-~-Game Genie")
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "Game Genie")
    }

    func testLegacyFormatWithEmptyCodeType() {
        let result = PVCheats.splitLegacyCombinedType("Unlock All-~-")
        XCTAssertEqual(result.type, "Unlock All")
        XCTAssertEqual(result.codeType, "")
    }

    func testLegacyFormatWithMultipleSeparators() {
        // Edge case: if somehow multiple -~- appear, join extras back into codeType
        let result = PVCheats.splitLegacyCombinedType("My Cheat-~-Code Type-~-Extra")
        XCTAssertEqual(result.type, "My Cheat")
        XCTAssertEqual(result.codeType, "Code Type-~-Extra")
    }

    // MARK: Clean format (no -~-, already migrated or newly created)

    func testCleanFormatIsUnchanged() {
        let result = PVCheats.splitLegacyCombinedType("Infinite Lives")
        XCTAssertEqual(result.type, "Infinite Lives")
        XCTAssertEqual(result.codeType, "")
    }

    func testEmptyTypeIsUnchanged() {
        let result = PVCheats.splitLegacyCombinedType("")
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "")
    }

    func testNilTypeIsHandledGracefully() {
        let result = PVCheats.splitLegacyCombinedType(nil)
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "")
    }
}
