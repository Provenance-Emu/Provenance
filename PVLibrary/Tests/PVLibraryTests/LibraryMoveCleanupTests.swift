//
//  LibraryMoveCleanupTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveCleanupTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!
    private var store = LibraryMoveJournalStore(url: URL(fileURLWithPath: NSTemporaryDirectory()))

    private static let folders = ["ROMs", "Save States", "Battery States"]

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveCleanupTests")
        src = base.appendingPathComponent("group/Documents", isDirectory: true)
        dst = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func engine() -> LibraryMoveEngine {
        LibraryMoveEngine(journalStore: store, planner: LibraryMovePlanner(availableCapacity: { _ in .max }), switchLocation: { _ in })
    }

    private func request(keepCopy: Bool = false) -> LibraryMoveRequest {
        .init(source: .appGroup, destination: .appStorage, sourceRoot: src, destinationRoot: dst, folders: Self.folders, keepCopy: keepCopy)
    }

    private func write(_ root: URL, _ relativePath: String, _ text: String) throws {
        try LibraryMoveTestSupport.write(root, relativePath, text)
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        LibraryMoveTestSupport.read(root, relativePath)
    }

    private func exists(_ root: URL, _ relativePath: String) -> Bool {
        LibraryMoveTestSupport.exists(root, relativePath)
    }

    /// Runs a full move up to the switch, as the first launch would.
    private func switchedJournal(keepCopy: Bool = false) async throws -> LibraryMoveJournal {
        _ = try await engine().start(request(keepCopy: keepCopy), progress: nil)
        return try XCTUnwrap(store.load())
    }

    func testCleanupDeletesJournaledSourcesAndEmptiedFoldersAndTheJournal() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(src, "Save States/Game/s.svs", "state")
        try write(src, "Skins/leave.me", "not ours")
        let journal = try await switchedJournal()

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(src, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertFalse(exists(src, "ROMs"), "emptied folders are removed")
        XCTAssertFalse(exists(src, "Save States"))
        XCTAssertEqual(read(src, "Skins/leave.me"), "not ours", "unlisted folders are untouched")
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertFalse(exists(dst, "Conflicts"), "unchanged files are not swept a second time")
        XCTAssertNil(store.load())
    }

    func testCleanupDeltaSweepCopiesFilesWrittenAfterTheSwitch() async throws {
        // The old process kept writing to the source until the user relaunched.
        try write(src, "ROMs/a/Game.sfc", "rom")
        try write(src, "Battery States/Game/Game.srm", "save v1")
        let journal = try await switchedJournal()
        try write(src, "Battery States/Game/Game.srm", "save v2 longer")          // changed after journaling
        try write(src, "Save States/Game/new.svs", "written in the window")       // brand new

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(dst, "Battery States/Game/Game.srm"), "save v1", "the verified copy is never overwritten")
        XCTAssertEqual(read(dst, "Conflicts/Battery States/Game/Game.srm"), "save v2 longer", "the newer source goes to Conflicts/ for the user to pick")
        XCTAssertEqual(read(dst, "Save States/Game/new.svs"), "written in the window")
        XCTAssertFalse(exists(src, "Battery States"))
        XCTAssertFalse(exists(src, "Save States"))
    }

    func testASameSizeChangedFileInBatteryStatesGoesToConflictsNotTreatedAsIdentical() async throws {
        // Battery saves are fixed-size SRAM images: a size check alone would call the new save "identical" and delete it unseen.
        try write(src, "Battery States/Game/Game.srm", "AAAA")
        let journal = try await switchedJournal()
        try write(src, "Battery States/Game/Game.srm", "BBBB")
        let later = Date().addingTimeInterval(60)
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: src.appendingPathComponent("Battery States/Game/Game.srm").path)

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(dst, "Battery States/Game/Game.srm"), "AAAA", "the verified copy is never overwritten")
        XCTAssertEqual(read(dst, "Conflicts/Battery States/Game/Game.srm"), "BBBB", "the changed save is kept for the user")
        XCTAssertFalse(exists(src, "Battery States"), "the source goes only after its content is safe")
    }

    func testChangedSinceJournalUsesSizeThenMtimeWithOneSecondTolerance() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = LibraryMoveJournal.Entry(size: 10, md5: nil, modified: t, state: .copied, destinationPath: nil)
        XCTAssertFalse(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(0.4)), entry: entry),
                       "sub-second drift from the ISO-8601 round trip is not a change")
        XCTAssertFalse(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(-0.4)), entry: entry))
        XCTAssertTrue(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 11, modified: t), entry: entry))
        XCTAssertTrue(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(2)), entry: entry))
        XCTAssertTrue(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: t.addingTimeInterval(-2)), entry: entry))
        XCTAssertFalse(LibraryMoveEngine.changedSinceJournal(.init(relativePath: "x", size: 10, modified: nil), entry: entry), "no mtime available: trust the size")
    }

    func testKeepCopyLeavesSourcesButStillFinishes() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let journal = try await switchedJournal(keepCopy: true)

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(src, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testCleanupOnlyDeletesSourcesTheJournalRecords() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let journal = try await switchedJournal()
        // A hidden file the planner never saw must survive.
        try write(src, "ROMs/a/.nomedia", "hidden")

        _ = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(read(src, "ROMs/a/.nomedia"), "hidden")
        XCTAssertFalse(exists(src, "ROMs/a/Game.sfc"))
        XCTAssertTrue(exists(src, "ROMs/a"), "a folder that still holds something is kept")
    }

    func testCleanupKeepsASourceWhoseCopyHasGoneMissing() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        try write(src, "ROMs/a/Other.sfc", "other")
        let journal = try await switchedJournal()
        try FileManager.default.removeItem(at: dst.appendingPathComponent("ROMs/a/Game.sfc"))

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(src, "ROMs/a/Game.sfc"), "rom", "the only remaining copy is never deleted")
        XCTAssertFalse(exists(src, "ROMs/a/Other.sfc"))
    }

    func testCleanupSurvivesBeingInterruptedAndResumed() async throws {
        try write(src, "ROMs/a/One.sfc", "1")
        try write(src, "ROMs/a/Two.sfc", "2")
        var journal = try await switchedJournal()
        // A crash mid-cleanup: the phase is already .cleaning and One.sfc is already deleted from the source.
        journal.phase = .cleaning
        try store.save(journal)
        try FileManager.default.removeItem(at: src.appendingPathComponent("ROMs/a/One.sfc"))

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(src, "ROMs"))
        XCTAssertEqual(read(dst, "ROMs/a/One.sfc"), "1")
        XCTAssertEqual(read(dst, "ROMs/a/Two.sfc"), "2")
        XCTAssertNil(store.load())
    }
}
