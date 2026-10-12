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
        // Whole-second dates: the journal round-trips through ISO-8601 without fractions, and the test compares for equality.
        var journal = LibraryMoveJournal(request: request, now: Date(timeIntervalSince1970: 1_700_000_000))
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 42, md5: "abc", modified: Date(timeIntervalSince1970: 1_700_000_000), state: .copied, destinationPath: nil)
        journal.entries["Save States/Game/s.svs"] = .init(size: 7, md5: nil, modified: Date(timeIntervalSince1970: 1_700_000_100),
                                                          state: .conflict, destinationPath: "Conflicts/Save States/Game/s.svs")
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

    func testNewerVersionIsDiscarded() throws {
        var journal = makeJournal()
        journal.version = LibraryMoveJournal.currentVersion + 1
        try store.save(journal)
        XCTAssertNil(store.load())
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
