//
//  SaveBundleManifestV2Tests.swift
//  PVLibraryTests
//
//  Tests for SaveBundleManifestV2 parsing, round-tripping, and v1 backward compatibility.
//  Part of issue #3552 (save import/export protocols foundation).
//

import XCTest
@testable import PVLibrary

final class SaveBundleManifestV2Tests: XCTestCase {

    // MARK: - V2 round-trip

    func testV2RoundTrip() throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let states: [SaveBundleManifestV2.SaveStateEntry] = [
            .init(filename: "abc.svs", screenshotFilename: "abc.jpg",
                  date: now, isAutosave: false, userDescription: "World 3", coreIdentifier: "com.provenance.snes9x")
        ]
        let batteries: [SaveBundleManifestV2.BatterySaveEntry] = [
            .init(filename: "Mario.srm", sizeBytes: 8192, md5: "deadbeef")
        ]
        let original = SaveBundleManifestV2(
            gameMD5: "abc123",
            gameTitle: "Super Mario World",
            systemIdentifier: "com.provenance.snes",
            exportDate: now,
            sourceEmulatorBundleID: "com.rileytestut.Delta",
            sourceEmulatorName: "Delta",
            batterySaves: batteries,
            saveStates: states
        )

        let data = try original.jsonData()
        let parsed = try SaveBundleManifestV2.parse(from: data)

