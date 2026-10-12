//
//  LibraryMoveJournalTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveJournalTests: XCTestCase {
    private var dir: URL!
    private var store: LibraryMoveJournalStore!

    override func setUpWithError() throws {
        dir = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveJournalTests")
        store = LibraryMoveJournalStore(url: dir.appendingPathComponent("nested/move-journal.json"))
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(dir)
    }

    private func makeJournal() -> LibraryMoveJournal {
        let request = LibraryMoveRequest(source: .appGroup, destination: .appStorage,
                                         sourceRoot: URL(fileURLWithPath: "/src"), destinationRoot: URL(fileURLWithPath: "/dst"),
                                         folders: ["ROMs", "Save States"], keepCopy: false)
        var journal = LibraryMoveJournal(request: request, now: Date(timeIntervalSince1970: 1_700_000_000))
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 42, md5: "abc", modified: Date(timeIntervalSince1970: 1_700_000_000), state: .copied, destinationPath: nil)
        journal.entries["Save States/Game/s.svs"] = .init(size: 7, md5: nil, modified: Date(timeIntervalSince1970: 1_700_000_100),
                                                          state: .conflict, destinationPath: "Conflicts/Save States/Game/s.svs")
        journal.entries["Battery States/Game/Game.srm"] = .init(size: 4, md5: nil, modified: Date(timeIntervalSince1970: 1_700_000_200.25),
                                                                state: .displaced, destinationPath: nil, displacedPath: "Conflicts/Battery States/Game/Game.srm")
        journal.inFlight = ["ROMs/com.provenance.snes/Next.sfc"]
        journal.createdDirectories = ["ROMs/com.provenance.snes"]
        return journal
    }

    func testLoadWithoutAFileIsNil() {
        XCTAssertNil(store.load())
    }

    func testSaveCreatesIntermediateDirectoriesAndRoundTrips() throws {
        let journal = makeJournal()
        try store.save(journal)
        let loaded = store.load()
        XCTAssertEqual(loaded, journal)
        XCTAssertEqual(loaded?.phase, .copying)
        XCTAssertEqual(loaded?.version, LibraryMoveJournal.currentVersion)
    }

    func testDeleteRemovesTheFileAndIsIdempotent() throws {
        try store.save(makeJournal())
        try store.delete()
        XCTAssertNil(store.load())
        XCTAssertNoThrow(try store.delete())
    }

    func testCorruptJournalIsDiscarded() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url.path), "a journal that can't be read is removed so launch doesn't retry it forever")
    }

    func testUnknownLocationRawValueIsDiscarded() throws {
        try store.save(makeJournal())
        let text = try String(contentsOf: store.url, encoding: .utf8).replacingOccurrences(of: "\"appGroup\"", with: "\"pickedFolder\"")
        try text.write(to: store.url, atomically: true, encoding: .utf8)
        XCTAssertNil(store.load())
    }

    func testDatesRoundTripWithFractionsOfASecond() throws {
        try store.save(makeJournal())
        XCTAssertEqual(store.load()?.entries["Battery States/Game/Game.srm"]?.modified, Date(timeIntervalSince1970: 1_700_000_200.25))
    }

    func testDisplacedEntryRoundTripsItsDisplacedPath() throws {
        try store.save(makeJournal())
        let entry = store.load()?.entries["Battery States/Game/Game.srm"]
        XCTAssertEqual(entry?.state, .displaced)
        XCTAssertNil(entry?.destinationPath)
        XCTAssertEqual(entry?.displacedPath, "Conflicts/Battery States/Game/Game.srm")
    }

    func testNewerVersionIsIgnoredButKept() throws {
        var journal = makeJournal()
        journal.version = LibraryMoveJournal.currentVersion + 1
        try store.save(journal)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.exists, "a newer build may still need this journal to finish its cleanup")
    }

    func testNewerVersionWithAnUnreadableBodyIsStillKept() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version": 99, "phase": "somethingNew"}"#.utf8).write(to: store.url)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.exists)
    }

    func testExistsDoesNotDeleteAnUnreadableJournal() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.url)
        XCTAssertTrue(store.exists)
        XCTAssertTrue(store.exists, "asking twice changes nothing")
        XCTAssertNil(store.load())
        XCTAssertFalse(store.exists)
    }

    func testEntryRecordsSourceSizeAndModificationDate() throws {
        try store.save(makeJournal())
        let entry = store.load()?.entries["ROMs/com.provenance.snes/Game.sfc"]
        XCTAssertEqual(entry?.size, 42)
        XCTAssertEqual(entry?.modified, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testStateRawValuesArePinned() {
        XCTAssertEqual(LibraryMovePhase.copying.rawValue, "copying")
        XCTAssertEqual(LibraryMovePhase.switched.rawValue, "switched")
        XCTAssertEqual(LibraryMovePhase.cleaning.rawValue, "cleaning")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.copied.rawValue, "copied")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.identical.rawValue, "identical")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.conflict.rawValue, "conflict")
        XCTAssertEqual(LibraryMoveJournal.Entry.State.displaced.rawValue, "displaced")
    }

    func testFolderConstantsArePinned() {
        XCTAssertEqual(LibraryMoveFolders.md5Verified, ["ROMs", "BIOS"])
        XCTAssertEqual(LibraryMoveFolders.conflicts, "Conflicts")
    }

    func testProgressFraction() {
        XCTAssertEqual(LibraryMoveProgress(phase: .copying, filesDone: 1, filesTotal: 4, bytesDone: 25, bytesTotal: 100).fraction, 0.25)
        XCTAssertEqual(LibraryMoveProgress(phase: .copying, filesDone: 1, filesTotal: 4, bytesDone: 0, bytesTotal: 0).fraction, 0.25)
        XCTAssertEqual(LibraryMoveProgress(phase: .copying, filesDone: 0, filesTotal: 0, bytesDone: 0, bytesTotal: 0).fraction, 1)
    }
}
