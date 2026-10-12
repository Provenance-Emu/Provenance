//
//  LibraryMoveEngineRecoveryTests.swift
//  PVLibraryTests
//
//  Crash recovery, rollback of displaced files and the root guard of the move engine.
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveEngineRecoveryTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!
    private var store = LibraryMoveJournalStore(url: URL(fileURLWithPath: NSTemporaryDirectory()))
    private var switched = SwitchRecorder()

    private static let folders = ["ROMs", "BIOS", "Save States"]

    private final class SwitchRecorder: @unchecked Sendable { var calls: [LibraryLocation] = [] }

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveEngineRecoveryTests")
        src = base.appendingPathComponent("group/Documents", isDirectory: true)
        dst = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/LibraryMove/move-journal.json"))
        switched = SwitchRecorder()
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func engine(capacity: Int64 = .max) -> LibraryMoveEngine {
        let recorder = switched
        return LibraryMoveEngine(journalStore: store,
                                 planner: LibraryMovePlanner(availableCapacity: { _ in capacity }),
                                 switchLocation: { recorder.calls.append($0) })
    }

    private func request() -> LibraryMoveRequest {
        .init(source: .appGroup, destination: .appStorage, sourceRoot: src, destinationRoot: dst, folders: Self.folders, keepCopy: false)
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

    func testResumeRemovesLeftoverTempFilesFromAnInterruptedCopy() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        try write(dst, "ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix, "half a ro")
        try write(dst, "ROMs/a/.Other.sfc" + LibraryMoveFileCopier.partialSuffix, "unrelated leftover")
        try write(dst, "Conflicts/ROMs/.Late.sfc" + LibraryMoveFileCopier.partialSuffix, "leftover in Conflicts")
        let journal = LibraryMoveJournal(request: request())
        try store.save(journal)

        _ = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
        XCTAssertFalse(exists(dst, "ROMs/a/.Game.sfc" + LibraryMoveFileCopier.partialSuffix))
        XCTAssertFalse(exists(dst, "ROMs/a/.Other.sfc" + LibraryMoveFileCopier.partialSuffix))
        XCTAssertFalse(exists(dst, "Conflicts/ROMs/.Late.sfc" + LibraryMoveFileCopier.partialSuffix))
    }

    func testResumeOfACopyingJournalChecksSpaceForTheRemainingFiles() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let journal = LibraryMoveJournal(request: request())
        try store.save(journal)
        do {
            _ = try await engine(capacity: 10).resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)
            XCTFail("expected insufficientSpace")
        } catch let error as LibraryMoveError {
            guard case .insufficientSpace = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(store.load()?.phase, .copying, "the journal is kept")
        XCTAssertTrue(switched.calls.isEmpty)
    }

    func testResumeOfAFinishedCopyNeedsNoFreeSpace() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        _ = try await engine().start(request(), progress: nil)
        var journal = try XCTUnwrap(store.load())
        journal.phase = .copying
        try store.save(journal)

        // Nothing is left to copy, so the headroom requirement alone must not strand the journal on a nearly full device.
        let outcome = try await engine(capacity: 10).resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .switched)
    }

    // MARK: root guard

    func testStartAndResumeRefuseIdenticalOrNestedRoots() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let nested = src.appendingPathComponent("ROMs", isDirectory: true)
        for destination in [try XCTUnwrap(src), nested] {
            let bad = LibraryMoveRequest(source: .appGroup, destination: .appStorage, sourceRoot: src, destinationRoot: destination, folders: Self.folders, keepCopy: false)
            do {
                _ = try await engine().start(bad, progress: nil)
                XCTFail("expected unsupportedMove for \(destination.path)")
            } catch let error as LibraryMoveError {
                XCTAssertEqual(error, .unsupportedMove(from: .appGroup, to: .appStorage))
            }
            do {
                _ = try await engine().resume(LibraryMoveJournal(request: bad), sourceRoot: src, destinationRoot: destination, progress: nil)
                XCTFail("expected unsupportedMove on resume for \(destination.path)")
            } catch let error as LibraryMoveError {
                XCTAssertEqual(error, .unsupportedMove(from: .appGroup, to: .appStorage))
            }
        }
        XCTAssertNil(store.load())
        XCTAssertEqual(read(src, "ROMs/a/Game.sfc"), "rom")
    }

    func testStartDoesNotOverwriteAJournalFromANewerBuild() async throws {
        var newer = LibraryMoveJournal(request: request())
        newer.version = LibraryMoveJournal.currentVersion + 1
        try store.save(newer)
        do {
            _ = try await engine().start(request(), progress: nil)
            XCTFail("expected moveInProgress")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .moveInProgress)
        }
        XCTAssertTrue(store.exists)
    }

    func testRollbackRestoresADisplacedFileAndIsSafeToRetry() async throws {
        // The state a copy leaves: our copy at the real path, the destination's file aside under a numbered name.
        var journal = LibraryMoveJournal(request: request())
        journal.entries["ROMs/a/Game.sfc"] = .init(size: 8, md5: nil, modified: nil, state: .displaced, destinationPath: nil, displacedPath: "Conflicts/ROMs/a/Game-2.sfc")
        try write(dst, "ROMs/a/Game.sfc", "incoming")
        try write(dst, "Conflicts/ROMs/a/Game.sfc", "unrelated earlier conflict")
        try write(dst, "Conflicts/ROMs/a/Game-2.sfc", "mine")
        let e = engine()

        try await e.rollback(journal, destinationRoot: dst)
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "mine")
        XCTAssertFalse(exists(dst, "Conflicts/ROMs/a/Game-2.sfc"))
        XCTAssertEqual(read(dst, "Conflicts/ROMs/a/Game.sfc"), "unrelated earlier conflict", "other Conflicts files are untouched")

        try await e.rollback(journal, destinationRoot: dst)
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "mine", "a retried rollback must not delete the file it just restored")
    }
}
