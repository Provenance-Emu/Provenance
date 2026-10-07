import XCTest

final class PVAzaharDataMigratorTests: XCTestCase {
    var tmp: URL!, legacy: URL!, target: URL!
    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        legacy = tmp.appendingPathComponent("Documents"); target = legacy.appendingPathComponent("Azahar")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    private func makeLegacy(_ dirs: [String], bytes: Int = 16) throws {
        for name in dirs {
            let dir = legacy.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(repeating: 1, count: bytes).write(to: dir.appendingPathComponent("file.bin"))
        }
    }

    func testPlanMovesExistingAndSkipsMissing() throws {
        try makeLegacy(["nand", "sdmc"])
        let plan = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target).plan()
        XCTAssertEqual(plan.items.first { $0.directory == "nand" }?.action, .move)
        XCTAssertEqual(plan.items.first { $0.directory == "sysdata" }?.action, .skipMissing)
        XCTAssertEqual(plan.totalBytes, 32)
        XCTAssertTrue(plan.hasWork)
    }

    func testApplyMovesDirectoriesAndWritesMarker() throws {
        try makeLegacy(["nand", "sdmc", "cheats"])
        let migrator = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        try migrator.apply()
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("sdmc/file.bin").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("sdmc").path))
        XCTAssertTrue(migrator.alreadyMigrated)
    }

    func testApplySkipsWhenTargetAlreadyHasTheFiles() throws {
        try makeLegacy(["nand"])
        let existing = target.appendingPathComponent("nand")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 4).write(to: existing.appendingPathComponent("file.bin"))
        let migrator = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        let plan = migrator.plan()
        XCTAssertEqual(plan.items.first { $0.directory == "nand" }?.action, .skipExists)
        XCTAssertEqual(plan.conflicts, ["nand/file.bin"])
        XCTAssertFalse(plan.hasWork)
        try migrator.apply()
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("nand/file.bin").path), "source left untouched")
        XCTAssertEqual(try Data(contentsOf: existing.appendingPathComponent("file.bin")).count, 4, "Azahar's file kept")
    }

    /// azahar creates nand/, sdmc/ (with subdirectories) and log/ on its first boot; a later import must still move the data.
    func testTargetDirsPreCreatedByABootStillImport() throws {
        let fileManager = FileManager.default
        try makeLegacy(["nand", "sdmc"])
        let legacySave = legacy.appendingPathComponent("sdmc/Nintendo 3DS/save.bin")
        try fileManager.createDirectory(at: legacySave.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 3, count: 8).write(to: legacySave)
        for dir in ["nand", "sdmc/Nintendo 3DS", "log"] {
            try fileManager.createDirectory(at: target.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        let migrator = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        let plan = migrator.plan()
        XCTAssertEqual(plan.items.first { $0.directory == "nand" }?.action, .merge)
        XCTAssertEqual(plan.items.first { $0.directory == "sdmc" }?.action, .merge)
        XCTAssertEqual(plan.totalBytes, 16 + 16 + 8)
        XCTAssertTrue(plan.conflicts.isEmpty)
        try migrator.apply()
        for file in ["nand/file.bin", "sdmc/file.bin", "sdmc/Nintendo 3DS/save.bin"] {
            XCTAssertTrue(fileManager.fileExists(atPath: target.appendingPathComponent(file).path), "\(file) imported")
            XCTAssertFalse(fileManager.fileExists(atPath: legacy.appendingPathComponent(file).path), "\(file) moved, not copied")
        }
        XCTAssertTrue(migrator.alreadyMigrated)
    }

    func testApplyIsIdempotent() throws {
        try makeLegacy(["nand"])
        let migrator = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        try migrator.apply()
        try makeLegacy(["sdmc"])             // new legacy data after the marker exists
        let second = try migrator.apply()
        XCTAssertFalse(second.hasWork, "marker short-circuits a second run")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("sdmc/file.bin").path), "second run moves nothing")
    }

    func testStatesAreNeverMigrated() throws {
        try makeLegacy(["states"])
        let plan = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target).plan()
        XCTAssertNil(plan.items.first { $0.directory == "states" })
    }

    func testNothingToMoveWritesNoMarker() throws {
        let migrator = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        let plan = try migrator.apply()
        XCTAssertFalse(plan.hasWork)
        XCTAssertFalse(migrator.alreadyMigrated)
    }
}
