//
//  RetroArchBatterySaveMigrationTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVLibrary

final class RetroArchBatterySaveMigrationTests: XCTestCase {
    private var root: URL!
    private var saves: URL!
    private var battery: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        saves = root.appendingPathComponent(RetroArchBatterySaveMigration.savesRelativePath, isDirectory: true)
        battery = root.appendingPathComponent("Battery States", isDirectory: true)
        try fileManager.createDirectory(at: saves, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: battery, withIntermediateDirectories: true)
        suiteName = "RetroArchBatterySaveMigrationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? fileManager.removeItem(at: root)
    }

    @discardableResult
    private func writeSRM(_ name: String, _ text: String, in folder: URL? = nil) throws -> URL {
        let directory: URL = folder ?? saves
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func batterySRM(_ romBase: String) -> String? {
        let url = RetroArchBatterySaveMigration.destination(forRomBase: romBase, batteryRoot: battery)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func migrate(_ known: Set<String>) -> RetroArchBatterySaveMigration.Outcome {
        RetroArchBatterySaveMigration.migrate(srmFiles: RetroArchBatterySaveMigration.srmFiles(in: saves),
                                              knownRomBases: known, batteryRoot: battery)
    }

    // MARK: Path mapping

    func testDestinationIsBatteryStatesRomFolderAndName() {
        let url = RetroArchBatterySaveMigration.destination(forRomBase: "Game (USA)", batteryRoot: battery)
        XCTAssertEqual(url.path, battery.appendingPathComponent("Game (USA)/Game (USA).srm").path)
    }

    func testSRMNameMapsToTheSameBaseAsTheGameROM() {
        // RetroArch strips only the last extension of the content path, as the thin wrapper does.
        let pairs = [
            ("Super Metroid (Japan, USA).srm", "ROMs/com.provenance.snes/Super Metroid (Japan, USA).sfc"),
            ("Final Fantasy III v1.1.srm", "ROMs/com.provenance.snes/Final Fantasy III v1.1.smc"),
            ("Game.srm", "ROMs/com.provenance.gba/Subfolder/Game.gba"),
            ("Disc Game.srm", "ROMs/com.provenance.psx/Disc Game.m3u")
        ]
        for (srm, romPath) in pairs {
            XCTAssertEqual(RetroArchBatterySaveMigration.romBase(ofSRM: URL(fileURLWithPath: srm)),
                           RetiredBatterySaveMigration.romBase(of: romPath), srm)
        }
    }

    func testSavesDirectoriesAreDeduplicated() throws {
        let other = root.appendingPathComponent("Caches", isDirectory: true)
        let link = root.appendingPathComponent("Link", isDirectory: true)
        try fileManager.createSymbolicLink(at: link, withDestinationURL: root)
        let dirs = RetroArchBatterySaveMigration.savesDirectories(documentsRoots: [root, other, root, link])
        XCTAssertEqual(dirs.map(\.path), [saves.path, other.appendingPathComponent("RetroArch/saves").path])
    }

    func testSRMFilesListsTopLevelThenSubfoldersAndSkipsOthers() throws {
        try writeSRM("B.srm", "b")
        try writeSRM("A.SRM", "a")
        try writeSRM("notes.txt", "x")
        try writeSRM(".hidden.srm", "h")
        try writeSRM("Sorted.srm", "s", in: saves.appendingPathComponent("Snes9x"))
        try fileManager.createDirectory(at: saves.appendingPathComponent("Folder.srm"), withIntermediateDirectories: true)
        let names = RetroArchBatterySaveMigration.srmFiles(in: saves).map(\.lastPathComponent)
        XCTAssertEqual(names, ["A.SRM", "B.srm", "Sorted.srm"])
    }

    func testMissingSavesDirectoryListsNothing() {
        XCTAssertTrue(RetroArchBatterySaveMigration.srmFiles(in: root.appendingPathComponent("nope")).isEmpty)
    }

    // MARK: Copy behaviour

    func testCopiesMatchingSaveAndKeepsTheOriginal() throws {
        let source = try writeSRM("Game (USA).srm", "ram")
        let outcome = migrate(["Game (USA)"])
        XCTAssertEqual(outcome.copied, 1)
        XCTAssertTrue(outcome.isComplete)
        XCTAssertEqual(batterySRM("Game (USA)"), "ram")
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "ram")
    }

    func testNeverOverwritesAnExistingThinSave() throws {
        try writeSRM("Game.srm", "old retroarch")
        let destination = RetroArchBatterySaveMigration.destination(forRomBase: "Game", batteryRoot: battery)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "newer thin".write(to: destination, atomically: true, encoding: .utf8)

        let outcome = migrate(["Game"])
        XCTAssertEqual(outcome.copied, 0)
        XCTAssertEqual(outcome.alreadyPresent, 1)
        XCTAssertTrue(outcome.isComplete)
        XCTAssertEqual(batterySRM("Game"), "newer thin")
    }

    func testSecondPassIsANoOp() throws {
        try writeSRM("One.srm", "1")
        try writeSRM("Two.srm", "2")
        XCTAssertEqual(migrate(["One", "Two"]).copied, 2)

        let again = migrate(["One", "Two"])
        XCTAssertEqual(again.copied, 0)
        XCTAssertEqual(again.alreadyPresent, 2)
        XCTAssertTrue(again.isComplete)
        XCTAssertEqual(batterySRM("One"), "1")
        XCTAssertEqual(batterySRM("Two"), "2")
    }

    func testTopLevelFileWinsOverASortedDuplicate() throws {
        try writeSRM("Game.srm", "top")
        try writeSRM("Game.srm", "sorted", in: saves.appendingPathComponent("SomeCore"))
        let outcome = migrate(["Game"])
        XCTAssertEqual(outcome.copied, 1)
        XCTAssertEqual(outcome.alreadyPresent, 1)
        XCTAssertEqual(batterySRM("Game"), "top")
    }

    func testUnmatchedSaveIsReportedAndNotCopied() throws {
        try writeSRM("Known.srm", "k")
        try writeSRM("Not Imported.srm", "n")
        let outcome = migrate(["Known"])
        XCTAssertEqual(outcome.copied, 1)
        XCTAssertEqual(outcome.unmatched, ["Not Imported.srm"])
        XCTAssertFalse(outcome.isComplete)
        XCTAssertFalse(fileManager.fileExists(atPath: battery.appendingPathComponent("Not Imported").path))
    }

    func testNoTempFilesAreLeftBehind() throws {
        try writeSRM("Game.srm", "ram")
        _ = migrate(["Game"])
        let folder = battery.appendingPathComponent("Game")
        let leftovers = try fileManager.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasPrefix(RetroArchBatterySaveMigration.tempFilePrefix) }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testCopyFailureIsReported() throws {
        try writeSRM("Game.srm", "ram")
        // A file where the per-game folder should be makes the copy fail.
        try "blocker".write(to: battery.appendingPathComponent("Game"), atomically: true, encoding: .utf8)
        let outcome = migrate(["Game"])
        XCTAssertEqual(outcome.failed, 1)
        XCTAssertFalse(outcome.isComplete)
    }

    // MARK: Done flag

    func testRunMarksDoneOnlyWhenEveryFileIsHandled() throws {
        try writeSRM("Known.srm", "k")
        try writeSRM("Later.srm", "l")
        let files = RetroArchBatterySaveMigration.srmFiles(in: saves)

        RetroArchBatterySaveMigration.run(RetroArchBatterySaveJob(srmFiles: files, knownRomBases: ["Known"]),
                                          batteryRoot: battery, defaults: defaults)
        XCTAssertFalse(RetroArchBatterySaveMigration.isDone(defaults: defaults))
        XCTAssertEqual(batterySRM("Known"), "k")

        // The user imports the other game; the next launch finishes the job.
        RetroArchBatterySaveMigration.run(RetroArchBatterySaveJob(srmFiles: files, knownRomBases: ["Known", "Later"]),
                                          batteryRoot: battery, defaults: defaults)
        XCTAssertTrue(RetroArchBatterySaveMigration.isDone(defaults: defaults))
        XCTAssertEqual(batterySRM("Known"), "k")
        XCTAssertEqual(batterySRM("Later"), "l")
    }

    func testRunDoesNotMarkDoneAfterAFailure() throws {
        try writeSRM("Game.srm", "ram")
        try "blocker".write(to: battery.appendingPathComponent("Game"), atomically: true, encoding: .utf8)
        RetroArchBatterySaveMigration.run(RetroArchBatterySaveJob(srmFiles: RetroArchBatterySaveMigration.srmFiles(in: saves),
                                                                  knownRomBases: ["Game"]),
                                          batteryRoot: battery, defaults: defaults)
        XCTAssertFalse(RetroArchBatterySaveMigration.isDone(defaults: defaults))
    }
}
