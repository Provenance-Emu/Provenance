//
//  PatchReplacementTests.swift
//  PVLibraryTests
//
//  The rules of "Replace the Original": every patch may replace (the warning grows instead), what
//  still blocks it, the atomic file swap with its rollback, and per-game settings following the
//  game to its new MD5.
//

import XCTest
@testable import PVLibrary

final class PatchReplacementTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchReplacementTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let directory = directory {
            try? FileManager.default.removeItem(atPath: directory.path)
        }
        super.tearDown()
    }

    private func file(_ name: String, _ contents: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func target(_ url: URL?, related: Bool = false, downloaded: Bool = true, cloud: Bool = false) -> PatchReplacement.Target {
        PatchReplacement.Target(romURL: url, hasRelatedFiles: related, isDownloaded: downloaded, cloudSyncEnabled: cloud)
    }

    // MARK: - Risk

    func testEveryPatchMayReplaceButTheWarningGrows() {
        XCTAssertEqual(PatchReplacement.Risk.assess(canVerifyIntegrity: true, applyingAnyway: false), .verified)
        XCTAssertEqual(PatchReplacement.Risk.assess(canVerifyIntegrity: false, applyingAnyway: false), .unverifiable)
        XCTAssertEqual(PatchReplacement.Risk.assess(canVerifyIntegrity: true, applyingAnyway: true), .knownMismatch)
        XCTAssertEqual(PatchReplacement.Risk.assess(canVerifyIntegrity: false, applyingAnyway: true), .knownMismatch)
    }

    // MARK: - Blockers

    func testASingleDownloadedROMCanBeReplaced() throws {
        XCTAssertNil(PatchReplacement.blocker(for: target(try file("Game.gba", "rom"))))
    }

    /// Another device deletes the old game, and with it the file at the path the new one shares.
    func testCloudSyncBlocksReplacement() throws {
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.gba", "rom"), cloud: true)), .cloudSyncOn)
    }

    func testMultiFileGamesAndArchivesAreBlocked() throws {
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.cue", "FILE"))), .multiFileGame)
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.m3u", "a.cue"))), .multiFileGame)
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.gdi", "1"))), .multiFileGame)
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.bin", "rom"), related: true)), .multiFileGame)
        XCTAssertEqual(PatchReplacement.blocker(for: target(directory)), .multiFileGame)
        XCTAssertEqual(PatchReplacement.blocker(for: target(try file("Game.zip", "PK"))), .archive)
    }

    func testMissingAndCloudOnlyFilesAreBlocked() throws {
        XCTAssertEqual(PatchReplacement.blocker(for: target(nil)), .fileMissing)
        XCTAssertEqual(PatchReplacement.blocker(for: target(directory.appendingPathComponent("Gone.gba"))), .fileMissing)
        XCTAssertEqual(PatchReplacement.blocker(for: target(directory.appendingPathComponent("Gone.gba"), downloaded: false)), .notDownloaded)
    }

    // MARK: - File swap

    func testTheSwapPutsThePatchedBytesInPlaceAndCommitDropsTheOriginal() throws {
        let original = try file("Game.gba", "original")
        let patched = try file("patched.gba", "patched")

        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: patched)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "patched")
        XCTAssertEqual(try String(contentsOf: swap.backup, encoding: .utf8), "original")
        XCTAssertTrue(swap.backup.lastPathComponent.hasPrefix("."), "the backup is hidden from the library")

        swap.commit()
        XCTAssertFalse(FileManager.default.fileExists(atPath: swap.backup.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: patched.path), "the cached copy is the caller's to remove")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "patched.gba"])
    }

    func testRollbackRestoresTheOriginal() throws {
        let original = try file("Game.gba", "original")
        let patched = try file("patched.gba", "patched")

        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: patched)
        try swap.rollback()

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "patched.gba"])
    }

    func testAFailedCopyLeavesTheOriginalUntouched() throws {
        let original = try file("Game.gba", "original")

        XCTAssertThrowsError(try PatchReplacement.beginSwap(replacing: original, withContentsOf: directory.appendingPathComponent("missing.gba")))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["Game.gba"])
    }

    // MARK: - Per-game settings

    func testPerGameSettingsFollowTheGameInEitherCase() throws {
        let suite = "PatchReplacementTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let old = "0123456789abcdef0123456789abcdef"
        let new = "fedcba9876543210fedcba9876543210"

        defaults.set("4x", forKey: "PVMGBACore.\(old.uppercased()).resolution")
        defaults.set(2, forKey: "LightGun\(old)")
        defaults.set([old.uppercased(): "classic", "OTHER": "modern"], forKey: "controllerLayoutVariantsByGame")
        defaults.set("kept", forKey: "PVMGBACore.\(new.uppercased()).existing")
        defaults.set("new wins", forKey: "PVMGBACore.\(new.uppercased()).resolution")

        PatchReplacement.copyPerGameSettings(fromMD5: old.uppercased(), toMD5: new.uppercased(), in: defaults)

        XCTAssertEqual(defaults.string(forKey: "PVMGBACore.\(new.uppercased()).resolution"), "new wins", "never overwrites")
        XCTAssertEqual(defaults.integer(forKey: "LightGun\(new)"), 2)
        let layouts = try XCTUnwrap(defaults.dictionary(forKey: "controllerLayoutVariantsByGame") as? [String: String])
        XCTAssertEqual(layouts[new.uppercased()], "classic")
        XCTAssertEqual(layouts["OTHER"], "modern")
        XCTAssertEqual(defaults.string(forKey: "PVMGBACore.\(old.uppercased()).resolution"), "4x", "old entries stay")
    }
}
