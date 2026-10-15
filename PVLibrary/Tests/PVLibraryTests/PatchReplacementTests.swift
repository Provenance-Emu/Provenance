//
//  PatchReplacementTests.swift
//  PVLibraryTests
//
//  The rules of "Replace the Original": every patch may replace (the warning grows instead), what
//  still blocks it, the atomic file swap with its rollback, and per-game settings following the
//  game to its new MD5.
//

import XCTest
import CryptoKit
import RealmSwift
import PVRealm
import PVFileSystem
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

    /// Turning sync back on would recreate the old MD5's row, pointing at the replaced file.
    func testAGameWithAnICloudCopyIsBlocked() throws {
        let rom = try file("Game.gba", "rom")
        XCTAssertEqual(PatchReplacement.blocker(for: PatchReplacement.Target(
            romURL: rom, hasRelatedFiles: false, isDownloaded: true, cloudSyncEnabled: false, isInICloud: true
        )), .inICloud)
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

        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: patched, newMD5: newMD5)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "patched")
        XCTAssertEqual(try String(contentsOf: swap.backup, encoding: .utf8), "original")
        XCTAssertTrue(swap.backup.lastPathComponent.hasPrefix("."), "the backup is hidden from the library")
        XCTAssertTrue(swap.backup.lastPathComponent.hasPrefix(".Game.gba.original-\(newMD5)-"), "the backup names the MD5 the game moves to")

        swap.commit()
        XCTAssertFalse(FileManager.default.fileExists(atPath: swap.backup.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: patched.path), "the cached copy is the caller's to remove")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "patched.gba"])
    }

    func testRollbackRestoresTheOriginal() throws {
        let original = try file("Game.gba", "original")
        let patched = try file("patched.gba", "patched")

        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: patched, newMD5: newMD5)
        try swap.rollback()

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "patched.gba"])
    }

    func testAFailedCopyLeavesTheOriginalUntouched() throws {
        let original = try file("Game.gba", "original")

        XCTAssertThrowsError(try PatchReplacement.beginSwap(replacing: original, withContentsOf: directory.appendingPathComponent("missing.gba"), newMD5: newMD5))
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["Game.gba"])
    }

    // MARK: - Commit

    private let oldMD5 = "0123456789ABCDEF0123456789ABCDEF"
    private let newMD5 = "FEDCBA9876543210FEDCBA9876543210"

    private func realmWithGame() throws -> Realm {
        let realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        let game = PVGame()
        game.md5Hash = oldMD5
        game.title = "Game"
        let state = PVSaveState()
        state.game = game
        let patch = PVPatch()
        patch.id = "Patches/hack.bps"
        patch.game = game
        patch.baseGameMD5 = oldMD5
        patch.isDefaultLaunch = true
        patch.isEnabled = true
        try realm.write { realm.add([game, state, patch] as [Object]) }
        return realm
    }

    func testCommitMovesTheGameAndDropsTheOriginal() throws {
        let realm = try realmWithGame()
        let original = try file("Game.gba", "original")
        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: try file("cached.gba", "patched"), newMD5: newMD5)

        let game = try PatchReplacement.commit(
            swap, rekeying: oldMD5, to: newMD5, crc: "ABCD1234", fileSize: 7, showPatchedSeparately: true, in: realm
        )

        XCTAssertEqual(game.md5Hash, newMD5)
        XCTAssertEqual(game.saveStates.count, 1)
        XCTAssertFalse(try XCTUnwrap(game.patches.first).isDefaultLaunch, "the replaced game launches itself")
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "patched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: swap.backup.path))
    }

    func testAFailedCommitRestoresTheOriginalAndTheDatabase() throws {
        let realm = try realmWithGame()
        let taken = PVGame()
        taken.md5Hash = newMD5
        taken.title = "Already here"
        try realm.write { realm.add(taken) }
        let original = try file("Game.gba", "original")
        let swap = try PatchReplacement.beginSwap(replacing: original, withContentsOf: try file("cached.gba", "patched"), newMD5: newMD5)

        XCTAssertThrowsError(try PatchReplacement.commit(
            swap, rekeying: oldMD5, to: newMD5, crc: "ABCD1234", fileSize: 7, showPatchedSeparately: true, in: realm
        ))

        XCTAssertFalse(realm.isInWriteTransaction)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "cached.gba"])
        let game = try XCTUnwrap(realm.object(ofType: PVGame.self, forPrimaryKey: oldMD5))
        XCTAssertTrue(try XCTUnwrap(game.patches.first).isDefaultLaunch)
    }

    // MARK: - Recovery

    private func backup(for name: String, md5: String, contents: String = "original") throws -> URL {
        try file(".\(name).original-\(md5)-\(UUID().uuidString.prefix(8))", contents)
    }

    private func emptyRealm() throws -> Realm {
        try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }

    func testABackupWhoseMD5IsInTheDatabaseIsDroppedAndTheROMKept() throws {
        let realm = try realmWithGame()
        try realm.write { realm.create(PVGame.self, value: ["md5Hash": newMD5.lowercased(), "title": "Patched"]) }
        let rom = try file("Game.gba", "patched")
        let spare = try backup(for: "Game.gba", md5: newMD5)

        let handled = PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: realm)

        XCTAssertEqual(handled, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: spare.path))
        XCTAssertEqual(try String(contentsOf: rom, encoding: .utf8), "patched")
    }

    func testABackupWhoseMD5IsNotInTheDatabaseRestoresTheOriginal() throws {
        let realm = try realmWithGame()
        let rom = try file("Game.gba", "patched")
        _ = try backup(for: "Game.gba", md5: newMD5)

        let handled = PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: realm)

        XCTAssertEqual(handled, 1)
        XCTAssertEqual(try String(contentsOf: rom, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["Game.gba"])
    }

    func testAMissingROMIsRestoredFromItsBackup() throws {
        _ = try backup(for: "Game.gba", md5: newMD5)

        PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: try emptyRealm())

        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("Game.gba"), encoding: .utf8), "original")
    }

    func testAnInterruptedSwapIsRecoveredEndToEnd() throws {
        let realm = try realmWithGame()
        let original = try file("Game.gba", "original")
        // beginSwap ran; the process died before the database update.
        _ = try PatchReplacement.beginSwap(replacing: original, withContentsOf: try file("cached.gba", "patched"), newMD5: newMD5)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "patched")

        PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: realm)

        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), ["Game.gba", "cached.gba"])
    }

    func testAnUnfinishedStagedCopyIsDeleted() throws {
        let stray = try file(".Game.gba.patched-\(UUID().uuidString)", "half")
        _ = try file("Game.gba", "original")

        let handled = PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: try emptyRealm())

        XCTAssertEqual(handled, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stray.path))
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("Game.gba"), encoding: .utf8), "original")
    }

    func testRecoveryLeavesUnrelatedFilesAlone() throws {
        let names = [".DS_Store", ".hidden.gba", ".Game.gba.original-notanmd5-12345678", ".Game.gba.original-\(newMD5)", ".Game.gba.patched-x", "Game.gba", "visible.original-\(newMD5)-12345678"]
        for name in names { _ = try file(name, "keep") }

        let handled = PatchReplacement.recoverInterruptedSwaps(in: [directory], realm: try emptyRealm())

        XCTAssertEqual(handled, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), names.sorted())
    }

    // MARK: - Library MD5

    /// The replaced game must get the MD5 an import of the same file would: for NES that skips the
    /// 16-byte iNES header, so it differs from the raw file MD5.
    func testTheLibraryMD5IsTheImportersHeaderAwareHash() async throws {
        let folder = URL.documentsPath.appendingPathComponent("PatchedROMs/test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: folder.path) }
        let payload = Data((0..<64).map { UInt8($0) })
        var rom = Data([0x4E, 0x45, 0x53, 0x1A] + [UInt8](repeating: 0, count: 12))
        rom.append(payload)
        let url = folder.appendingPathComponent("Game.nes")
        try rom.write(to: url)

        let md5 = await PatchReplacement.libraryMD5(ofFileAt: url, systemIdentifier: "com.provenance.nes")

        XCTAssertEqual(md5, Self.md5(payload))
        XCTAssertNotEqual(md5, Self.md5(rom))
    }

    private static func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02X", $0) }.joined()
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
