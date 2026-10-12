//
//  LibraryMoveEngineTests.swift
//  PVLibraryTests
//

import XCTest
import PVHashing
@testable import PVFileSystem

// swiftlint:disable:next type_body_length
final class LibraryMoveEngineTests: XCTestCase {
    private var base: URL!
    private var src: URL!
    private var dst: URL!
    private var store = LibraryMoveJournalStore(url: URL(fileURLWithPath: NSTemporaryDirectory()))
    private var switched = SwitchRecorder()

    private static let folders = ["ROMs", "BIOS", "Save States"]

    private final class SwitchRecorder: @unchecked Sendable {
        var switches: [LibraryLocation] = []
        var switchedFolders: [PickedLibraryFolder?] = []
        func record(_ location: LibraryLocation, _ folder: PickedLibraryFolder?) {
            switches.append(location)
            switchedFolders.append(folder)
        }
    }

    /// Progress closures are `@Sendable`, so they can't mutate captured `var`s; collect through a box instead.
    private final class ProgressBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _reports: [LibraryMoveProgress] = []
        var reports: [LibraryMoveProgress] { lock.lock(); defer { lock.unlock() }; return _reports }
        func append(_ p: LibraryMoveProgress) { lock.lock(); _reports.append(p); lock.unlock() }
    }

    private final class IntBox: @unchecked Sendable { var value: Int? }

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveEngineTests")
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

    private func engine(md5: any MD5Provider = FileManager.default, capacity: Int64 = .max) -> LibraryMoveEngine {
        let recorder = switched
        return LibraryMoveEngine(journalStore: store, md5Provider: md5,
                                 planner: LibraryMovePlanner(availableCapacity: { _ in capacity }),
                                 manifestAuthor: "org.test.full",
                                 switchLocation: { recorder.record($0, $1) })
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

    // MARK: start

    func testStartCopiesVerifiesSwitchesAndLeavesTheJournalInSwitchedPhase() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(src, "BIOS/scph1001.bin", "bios")
        try write(src, "Save States/Game/s.svs", "state")
        try write(src, "Skins/leave.me", "not moved")

        let seen = ProgressBox()
        let outcome = try await engine().start(request()) { seen.append($0) }

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(switched.switches, [.appStorage])
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(dst, "BIOS/scph1001.bin"), "bios")
        XCTAssertEqual(read(dst, "Save States/Game/s.svs"), "state")
        XCTAssertNil(read(dst, "Skins/leave.me"))
        XCTAssertEqual(read(src, "ROMs/com.provenance.snes/Game.sfc"), "rom", "sources stay until cleanup on the next launch")

        let journal = store.load()
        XCTAssertEqual(journal?.phase, .switched)
        XCTAssertEqual(journal?.entries.count, 3)
        XCTAssertEqual(journal?.entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .copied)
        XCTAssertNotNil(journal?.entries["ROMs/com.provenance.snes/Game.sfc"]?.md5)
        XCTAssertEqual(journal?.inFlight, [], "no claim outlives the copy phase")
        XCTAssertEqual(seen.reports.last?.phase, .switched)
        XCTAssertEqual(seen.reports.last?.filesDone, 3)
        XCTAssertEqual(seen.reports.last?.filesTotal, 3)
    }

    func testStartWithNothingToMoveStillSwitches() async throws {
        let outcome = try await engine().start(request(), progress: nil)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(switched.switches, [.appStorage])
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testStartRejectsUnsupportedPairsBeforeTouchingDisk() async throws {
        let bad = LibraryMoveRequest(source: .appStorage, destination: .iCloudDrive, sourceRoot: src, destinationRoot: dst, folders: ["ROMs"], keepCopy: false)
        do {
            _ = try await engine().start(bad, progress: nil)
            XCTFail("expected unsupportedMove")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .unsupportedMove(from: .appStorage, to: .iCloudDrive))
        }
        XCTAssertNil(store.load())
    }

    func testStartRefusesWhenSpaceIsShort() async throws {
        try write(src, "ROMs/a.sfc", "rom")
        do {
            _ = try await engine(capacity: 10).start(request(), progress: nil)
            XCTFail("expected insufficientSpace")
        } catch let error as LibraryMoveError {
            guard case .insufficientSpace = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(store.load(), "no journal is written when the plan is refused")
        XCTAssertTrue(switched.switches.isEmpty)
    }

    func testStartRefusesWhileAJournalExists() async throws {
        var journal = LibraryMoveJournal(request: request())
        journal.phase = .copying
        try store.save(journal)
        do {
            _ = try await engine().start(request(), progress: nil)
            XCTFail("expected moveInProgress")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .moveInProgress)
        }
    }

    func testVerificationFailureStopsBeforeTheSwitchAndKeepsTheJournal() async throws {
        try write(src, "ROMs/a/Bad.sfc", "rom")
        try write(src, "BIOS/ok.bin", "bios")
        // Verification happens on the hidden temp file, before it is renamed into place.
        let md5 = FailingMD5(badSuffix: "app/Documents/ROMs/a/.Bad.sfc" + LibraryMoveFileCopier.partialSuffix)
        do {
            _ = try await engine(md5: md5).start(request(), progress: nil)
            XCTFail("expected verificationFailed")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .verificationFailed(relativePath: "ROMs/a/Bad.sfc"))
        }
        XCTAssertTrue(switched.switches.isEmpty)
        let journal = store.load()
        XCTAssertEqual(journal?.phase, .copying)
        XCTAssertEqual(journal?.entries["BIOS/ok.bin"]?.state, .copied, "verified files before the failure stay journaled so the retry resumes")
        XCTAssertNil(journal?.entries["ROMs/a/Bad.sfc"])
        XCTAssertFalse(exists(dst, "ROMs/a/Bad.sfc"), "the copier removes the copy that failed verification")
        XCTAssertFalse(exists(dst, "ROMs/a/.Bad.sfc" + LibraryMoveFileCopier.partialSuffix), "and its temp file")
    }

    func testSourceThatVanishesAfterPlanningIsSkippedNotFatal() async throws {
        try write(src, "ROMs/a/A.sfc", "rom a")
        try write(src, "ROMs/a/B.sfc", "rom b")
        let doomed = src.appendingPathComponent("ROMs/a/B.sfc")
        let planned = IntBox()

        // The plan lists A then B. The progress report for A lands after A is copied and before B is attempted:
        // delete B there, so the engine's own skip path runs rather than a fresh plan.
        let outcome = try await engine().start(request()) { report in
            if report.currentPath == "ROMs/a/A.sfc" {
                planned.value = report.filesTotal
                try? FileManager.default.removeItem(at: doomed)
            }
        }

        XCTAssertEqual(planned.value, 2, "B was planned")
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(store.load()?.entries.keys.sorted(), ["ROMs/a/A.sfc"])
        XCTAssertFalse(exists(dst, "ROMs/a/B.sfc"))
    }

    // MARK: resume

    func testResumeRecopiesATornFileTheJournalClaimedAndKeepsVerifiedOnes() async throws {
        try write(src, "ROMs/a/Done.sfc", "done")
        try write(src, "ROMs/a/Torn.sfc", "full content")
        try write(src, "ROMs/a/Missing.sfc", "missing")
        // The crash: Done.sfc copied and journaled; Torn.sfc claimed and half-written; Missing.sfc untouched.
        try write(dst, "ROMs/a/Done.sfc", "done")
        try write(dst, "ROMs/a/Torn.sfc", "full")
        var journal = LibraryMoveJournal(request: request())
        let doneURL = src.appendingPathComponent("ROMs/a/Done.sfc")
        journal.entries["ROMs/a/Done.sfc"] = .init(size: 4, md5: FileManager.default.md5ForFile(at: doneURL, fromOffset: 0), modified: nil, state: .copied, destinationPath: nil)
        journal.inFlight = ["ROMs/a/Torn.sfc", "ROMs/a/Missing.sfc"]
        try store.save(journal)
        let doneBefore = try LibraryMoveTestSupport.modificationDate(dst, "ROMs/a/Done.sfc")

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(dst, "ROMs/a/Torn.sfc"), "full content", "a torn copy the journal claimed is recopied, not a conflict")
        XCTAssertEqual(read(dst, "ROMs/a/Missing.sfc"), "missing")
        XCTAssertFalse(exists(dst, "Conflicts"))
        XCTAssertEqual(try LibraryMoveTestSupport.modificationDate(dst, "ROMs/a/Done.sfc"), doneBefore, "a journaled, intact file is not recopied")
        let after = store.load()
        XCTAssertEqual(after?.phase, .switched)
        XCTAssertEqual(after?.entries.count, 3)
        XCTAssertEqual(after?.entries["ROMs/a/Torn.sfc"]?.state, .copied)
        XCTAssertEqual(switched.switches, [.appStorage])
    }

    func testResumeNeverDeletesAPreexistingDestinationFileTheJournalDoesNotOwn() async throws {
        try write(src, "ROMs/a/Foreign.sfc", "incoming version")
        try write(dst, "ROMs/a/Foreign.sfc", "mine")
        let journal = LibraryMoveJournal(request: request())
        try store.save(journal)

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(dst, "ROMs/a/Foreign.sfc"), "incoming version", "the live file the app was using takes the real path")
        XCTAssertEqual(read(dst, "Conflicts/ROMs/a/Foreign.sfc"), "mine", "the destination's own file is moved aside, never deleted")
        let entry = store.load()?.entries["ROMs/a/Foreign.sfc"]
        XCTAssertEqual(entry?.state, .displaced)
        XCTAssertEqual(entry?.displacedPath, "Conflicts/ROMs/a/Foreign.sfc")
    }

    func testResumeOfACompleteCopyingJournalDoesNotRecopyAndReassertsTheSwitch() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        _ = try await engine().start(request(), progress: nil)
        var journal = try XCTUnwrap(store.load())
        journal.phase = .copying
        try store.save(journal)
        let before = try LibraryMoveTestSupport.modificationDate(dst, "ROMs/a/Game.sfc")

        let outcome = try await engine().resume(journal, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(try LibraryMoveTestSupport.modificationDate(dst, "ROMs/a/Game.sfc"), before, "nothing was recopied")
        XCTAssertEqual(switched.switches, [.appStorage, .appStorage], "the interrupted run had switched once; the resume's switch is the second and is harmless")
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testResumeOfAnAlreadySwitchedJournalRunsCleanupAndDoesNotSwitchAgain() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        _ = try await engine().start(request(), progress: nil)
        let first = try XCTUnwrap(store.load())

        let outcome = try await engine().resume(first, sourceRoot: src, destinationRoot: dst, progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(switched.switches, [.appStorage], "no second switch")
        XCTAssertFalse(exists(src, "ROMs/a/Game.sfc"))
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    // MARK: cancel

    func testCancelBeforeSwitchRollsBackWhatItCreatedAndNothingElse() async throws {
        // Sorted order puts the identical and the conflicting file first, so both branches run before the cancel at file 10.
        try write(src, "ROMs/a/A-Same.sfc", "same")
        try write(dst, "ROMs/a/A-Same.sfc", "same")
        try write(src, "ROMs/a/B-Conflict.sfc", "incoming")
        try write(dst, "ROMs/a/B-Conflict.sfc", "mine")
        for i in 0..<40 { try write(src, String(format: "ROMs/a/Game%03d.sfc", i), "rom \(i)") }
        try write(src, "ROMs/0new/N.sfc", "n")
        try write(src, "ROMs/0pre/P.sfc", "p")
        try FileManager.default.createDirectory(at: dst.appendingPathComponent("ROMs/0pre"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst.appendingPathComponent("BIOS"), withIntermediateDirectories: true)

        let e = engine()
        let seen = ProgressBox()
        let outcome = try await e.start(request()) { report in
            seen.append(report)
            if report.filesDone >= 10 { e.cancel() }
        }

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(seen.reports.count, 10, "cancel stops the copy at the next file")
        XCTAssertFalse(exists(dst, "Conflicts"), "the destination's own file was moved aside during the copy; rollback put it back")
        XCTAssertTrue(switched.switches.isEmpty)
        XCTAssertNil(store.load())
        XCTAssertEqual(read(dst, "ROMs/a/A-Same.sfc"), "same", "identical pre-existing files are untouched")
        XCTAssertEqual(read(dst, "ROMs/a/B-Conflict.sfc"), "mine", "the destination's own file is untouched")
        XCTAssertFalse(exists(dst, "Conflicts"), "the conflict copy and the Conflicts/ folder this move created are gone")
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dst.appendingPathComponent("ROMs/a").path)
        XCTAssertEqual(Set(remaining), ["A-Same.sfc", "B-Conflict.sfc"], "every file the engine copied is gone")
        XCTAssertTrue(exists(dst, "ROMs/0pre"), "a pre-existing empty folder survives the rollback")
        XCTAssertTrue(exists(dst, "BIOS"), "a pre-existing empty top-level folder survives the rollback")
        XCTAssertFalse(exists(dst, "ROMs/0new"), "a folder this move created is removed once empty")
        for i in 0..<40 { XCTAssertEqual(read(src, String(format: "ROMs/a/Game%03d.sfc", i)), "rom \(i)", "sources are never touched by a cancel") }
    }

    func testCancelAfterSwitchIsIgnored() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let e = engine()
        // The final report is delivered after the switch: a cancel requested from there must change nothing.
        let outcome = try await e.start(request()) { report in
            if report.phase == .switched { e.cancel() }
        }
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(store.load()?.phase, .switched)
        XCTAssertEqual(read(dst, "ROMs/a/Game.sfc"), "rom")
    }

    func testAStaleCancelDoesNotAbortTheNextMove() async throws {
        try write(src, "ROMs/a/Game.sfc", "rom")
        let e = engine()
        e.cancel()
        let outcome = try await e.start(request(), progress: nil)
        XCTAssertEqual(outcome, .switched)
    }

    // MARK: journal flushing

    func testJournalIsFlushedEveryTwentyFiveFiles() async throws {
        for i in 0..<30 { try write(src, String(format: "ROMs/a/Game%03d.sfc", i), "rom \(i)") }
        let snapshot = IntBox()
        let store = self.store
        _ = try await engine().start(request()) { p in
            if p.filesDone == LibraryMoveEngine.journalFlushInterval, snapshot.value == nil { snapshot.value = store.load()?.entries.count }
        }
        XCTAssertEqual(snapshot.value, LibraryMoveEngine.journalFlushInterval)
    }

    func testADisplacementIsJournaledAtOnceNotAtTheBatchFlush() async throws {
        // Rollback needs the record to put the destination's own file back, so it must not wait for the batch flush.
        try write(src, "ROMs/a/Game.sfc", "incoming")
        try write(src, "ROMs/a/Zed.sfc", "z")
        try write(dst, "ROMs/a/Game.sfc", "mine")
        let displaced = IntBox()
        let store = self.store
        _ = try await engine().start(request()) { report in
            if report.currentPath == "ROMs/a/Game.sfc" {
                displaced.value = store.load()?.entries.values.filter { $0.state == .displaced }.count
            }
        }
        XCTAssertEqual(displaced.value, 1)
    }

    func testClaimsAreJournaledBeforeTheFilesAreWritten() async throws {
        try write(src, "ROMs/a/One.sfc", "1")
        try write(src, "ROMs/a/Two.sfc", "2")
        let reports = ProgressBox()
        let inFlight = IntBox()
        let store = self.store
        _ = try await engine().start(request()) { p in
            reports.append(p)
            if reports.reports.count == 1 { inFlight.value = store.load()?.inFlight.count }
        }
        XCTAssertEqual(inFlight.value, 2, "the whole batch was claimed in the journal before the first report")
        XCTAssertEqual(store.load()?.createdDirectories, ["ROMs", "ROMs/a"])
    }

    // MARK: - Picked folder (phase 3)

    private func pickedFolder(name: String = "Retro") -> PickedLibraryFolder {
        PickedLibraryFolder(bookmark: Data([1]), displayName: name, includesSaves: false)
    }

    func testAppStorageToPickedFolderCopiesTheSharedFoldersAndWritesTheManifest() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(src, "BIOS/scph5501.bin", "bios")
        try write(src, "System/PSP/font.pgf", "font")
        try write(src, "Save States/Game/s.svs", "save")
        let folder = pickedFolder()
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: dst,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: folder)
        let outcome = try await engine().start(request)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(dst, "BIOS/scph5501.bin"), "bios")
        XCTAssertEqual(read(dst, "System/PSP/font.pgf"), "font")
        XCTAssertFalse(exists(dst, "Save States/Game/s.svs"))
        XCTAssertTrue(LibraryManifest.exists(in: dst))
        XCTAssertEqual(try LibraryManifest.read(from: dst).createdBy, "org.test.full")
        XCTAssertEqual(switched.switchedFolders.last??.displayName, "Retro")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.destinationFolder, folder)
        XCTAssertEqual(journal.version, 2)
    }

    func testJoiningKeepsAnExistingManifest() async throws {
        try write(dst, LibraryManifest.fileName, #"{"version":1,"createdBy":"com.ifly"}"#)
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: dst,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        _ = try await engine().start(request)
        XCTAssertEqual(try LibraryManifest.read(from: dst).createdBy, "com.ifly")
    }

    func testPickedFolderToAppStorageCarriesTheSourceFolderInTheJournal() async throws {
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let folder = pickedFolder()
        let request = LibraryMoveRequest(source: .pickedFolder, destination: .appStorage, sourceRoot: src, destinationRoot: dst,
                                         folders: LibraryMoveFolders.shared, keepCopy: true, sourceFolder: folder)
        let outcome = try await engine().start(request)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(try XCTUnwrap(store.load()).sourceFolder, folder)
        XCTAssertEqual(switched.switches.last, .appStorage)
        XCTAssertNil(switched.switchedFolders.last ?? nil)
        XCTAssertFalse(LibraryManifest.exists(in: dst), "no manifest in App storage")
    }

    func testAppGroupToPickedFolderIsRefused() async {
        let request = LibraryMoveRequest(source: .appGroup, destination: .pickedFolder, sourceRoot: src, destinationRoot: dst,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        do {
            _ = try await engine().start(request)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appGroup, to: .pickedFolder))
        }
    }

    func testADestinationInsideTheSourceRootIsAllowedOutsideMovedFolders() async throws {
        // Review Focus 1 / D12: Documents/MyLib as the picked folder.
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let nested = src.appendingPathComponent("MyLib", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: nested,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        let outcome = try await engine().start(request)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(nested, "ROMs/com.provenance.snes/Game.sfc"), "rom")
    }

    func testADestinationInsideAMovedFolderIsRefused() async throws {
        let inside = src.appendingPathComponent("ROMs/Lib", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: inside,
                                         folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder())
        do {
            _ = try await engine().start(request)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appStorage, to: .pickedFolder))
        }
    }

    // MARK: - Join (phase 4)

    private func joinRequest(deduplicate: Bool = true) -> LibraryMoveRequest {
        LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: dst,
                           folders: LibraryMoveFolders.shared, keepCopy: false, destinationFolder: pickedFolder(), deduplicateByMD5: deduplicate)
    }

    func testJoinRecordsASharedCopyUnderAnotherNameInsteadOfCopying() async throws {
        try write(dst, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(src, "ROMs/com.provenance.snes/New.sfc", "new")
        let outcome = try await engine().start(joinRequest())
        XCTAssertEqual(outcome, .switched)
        XCTAssertFalse(exists(dst, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/New.sfc"), "new")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .deduplicated)
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/Game.sfc"]?.destinationPath, "ROMs/com.provenance.snes/Game (USA).sfc")
        XCTAssertEqual(journal.remaps, ["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"])
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/New.sfc"]?.state, .copied)
    }

    func testSamePathStillGoesThroughTheIdenticalRule() async throws {
        try write(dst, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        _ = try await engine().start(joinRequest())
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.entries["ROMs/com.provenance.snes/Game.sfc"]?.state, .identical)
        XCTAssertNil(journal.remaps)
    }

    func testWithoutDeduplicationTheFileIsCopied() async throws {
        try write(dst, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        _ = try await engine().start(joinRequest(deduplicate: false))
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game.sfc"), "same bytes")
    }

    func testSavesAreNeverDeduplicated() async throws {
        try write(dst, "Save States/Other/s.svs", "same bytes")
        try write(src, "Save States/Game/s.svs", "same bytes")
        let request = LibraryMoveRequest(source: .appStorage, destination: .pickedFolder, sourceRoot: src, destinationRoot: dst,
                                         folders: LibraryMoveFolders.shared + LibraryMoveFolders.saves, keepCopy: false,
                                         destinationFolder: pickedFolder(), deduplicateByMD5: true)
        _ = try await engine().start(request)
        XCTAssertEqual(read(dst, "Save States/Game/s.svs"), "same bytes")
    }

    func testBIOSIsNeverDeduplicated() async throws {
        // Cores find BIOS files by path, so a copy under another name would not help them.
        try write(dst, "BIOS/scph5501-copy.bin", "same bytes")
        try write(src, "BIOS/scph5501.bin", "same bytes")
        _ = try await engine().start(joinRequest())
        XCTAssertEqual(read(dst, "BIOS/scph5501.bin"), "same bytes")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.entries["BIOS/scph5501.bin"]?.state, .copied)
        XCTAssertNil(journal.remaps)
    }

    func testAMatchInAnotherSystemFolderIsCopiedNotDeduplicated() async throws {
        try write(dst, "ROMs/com.provenance.gba/Game.gba", "same bytes")
        try write(src, "ROMs/com.provenance.gb/Game.gb", "same bytes")
        _ = try await engine().start(joinRequest())
        XCTAssertEqual(read(dst, "ROMs/com.provenance.gb/Game.gb"), "same bytes")
        XCTAssertEqual(try XCTUnwrap(store.load()).entries["ROMs/com.provenance.gb/Game.gb"]?.state, .copied)
    }

    func testADiscSetIsCopiedWholeEvenWhenItsTrackMatchesAnotherName() async throws {
        try write(dst, "ROMs/com.provenance.psx/Game (USA).bin", "same bytes")
        try write(src, "ROMs/com.provenance.psx/Game.cue", "FILE \"Game.bin\" BINARY")
        try write(src, "ROMs/com.provenance.psx/Game.bin", "same bytes")
        _ = try await engine().start(joinRequest())
        XCTAssertEqual(read(dst, "ROMs/com.provenance.psx/Game.bin"), "same bytes")
        XCTAssertNotNil(read(dst, "ROMs/com.provenance.psx/Game.cue"))
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.entries["ROMs/com.provenance.psx/Game.bin"]?.state, .copied)
        XCTAssertNil(journal.remaps)
    }

    func testIsDeduplicableRules() {
        let plan = LibraryMovePlan(items: [
            .init(relativePath: "ROMs/a/Game.sfc", size: 1, modified: nil),
            .init(relativePath: "ROMs/a/Disc.cue", size: 1, modified: nil),
            .init(relativePath: "ROMs/a/Disc.bin", size: 1, modified: nil),
            .init(relativePath: "ROMs/a/Solo.BIN", size: 1, modified: nil),
            .init(relativePath: "ROMs/a/Twin.nes", size: 1, modified: nil),
            .init(relativePath: "ROMs/a/Twin.srm", size: 1, modified: nil),
            .init(relativePath: "BIOS/bios.rom", size: 1, modified: nil)
        ])
        func deduplicable(_ path: String) -> Bool {
            plan.items.first { $0.relativePath == path }.map { LibraryMoveEngine.isDeduplicable($0, in: plan) } ?? false
        }
        XCTAssertTrue(deduplicable("ROMs/a/Game.sfc"))
        XCTAssertFalse(deduplicable("ROMs/a/Disc.cue"))
        XCTAssertFalse(deduplicable("ROMs/a/Disc.bin"))
        XCTAssertFalse(deduplicable("ROMs/a/Solo.BIN"))
        XCTAssertFalse(deduplicable("ROMs/a/Twin.nes"), "its base name is shared")
        XCTAssertFalse(deduplicable("BIOS/bios.rom"))
    }

    func testRollbackLeavesTheSharedCopyAlone() async throws {
        try write(dst, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try write(src, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        var journal = LibraryMoveJournal(request: joinRequest())
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 10, md5: nil, modified: nil, state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Game (USA).sfc")
        try store.save(journal)
        try await engine().rollback(journal, destinationRoot: dst)
        XCTAssertEqual(read(dst, "ROMs/com.provenance.snes/Game (USA).sfc"), "same bytes")
    }
}

/// Real MD5 everywhere except one destination path, which always hashes wrong.
final class FailingMD5: MD5Provider, @unchecked Sendable {
    let badSuffix: String
    init(badSuffix: String) { self.badSuffix = badSuffix }
    func md5ForFile(at url: URL, fromOffset offset: UInt) -> String? {
        url.path.hasSuffix(badSuffix) ? "00000000000000000000000000000000" : FileManager.default.md5ForFile(at: url, fromOffset: offset)
    }
}
