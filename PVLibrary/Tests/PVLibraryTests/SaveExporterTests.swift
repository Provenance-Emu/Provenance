//
//  SaveExporterTests.swift
//  PVLibraryTests
//
//  Tests for SaveExporter export/import service.
//

import XCTest
import RealmSwift
import ZipArchive
import PVFileSystem
@testable import PVLibrary

final class SaveExporterTests: XCTestCase {

    private var tempDir: URL!
    private var realm: Realm!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Use unique in-memory Realm per test
        let config = Realm.Configuration(inMemoryIdentifier: "SaveExporterTests-\(UUID().uuidString)")
        realm = try Realm(configuration: config)

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveExporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        realm = nil
        try super.tearDownWithError()
    }

    // MARK: - Error description tests

    func testErrorDescriptions() {
        XCTAssertNotNil(SaveExportError.noSavesFound.errorDescription)
        XCTAssertNotNil(SaveExportError.zipCreationFailed.errorDescription)
        XCTAssertNotNil(SaveExportError.gameMismatch.errorDescription)
        XCTAssertNotNil(SaveExportError.invalidBundle("reason").errorDescription)
        XCTAssertTrue(SaveExportError.invalidBundle("details").errorDescription?.contains("details") == true)
    }

    // MARK: - noSavesFound

    func testExportThrowsNoSavesFoundWhenGameHasNoSavesOrBatteryFiles() async throws {
        let game = makeGame(title: "TestGame", md5: "abc123", romURL: nil)

        do {
            _ = try await SaveExporter.shared.exportSaves(for: game)
            XCTFail("Expected noSavesFound to be thrown")
        } catch SaveExportError.noSavesFound {
            // expected
        }
    }

    // MARK: - gameMismatch

    func testImportThrowsGameMismatchForWrongMD5() async throws {
        let bundleMD5 = "aaaa1111"
        let gameMD5 = "bbbb2222"
        let zipURL = try makeMinimalExportZip(gameMD5: bundleMD5)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let game = makeGame(title: "Other", md5: gameMD5, romURL: nil)

        do {
            try await SaveExporter.shared.importSaves(from: zipURL, for: game)
            XCTFail("Expected gameMismatch to be thrown")
        } catch SaveExportError.gameMismatch {
            // expected
        }
    }

    // MARK: - Import happy path

    func testImportSucceedsForMatchingMD5() async throws {
        let md5 = "match1234"
        let zipURL = try makeMinimalExportZip(gameMD5: md5)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // A valid (but non-existent) ROM URL is required; import guards against nil romURL.
        let romFile = tempDir.appendingPathComponent("match.sfc")
        let game = makeGame(title: "MatchGame", md5: md5, romURL: romFile)

        // Should not throw — manifest matches and the zip has no battery/states to restore.
        try await SaveExporter.shared.importSaves(from: zipURL, for: game)
    }

    // MARK: - nil ROM URL guard

    func testImportThrowsInvalidBundleWhenGameHasNoROMURL() async throws {
        let md5 = "nilrom123"
        let zipURL = try makeMinimalExportZip(gameMD5: md5)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let game = makeGame(title: "NoROM", md5: md5, romURL: nil)

        do {
            try await SaveExporter.shared.importSaves(from: zipURL, for: game)
            XCTFail("Expected invalidBundle to be thrown when romURL is nil")
        } catch SaveExportError.invalidBundle {
            // expected — prevents importing into the shared NULL directory
        }
    }

    // MARK: - Staging dir uniqueness

    func testConcurrentExportsDoNotShareStagingDir() async throws {
        // Create ROM files so Paths resolves to game-specific directories (not the shared NULL dir).
        let romFile1 = tempDir.appendingPathComponent("gameA.sfc")
        let romFile2 = tempDir.appendingPathComponent("gameB.sfc")
        try Data().write(to: romFile1)
        try Data().write(to: romFile2)

        // Create battery saves at the location SaveExporter actually reads from.
        let batterySavesDir1 = Paths.batterySavesPath(forROM: romFile1)
        let batterySavesDir2 = Paths.batterySavesPath(forROM: romFile2)
        try FileManager.default.createDirectory(at: batterySavesDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: batterySavesDir2, withIntermediateDirectories: true)
        try "save data A".data(using: .utf8)!.write(to: batterySavesDir1.appendingPathComponent("gameA.srm"))
        try "save data B".data(using: .utf8)!.write(to: batterySavesDir2.appendingPathComponent("gameB.srm"))
        defer {
            try? FileManager.default.removeItem(at: batterySavesDir1)
            try? FileManager.default.removeItem(at: batterySavesDir2)
        }

        let game1 = makeGame(title: "SameTitle", md5: "md5aaa", romURL: romFile1)
        let game2 = makeGame(title: "SameTitle", md5: "md5bbb", romURL: romFile2)

        // Both concurrent exports must succeed and produce unique zip names.
        async let url1 = SaveExporter.shared.exportSaves(for: game1)
        async let url2 = SaveExporter.shared.exportSaves(for: game2)

        do {
            let (exportURL1, exportURL2) = try await (url1, url2)
            XCTAssertNotEqual(
                exportURL1.lastPathComponent,
                exportURL2.lastPathComponent,
                "Concurrent exports must produce unique zip names"
            )
            SaveExporter.shared.cleanupExport(at: exportURL1)
            SaveExporter.shared.cleanupExport(at: exportURL2)
        } catch {
            XCTFail("Both concurrent exports expected to succeed but failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeGame(title: String, md5: String, romURL: URL?) -> PVGame {
        let game = PVGame()
        game.title = title
        game.md5Hash = md5
        game.systemIdentifier = "com.provenance.snes"

        if let romURL {
            let pvFile = PVFile(withURL: romURL)
            game.file = pvFile
        }

        try? realm.write { realm.add(game, update: .all) }
        let frozen = game.isFrozen ? game : game.freeze()
        return frozen
    }

    /// Creates a minimal valid export zip with only a `manifest.json` inside.
    private func makeMinimalExportZip(gameMD5: String) throws -> URL {
        let stagingDir = tempDir.appendingPathComponent("staging-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingDir) }

        let manifest: [String: String] = [
            "schemaVersion": "1",
            "game": gameMD5,
            "title": "TestGame",
            "system": "com.provenance.snes",
            "exportDate": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
        try data.write(to: stagingDir.appendingPathComponent("manifest.json"))

        let zipURL = tempDir.appendingPathComponent("test-export-\(gameMD5).zip")
        guard SSZipArchive.createZipFile(atPath: zipURL.path, withContentsOfDirectory: stagingDir.path) else {
            throw SaveExportError.zipCreationFailed
        }
        return zipURL
    }
}