        XCTAssertEqual(parsed.schemaVersion, 2)
        XCTAssertEqual(parsed.gameMD5, "abc123")
        XCTAssertEqual(parsed.gameTitle, "Super Mario World")
        XCTAssertEqual(parsed.systemIdentifier, "com.provenance.snes")
        XCTAssertEqual(parsed.exportDate, now)
        XCTAssertEqual(parsed.sourceEmulatorBundleID, "com.rileytestut.Delta")
        XCTAssertEqual(parsed.sourceEmulatorName, "Delta")
        XCTAssertEqual(parsed.batterySaves?.count, 1)
        XCTAssertEqual(parsed.batterySaves?.first?.filename, "Mario.srm")
        XCTAssertEqual(parsed.batterySaves?.first?.sizeBytes, 8192)
        XCTAssertEqual(parsed.saveStates?.count, 1)
        XCTAssertEqual(parsed.saveStates?.first?.filename, "abc.svs")
        XCTAssertEqual(parsed.saveStates?.first?.isAutosave, false)
        XCTAssertEqual(parsed.saveStates?.first?.userDescription, "World 3")
    }

    // MARK: - V1 backward compatibility

    func testV1CompatibilityWithSchemaVersion1String() throws {
        let json = """
        {
            "schemaVersion": "1",
            "game": "deadbeef1234",
            "title": "Sonic the Hedgehog",
            "system": "com.provenance.genesis",
            "exportDate": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let manifest = try SaveBundleManifestV2.parse(from: json)
        XCTAssertEqual(manifest.gameMD5, "deadbeef1234")
        XCTAssertEqual(manifest.gameTitle, "Sonic the Hedgehog")
        XCTAssertEqual(manifest.systemIdentifier, "com.provenance.genesis")
        XCTAssertNil(manifest.batterySaves)
        XCTAssertNil(manifest.saveStates)
        XCTAssertNil(manifest.sourceEmulatorBundleID)
    }

    func testV1CompatibilityWithNoSchemaVersion() throws {
        // Oldest bundles had no schemaVersion key at all
        let json = """
        {
            "game": "aabbccdd",
            "title": "Zelda",
            "system": "com.provenance.snes",
            "exportDate": "2024-06-15T12:00:00Z"
        }
        """.data(using: .utf8)!

        let manifest = try SaveBundleManifestV2.parse(from: json)
        XCTAssertEqual(manifest.gameMD5, "aabbccdd")
        XCTAssertEqual(manifest.gameTitle, "Zelda")
        XCTAssertNil(manifest.batterySaves)
    }

    // MARK: - JSON key compatibility

    func testV2ManifestEncodesGameKeyAsString() throws {
        // v1 readers expect the key name "game" (not "gameMD5")
        let manifest = SaveBundleManifestV2(
            gameMD5: "testmd5",
            gameTitle: "Test Game",
            systemIdentifier: "com.provenance.nes",
            exportDate: "2026-01-01T00:00:00Z"
        )
        let data = try manifest.jsonData()
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(dict["game"], "v1 readers require key 'game' — must not change to 'gameMD5'")
        XCTAssertEqual(dict["game"] as? String, "testmd5")
    }

    // MARK: - Error cases

    func testParseThrowsOnMissingGameField() {
        let json = """
        { "title": "No MD5", "system": "com.provenance.nes", "exportDate": "" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json))
    }

    func testParseThrowsOnUnsupportedSchemaVersion() {
        let json = """
        { "schemaVersion": 99, "game": "abc", "title": "Future Game", "system": "com.provenance.future", "exportDate": "" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json)) { error in
            guard case SaveBundleManifestParseError.unsupportedSchemaVersion(99) = error else {
                XCTFail("Expected unsupportedSchemaVersion(99), got \(error)")
                return
            }
        }
    }

    func testParseThrowsOnInvalidJSON() {
        let notJSON = "this is not json".data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: notJSON))
    }

    func testV2MalformedFieldsThrowsSaveBundleError() throws {
        // schemaVersion==2 but gameMD5 ("game") is an int instead of String — DecodingError
        // must be wrapped into SaveBundleManifestParseError, not escape as DecodingError.
        let json = """
        {
            "schemaVersion": 2,
            "game": 12345,
            "title": "Malformed",
            "system": "com.provenance.nes",
            "exportDate": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json)) { error in
            XCTAssertTrue(error is SaveBundleManifestParseError,
                          "Expected SaveBundleManifestParseError, got \(type(of: error))")
        }
    }

    // MARK: - SaveFileCategory helpers

    func testSaveFileCategoryInference() {
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "srm"), .sram)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "sav"), .sram)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "ram"), .sram)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "dsv"), .sram)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "svs"), .saveState)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "state"), .saveState)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "dvsave"), .saveState)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "rtc"), .rtc)
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "SRM"), .sram) // case-insensitive
    }

    // MARK: - KnownEmulator

    func testKnownEmulatorProperties() {
        XCTAssertEqual(KnownEmulator.delta.displayName, "Delta")
        XCTAssertEqual(KnownEmulator.deltaLite.displayName, "Delta")
        XCTAssertEqual(KnownEmulator.retroArch.displayName, "RetroArch")
        XCTAssertEqual(KnownEmulator.manticEmu.displayName, "Mantic Emu")
        XCTAssertEqual(KnownEmulator.ppsspp.displayName, "PPSSPP")

        XCTAssertEqual(KnownEmulator.delta.urlScheme, "delta")
        XCTAssertEqual(KnownEmulator.retroArch.urlScheme, "retroarch")
        XCTAssertNil(KnownEmulator.manticEmu.urlScheme)

        XCTAssertTrue(KnownEmulator.delta.saveFileExtensions.contains("sav"))
        XCTAssertTrue(KnownEmulator.retroArch.stateFileExtensions.contains("state"))
    }

    func testKnownEmulatorExportDeepLinks() {
        XCTAssertNotNil(KnownEmulator.delta.exportDeepLinkURL)
        XCTAssertNotNil(KnownEmulator.retroArch.exportDeepLinkURL)
        XCTAssertNil(KnownEmulator.manticEmu.exportDeepLinkURL)
        XCTAssertNil(KnownEmulator.ppsspp.exportDeepLinkURL)
    }

    func testKnownEmulatorStateExtensions() {
        XCTAssertTrue(KnownEmulator.delta.stateFileExtensions.contains("dvsave"))
        XCTAssertTrue(KnownEmulator.retroArch.stateFileExtensions.contains("state"))
        XCTAssertTrue(KnownEmulator.retroArch.stateFileExtensions.contains("state0"))
        XCTAssertTrue(KnownEmulator.ppsspp.stateFileExtensions.contains("ppst"))
        XCTAssertTrue(KnownEmulator.gamma.stateFileExtensions.isEmpty)
        XCTAssertTrue(KnownEmulator.manticEmu.stateFileExtensions.isEmpty)
    }

    func testKnownEmulatorBundleIDs() {
        XCTAssertEqual(KnownEmulator.delta.bundleID, "com.rileytestut.Delta")
        XCTAssertEqual(KnownEmulator.retroArch.bundleID, "com.libretro.RetroArch")
        XCTAssertEqual(KnownEmulator.ppsspp.bundleID, "org.ppsspp.ppsspp")
    }

    // MARK: - V2 parse with integer schemaVersion

    func testV2ParseWithIntegerSchemaVersion() throws {
        let json = """
        {
            "schemaVersion": 2,
            "game": "inttest123",
            "title": "Integer Version Game",
            "system": "com.provenance.nes",
            "exportDate": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let manifest = try SaveBundleManifestV2.parse(from: json)
        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.gameMD5, "inttest123")
        XCTAssertEqual(manifest.systemIdentifier, "com.provenance.nes")
    }

    // MARK: - V1 missing optional fields

    func testV1ParseMissingExportDate() throws {
        let json = """
        {
            "game": "nodatehash",
            "title": "No Date Game",
            "system": "com.provenance.nes"
        }
        """.data(using: .utf8)!

        let manifest = try SaveBundleManifestV2.parse(from: json)
        XCTAssertEqual(manifest.gameMD5, "nodatehash")
        XCTAssertEqual(manifest.exportDate, "")
    }

    func testParseThrowsOnMissingTitleField() {
        let json = """
        { "game": "abc123", "system": "com.provenance.nes", "exportDate": "" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json))
    }

    func testParseThrowsOnMissingSystemField() {
        let json = """
        { "game": "abc123", "title": "Test", "exportDate": "" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json))
    }

    func testParseThrowsOnEmptyGameMD5() {
        let json = """
        { "game": "", "title": "Test", "system": "com.provenance.nes", "exportDate": "" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try SaveBundleManifestV2.parse(from: json))
    }

    // MARK: - Error descriptions

    func testParseErrorDescriptions() {
        let invalidError = SaveBundleManifestParseError.invalidManifest("some reason")
        XCTAssertTrue(invalidError.errorDescription?.contains("some reason") == true)

        let versionError = SaveBundleManifestParseError.unsupportedSchemaVersion(42)
        XCTAssertTrue(versionError.errorDescription?.contains("42") == true)
    }

    // MARK: - SaveMatchConfidence ordering

    func testSaveMatchConfidenceOrdering() {
        XCTAssertLessThan(SaveMatchConfidence.manual, SaveMatchConfidence.probable)
        XCTAssertLessThan(SaveMatchConfidence.probable, SaveMatchConfidence.exact)
        XCTAssertGreaterThan(SaveMatchConfidence.exact, SaveMatchConfidence.manual)
    }

    func testSaveMatchConfidenceRawValues() {
        XCTAssertEqual(SaveMatchConfidence.exact.rawValue, 3)
        XCTAssertEqual(SaveMatchConfidence.probable.rawValue, 2)
        XCTAssertEqual(SaveMatchConfidence.manual.rawValue, 1)
    }

    // MARK: - SaveGameMatch

    func testSaveGameMatchInit() {
        let match = SaveGameMatch(gameID: "abc123", gameTitle: "Sonic", confidence: .exact)
        XCTAssertEqual(match.gameID, "abc123")
        XCTAssertEqual(match.gameTitle, "Sonic")
        XCTAssertEqual(match.confidence, .exact)
    }

    // MARK: - SaveImportResult / SaveExportResult

    func testSaveImportResultDefaults() {
        let result = SaveImportResult(sramRestored: true, statesRestored: 3)
        XCTAssertTrue(result.sramRestored)
        XCTAssertEqual(result.statesRestored, 3)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testSaveImportResultWithWarnings() {
        let result = SaveImportResult(sramRestored: false, statesRestored: 0, warnings: ["File skipped"])
        XCTAssertFalse(result.sramRestored)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(result.warnings.first, "File skipped")
    }

    func testSaveExportResultInit() {
        let url = URL(fileURLWithPath: "/tmp/test.zip")
        let result = SaveExportResult(bundleURL: url, sramIncluded: true, statesIncluded: 5)
        XCTAssertEqual(result.bundleURL, url)
        XCTAssertTrue(result.sramIncluded)
        XCTAssertEqual(result.statesIncluded, 5)
    }

    // MARK: - SaveFileCategory CaseIterable

    func testSaveFileCategoryAllCases() {
        XCTAssertEqual(SaveFileCategory.allCases.count, 3)
        XCTAssertTrue(SaveFileCategory.allCases.contains(.sram))
        XCTAssertTrue(SaveFileCategory.allCases.contains(.saveState))
        XCTAssertTrue(SaveFileCategory.allCases.contains(.rtc))
    }

    func testSaveFileCategoryPPSTIsState() {
        XCTAssertEqual(SaveFileCategory.infer(fromExtension: "ppst"), .saveState)
    }

    // MARK: - isSafeFilename

    func testIsSafeFilename_validNames() {
        XCTAssertTrue(SaveBundleManifestV2.isSafeFilename("Mario.srm"))
        XCTAssertTrue(SaveBundleManifestV2.isSafeFilename("save_state_001.svs"))
        XCTAssertTrue(SaveBundleManifestV2.isSafeFilename("abc123.state"))
        XCTAssertTrue(SaveBundleManifestV2.isSafeFilename("My Game (USA).sav"))
    }

    func testIsSafeFilename_rejectsEmpty() {
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename(""))
    }

    func testIsSafeFilename_rejectsHiddenFiles() {
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename(".DS_Store"))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename(".hidden"))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("._resource_fork"))
    }

    func testIsSafeFilename_rejectsPathTraversal() {
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("../etc/passwd"))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename(".."))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("foo/../bar.srm"))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("subdir/Mario.srm"))
    }

    func testIsSafeFilename_rejectsBackslash() {
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("foo\\bar.srm"))
        XCTAssertFalse(SaveBundleManifestV2.isSafeFilename("..\\passwd"))
    }

    func testBatterySaveEntry_isSafeFilename() {
        let safe = SaveBundleManifestV2.BatterySaveEntry(filename: "Mario.srm")
        XCTAssertTrue(safe.isSafeFilename)

        let unsafe = SaveBundleManifestV2.BatterySaveEntry(filename: "../secret.srm")
        XCTAssertFalse(unsafe.isSafeFilename)

        let hidden = SaveBundleManifestV2.BatterySaveEntry(filename: ".DS_Store")
        XCTAssertFalse(hidden.isSafeFilename)
    }

    func testSaveStateEntry_isSafeFilename() {
        let safe = SaveBundleManifestV2.SaveStateEntry(filename: "abc.svs")
        XCTAssertTrue(safe.isSafeFilename)

        let unsafe = SaveBundleManifestV2.SaveStateEntry(filename: "../../etc/passwd")
        XCTAssertFalse(unsafe.isSafeFilename)
    }
}
