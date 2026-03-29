//
//  SystemDirectoryMigrationTests.swift
//  PVLibraryTests
//
//  Created by Agent on 2026-03-29.
//

import XCTest
@testable import PVLibrary

final class SystemDirectoryMigrationTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a fresh, isolated UserDefaults suite for each test.
    private func makeFreshDefaults() -> UserDefaults {
        let suiteName = "com.provenance.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    /// Creates a temporary directory that acts as a fake "Documents" root.
    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PVMigrationTests/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Seeds a file at `root/relPath` with dummy content, creating parent directories as needed.
    private func seedFile(at root: URL, relPath: String) throws {
        let url = root.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "test".write(to: url, atomically: true, encoding: .utf8)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Flag tests

    func testMigrationFlagDefaultsFalse() async {
        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults())
        let completed = await migrator.isMigrationCompleted
        XCTAssertFalse(completed, "Migration flag should start false")
    }

    func testMigrationFlagSetAfterRun() async throws {
        let defaults = makeFreshDefaults()
        let root = try makeTemporaryRoot()
        let migrator = SystemDirectoryMigration(defaults: defaults, documentsRoot: root)

        try await migrator.migrateIfNeeded()

        XCTAssertTrue(await migrator.isMigrationCompleted)
    }

    func testMigrationSkipsIfAlreadyCompleted() async throws {
        let defaults = makeFreshDefaults()
        defaults.set(true, forKey: SystemDirectoryMigration.migrationCompletedKey)
        let root = try makeTemporaryRoot()
        let migrator = SystemDirectoryMigration(defaults: defaults, documentsRoot: root)

        // Should return immediately without error.
        try await migrator.migrateIfNeeded()
        XCTAssertTrue(await migrator.isMigrationCompleted)
    }

    func testResetMigrationFlag() async {
        let defaults = makeFreshDefaults()
        defaults.set(true, forKey: SystemDirectoryMigration.migrationCompletedKey)
        let migrator = SystemDirectoryMigration(defaults: defaults)

        await migrator.resetMigrationFlag()
        XCTAssertFalse(await migrator.isMigrationCompleted)
    }

    // MARK: - File-move tests

    func testPSPDirectoryMigrated() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "PSP/flash0/font.pgf")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        try await migrator.migrateIfNeeded()

        XCTAssertFalse(exists(root.appendingPathComponent("PSP")),
                       "Source PSP/ dir should be removed after migration")
        XCTAssertTrue(exists(root.appendingPathComponent("System/PSP/flash0/font.pgf")),
                      "flash0/font.pgf should exist at System/PSP/")
    }

    func testN64BatterySavesMigrated() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "com.provenance.n64/MyGame.srm")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        try await migrator.migrateIfNeeded()

        XCTAssertFalse(exists(root.appendingPathComponent("com.provenance.n64")))
        XCTAssertTrue(exists(root.appendingPathComponent("Battery States/com.provenance.n64/MyGame.srm")))
    }

    func testRetroArchSystemMerged() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "RetroArch/system/cores.info")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        try await migrator.migrateIfNeeded()

        XCTAssertFalse(exists(root.appendingPathComponent("RetroArch/system")),
                       "RetroArch/system/ should be removed after migration")
        XCTAssertTrue(exists(root.appendingPathComponent("System/cores.info")),
                      "cores.info should be at System/")
    }

    func testThreeDSLegacyDirsMigrated() async throws {
        let root = try makeTemporaryRoot()
        for name in ["nand", "sdmc", "sysdata"] {
            try seedFile(at: root, relPath: "\(name)/data.bin")
        }

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        try await migrator.migrateIfNeeded()

        for name in ["nand", "sdmc", "sysdata"] {
            XCTAssertFalse(exists(root.appendingPathComponent(name)),
                           "\(name)/ should be removed after migration")
            XCTAssertTrue(exists(root.appendingPathComponent("System/3DS/\(name)/data.bin")),
                          "System/3DS/\(name)/data.bin should exist")
        }
    }

    func testPS2PlayDataFilesMigrated() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "Play Data Files/game.bin")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        try await migrator.migrateIfNeeded()

        XCTAssertFalse(exists(root.appendingPathComponent("Play Data Files")))
        XCTAssertTrue(exists(root.appendingPathComponent("System/PS2/game.bin")))
    }

    func testProgressHandlerReceivesUpdates() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "PSP/file1.bin")
        try seedFile(at: root, relPath: "Play Data Files/file2.bin")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        // `nonisolated(unsafe)` is appropriate here: the progress handler is called
        // serially from within the actor's synchronous nested function, so there is no
        // actual data race even though the compiler cannot verify this statically.
        nonisolated(unsafe) var stepCount = 0
        nonisolated(unsafe) var lastItemsMoved = 0
        try await migrator.migrateIfNeeded { step in
            stepCount += 1
            lastItemsMoved = step.itemsMoved
        }

        XCTAssertEqual(stepCount, 2, "Should receive one progress event per moved item")
        XCTAssertEqual(lastItemsMoved, 2)
    }

    func testNoLegacyDirsIsNoop() async throws {
        let root = try makeTemporaryRoot()
        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)

        var threw = false
        do {
            try await migrator.migrateIfNeeded()
        } catch {
            threw = true
        }

        XCTAssertFalse(threw, "Migration with no legacy dirs should not throw")
        XCTAssertTrue(await migrator.isMigrationCompleted)
    }

    func testExistingDestinationItemsAreNotOverwritten() async throws {
        let root = try makeTemporaryRoot()
        // Seed legacy source file.
        try seedFile(at: root, relPath: "PSP/flash0/font.pgf")
        // Pre-seed a conflicting file at the destination.
        try seedFile(at: root, relPath: "System/PSP/flash0/font.pgf")

        let migrator = SystemDirectoryMigration(defaults: makeFreshDefaults(), documentsRoot: root)
        // Should not throw even though destination already exists.
        try await migrator.migrateIfNeeded()

        // Destination file should still exist.
        XCTAssertTrue(exists(root.appendingPathComponent("System/PSP/flash0/font.pgf")))
    }

    func testMigrationRunsOnlyOnce() async throws {
        let root = try makeTemporaryRoot()
        try seedFile(at: root, relPath: "PSP/flash0/font.pgf")

        let defaults = makeFreshDefaults()
        let migrator = SystemDirectoryMigration(defaults: defaults, documentsRoot: root)

        try await migrator.migrateIfNeeded()
        // Re-seed the source (simulate trying again after migration).
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("PSP/flash0"), withIntermediateDirectories: true)
        try "test2".write(
            to: root.appendingPathComponent("PSP/flash0/font.pgf"), atomically: true, encoding: .utf8)

        // Second call should skip — flag is already set.
        try await migrator.migrateIfNeeded()

        // The re-seeded source should still be there (second migration didn't run).
        XCTAssertTrue(exists(root.appendingPathComponent("PSP/flash0/font.pgf")))
    }
}
