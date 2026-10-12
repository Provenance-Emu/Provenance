//
//  LibraryMoveCoordinatorTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryMoveCoordinatorTests: XCTestCase {
    private var base: URL!
    private var group: URL!
    private var local: URL!
    private var store = LibraryMoveJournalStore(url: URL(fileURLWithPath: NSTemporaryDirectory()))
    private var recorder = Recorder()

    private final class Recorder: @unchecked Sendable { var switches: [LibraryLocation] = [] }

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveCoordinatorTests")
        group = base.appendingPathComponent("group/Documents", isDirectory: true)
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
        recorder = Recorder()
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func coordinator(launched: LibraryLocation, groupAvailable: Bool = true) -> LibraryMoveCoordinator {
        let record = recorder
        let group = groupAvailable ? self.group : nil
        let local = self.local
        return LibraryMoveCoordinator(journalStore: store,
                                      rootProvider: { location in
                                          switch location {
                                          case .appGroup: return group
                                          case .appStorage: return local
                                          case .iCloudDrive: return nil
                                          }
                                      },
                                      launchedLocation: { launched },
                                      switchLocation: { record.switches.append($0) },
                                      planner: LibraryMovePlanner(availableCapacity: { _ in .max }))
    }

    private func write(_ root: URL, _ relativePath: String, _ text: String) throws {
        try LibraryMoveTestSupport.write(root, relativePath, text)
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        LibraryMoveTestSupport.read(root, relativePath)
    }

    private func copyingJournal() throws -> LibraryMoveJournal {
        var journal = LibraryMoveJournal(request: .init(source: .appGroup, destination: .appStorage, sourceRoot: group, destinationRoot: local,
                                                        folders: ["ROMs"], keepCopy: false))
        journal.phase = .copying
        try store.save(journal)
        return journal
    }

    func testResumeWithoutAJournalIsANoOp() async {
        let c = coordinator(launched: .appGroup)
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertNil(outcome)
        XCTAssertFalse(c.hasPendingMove)
    }

    func testMoveToAppStorageRunsTheEngineAgainstTheRealRoots() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        let c = coordinator(launched: .appGroup)
        let outcome = try await c.moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertTrue(c.hasPendingMove, "cleanup is still owed")
    }

    func testMoveToAppStorageCarriesEveryTopLevelEntryExceptHiddenAndRealmFiles() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        try write(group, "DeltaSkins/Skin/info.json", "skin")
        try write(group, "Azahar/sdmc/title.bin", "core data")
        try write(group, "loose.txt", "a loose file")
        try write(group, "default.realm", "database")
        try write(group, ".hidden", "hidden")

        let c = coordinator(launched: .appGroup)
        _ = try await c.moveToAppStorage(keepCopy: false, progress: nil)

        XCTAssertEqual(read(local, "DeltaSkins/Skin/info.json"), "skin")
        XCTAssertEqual(read(local, "Azahar/sdmc/title.bin"), "core data")
        XCTAssertEqual(read(local, "loose.txt"), "a loose file")
        XCTAssertNil(read(local, "default.realm"), "the Realm database stays where it is")
        XCTAssertNil(read(local, ".hidden"))
        XCTAssertEqual(store.load()?.folders, ["Azahar", "DeltaSkins", "ROMs", "loose.txt"], "the folder list is journaled so a resume uses it")
    }

    func testMoveToAppStorageRefusesWhenNotInTheAppGroup() async {
        do {
            _ = try await coordinator(launched: .appStorage).moveToAppStorage(keepCopy: false, progress: nil)
            XCTFail("expected unsupportedMove")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .unsupportedMove(from: .appStorage, to: .appStorage))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testMoveToAppStorageReportsAMissingGroupContainer() async {
        do {
            _ = try await coordinator(launched: .appGroup, groupAvailable: false).moveToAppStorage(keepCopy: false, progress: nil)
            XCTFail("expected rootUnavailable")
        } catch let error as LibraryMoveError {
            XCTAssertEqual(error, .rootUnavailable(.appGroup))
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertNil(store.load())
    }

    func testCancelWithNothingRunningDoesNotAbortALaterMove() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        let c = coordinator(launched: .appGroup)
        c.cancel()
        let outcome = try await c.moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(outcome, .switched)
    }

    #if os(tvOS)
    func testResumeIsANoOpOnTVOSAndLeavesTheJournalAlone() async throws {
        let journal = try copyingJournal()
        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)
        XCTAssertNil(outcome)
        XCTAssertEqual(store.load()?.id, journal.id)
    }
    #else
    func testResumeFinishesAnInterruptedCopyWhenStillLaunchedOnTheSource() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try copyingJournal()

        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testResumeCleansUpWhenLaunchedOnTheDestination() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertNil(read(group, "ROMs/a/Game.sfc"))
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testSwitchedJournalIsLeftAloneWhenThisLaunchIsStillOnTheSource() async throws {
        // The settings were written but this process still runs on the old root (the user hasn't relaunched,
        // or the settings were reset): never delete sources from here.
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertEqual(read(group, "ROMs/a/Game.sfc"), "rom")
        XCTAssertEqual(store.load()?.phase, .switched)
    }

    func testCopyingJournalIsLeftAloneWhenThisLaunchIsAlreadyOnTheDestination() async throws {
        _ = try copyingJournal()

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertEqual(store.load()?.phase, .copying)
        XCTAssertTrue(recorder.switches.isEmpty)
    }

    func testMissingSourceContainerKeepsTheJournal() async throws {
        _ = try copyingJournal()

        let outcome = await coordinator(launched: .appGroup, groupAvailable: false).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertNotNil(store.load())
        XCTAssertTrue(recorder.switches.isEmpty)
    }
    #endif

    func testDefaultRootsAreTheGroupAndLocalDocuments() {
        #if os(tvOS)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appGroup))
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appStorage))
        #else
        XCTAssertEqual(LibraryMoveCoordinator.defaultRoot(for: .appStorage), URL.documentsPathLocal)
        XCTAssertEqual(LibraryMoveCoordinator.defaultRoot(for: .appGroup), URL.documentsPathAppGroup)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .iCloudDrive), "phase 5")
        #endif
    }
}
