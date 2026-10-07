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
        for d in dirs {
            let dir = legacy.appendingPathComponent(d)
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
        let m = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        try m.apply()
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("sdmc/file.bin").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("sdmc").path))
        XCTAssertTrue(m.alreadyMigrated)
    }

    func testApplySkipsWhenTargetDirectoryExists() throws {
        try makeLegacy(["nand"])
        try FileManager.default.createDirectory(at: target.appendingPathComponent("nand"), withIntermediateDirectories: true)
        let m = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        XCTAssertEqual(m.plan().items.first { $0.directory == "nand" }?.action, .skipExists)
        try m.apply()
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("nand/file.bin").path), "source left untouched")
    }

    func testApplyIsIdempotent() throws {
        try makeLegacy(["nand"])
        let m = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        try m.apply()
        try makeLegacy(["sdmc"])             // new legacy data after the marker exists
        let second = try m.apply()
        XCTAssertFalse(second.hasWork, "marker short-circuits a second run")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("sdmc/file.bin").path), "second run moves nothing")
    }

    func testStatesAreNeverMigrated() throws {
        try makeLegacy(["states"])
        let plan = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target).plan()
        XCTAssertNil(plan.items.first { $0.directory == "states" })
    }

    func testNothingToMoveWritesNoMarker() throws {
        let m = PVAzaharDataMigrator(legacyRoot: legacy, targetRoot: target)
        let plan = try m.apply()
        XCTAssertFalse(plan.hasWork)
        XCTAssertFalse(m.alreadyMigrated)
    }
}
