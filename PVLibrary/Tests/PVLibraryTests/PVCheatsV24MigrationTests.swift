//
//  PVCheatsV24MigrationTests.swift
//  PVLibraryTests
//
//  Tests for the schema v24 migration that splits the legacy `-~-` separator
//  out of PVCheats.type into the dedicated codeType field.
//

import XCTest

/// Mirrors the splitting logic used in the Realm schema v24 migration block.
/// Keep in sync with `RomDatabase.swift` migration for `oldSchemaVersion < 24`.
private func migrateCheatRecord(type combinedType: String?) -> (type: String, codeType: String) {
    guard let combinedType, combinedType.contains("-~-") else {
        return (type: combinedType ?? "", codeType: "")
    }
    let parts = combinedType.components(separatedBy: "-~-")
    let migratedType = parts[0]
    let migratedCodeType = parts.dropFirst().joined(separator: "-~-")
    return (type: migratedType, codeType: migratedCodeType)
}

final class PVCheatsV24MigrationTests: XCTestCase {

    // MARK: Legacy format (contains -~-)

    func testLegacyFormatSplitsCorrectly() {
        let result = migrateCheatRecord(type: "Infinite Lives-~-Game Shark")
        XCTAssertEqual(result.type, "Infinite Lives")
        XCTAssertEqual(result.codeType, "Game Shark")
    }

    func testLegacyFormatWithActionReplay() {
        let result = migrateCheatRecord(type: "Max Money-~-Action Replay")
        XCTAssertEqual(result.type, "Max Money")
        XCTAssertEqual(result.codeType, "Action Replay")
    }

    func testLegacyFormatWithEmptyCheatName() {
        let result = migrateCheatRecord(type: "-~-Game Genie")
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "Game Genie")
    }

    func testLegacyFormatWithEmptyCodeType() {
        let result = migrateCheatRecord(type: "Unlock All-~-")
        XCTAssertEqual(result.type, "Unlock All")
        XCTAssertEqual(result.codeType, "")
    }

    func testLegacyFormatWithMultipleSeparators() {
        // Edge case: if somehow multiple -~- appear, join extras back into codeType
        let result = migrateCheatRecord(type: "My Cheat-~-Code Type-~-Extra")
        XCTAssertEqual(result.type, "My Cheat")
        XCTAssertEqual(result.codeType, "Code Type-~-Extra")
    }

    // MARK: Clean format (no -~-, already migrated or newly created)

    func testCleanFormatIsUnchanged() {
        let result = migrateCheatRecord(type: "Infinite Lives")
        XCTAssertEqual(result.type, "Infinite Lives")
        XCTAssertEqual(result.codeType, "")
    }

    func testEmptyTypeIsUnchanged() {
        let result = migrateCheatRecord(type: "")
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "")
    }

    func testNilTypeIsHandledGracefully() {
        let result = migrateCheatRecord(type: nil)
        XCTAssertEqual(result.type, "")
        XCTAssertEqual(result.codeType, "")
    }
}
