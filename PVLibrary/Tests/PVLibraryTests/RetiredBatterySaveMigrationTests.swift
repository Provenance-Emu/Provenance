//
//  RetiredBatterySaveMigrationTests.swift
//  PVLibraryTests
//

import XCTest
import PVRealm
@testable import PVLibrary

final class RetiredBatterySaveMigrationTests: XCTestCase {
    private var root: URL!
    private var battery: URL!
    private var states: URL!
    private let rom = "Game (USA)"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        battery = root.appendingPathComponent("Battery States")
        states = root.appendingPathComponent("Save States")
        try FileManager.default.createDirectory(at: battery, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: states, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ dir: URL, _ ext: String, _ text: String) throws -> URL {
        let folder = dir.appendingPathComponent(rom, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(rom).appendingPathExtension(ext)
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func read(_ dir: URL, _ ext: String) -> String? {
        try? String(contentsOf: dir.appendingPathComponent(rom).appendingPathComponent(rom).appendingPathExtension(ext), encoding: .utf8)
    }

    private func migrate(_ rules: [RetiredBatterySaveRule]) -> [String] {
        RetiredBatterySaveMigration.migrate(romBase: rom, rules: rules, batteryRoot: battery, saveStatesRoot: states)
    }

    func testCopiesBatteryFileToSRMAndKeepsOriginal() throws {
        try write(battery, "sav", "ram")
        let log = migrate([.copiedToSRM("sav")])
        XCTAssertEqual(read(battery, "srm"), "ram")
        XCTAssertEqual(read(battery, "sav"), "ram")
        XCTAssertEqual(log.count, 1)
    }

    func testNeverOverwritesAnExistingSRM() throws {
        try write(battery, "eep", "old native")
        try write(battery, "srm", "newer thin")
        XCTAssertTrue(migrate([.copiedToSRM("eep")]).isEmpty)
        XCTAssertEqual(read(battery, "srm"), "newer thin")
    }

    func testMovesFromSaveStatesAndCopiesSRM() throws {
        try write(states, "sav", "ds")
        _ = migrate([.movedFromSaveStates("sav", copyToSRM: true)])
        XCTAssertNil(read(states, "sav"))
        XCTAssertEqual(read(battery, "sav"), "ds")
        XCTAssertEqual(read(battery, "srm"), "ds")
    }

    func testMovesDSVWithoutSRM() throws {
        try write(states, "dsv", "desmume")
        _ = migrate([.movedFromSaveStates("dsv")])
        XCTAssertEqual(read(battery, "dsv"), "desmume")
        XCTAssertNil(read(battery, "srm"))
    }

    func testMissingSourceIsANoOp() {
        XCTAssertTrue(migrate([.copiedToSRM("sav"), .movedFromSaveStates("dsv")]).isEmpty)
    }

    func testRomBaseDropsDirectoryAndExtension() {
        XCTAssertEqual(RetiredBatterySaveMigration.romBase(of: "com.provenance.gb/Game (USA).gb"), "Game (USA)")
    }

    func testRunMarksEachRetiredCoreDone() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        try write(battery, "sav2", "gba")
        let job = RetiredBatterySaveJob(retiredID: "com.example.retired", rules: [.copiedToSRM("sav2")], romBases: [rom])
        XCTAssertFalse(RetiredBatterySaveMigration.isDone(job.retiredID, defaults: defaults))

        RetiredBatterySaveMigration.run([job], batteryRoot: battery, saveStatesRoot: states, defaults: defaults)

        XCTAssertEqual(read(battery, "srm"), "gba")
        XCTAssertTrue(RetiredBatterySaveMigration.isDone(job.retiredID, defaults: defaults))
    }
}
