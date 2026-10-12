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
    private var defaults: UserDefaults!
    private var defaultsSuite = ""

    private static let thisApp = "org.test.full"
    private static let otherApp = "org.test.lite"

    private final class Recorder: @unchecked Sendable { var switches: [LibraryLocation] = [] }

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveCoordinatorTests")
        group = base.appendingPathComponent("group/Documents", isDirectory: true)
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
        recorder = Recorder()
        defaultsSuite = "LibraryMoveCoordinatorTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuite)
        LibraryMoveTestSupport.removeTree(base)
    }

    /// - Parameters:
    ///   - launched: the appGroup/appStorage axis this process launched on.
    ///   - live: what `LibraryLocation.current` reports (it also follows iCloud Drive mode); defaults to `launched`.
    private func coordinator(launched: LibraryLocation, live: LibraryLocation? = nil, groupAvailable: Bool = true,
                             variantID: String = LibraryMoveCoordinatorTests.thisApp) -> LibraryMoveCoordinator {
        let record = recorder
        let group = groupAvailable ? self.group : nil
        let local = self.local
        return LibraryMoveCoordinator(journalStore: store,
                                      rootProvider: { location in
                                          switch location {
                                          case .appGroup: return group
                                          case .appStorage: return local
                                          case .iCloudDrive, .pickedFolder: return nil
                                          }
                                      },
                                      launchedLocation: { live ?? launched },
                                      resumeLocation: { launched },
                                      switchLocation: { record.switches.append($0) },
                                      planner: LibraryMovePlanner(availableCapacity: { _ in .max }),
                                      sharedDefaults: defaults,
                                      variantID: variantID)
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

    func testHasPendingMoveIsAPureCheck() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.url)
        let c = coordinator(launched: .appGroup)
        XCTAssertTrue(c.hasPendingMove)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url.path), "asking must not delete the journal")
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

    func testCopyingJournalWithClaimsIsLeftAloneWhenThisLaunchIsAlreadyOnTheDestination() async throws {
        // Claims outstanding mean the copy loop never finished, so a launch on the destination cannot be the one a
        // completed switch produced.
        var journal = try copyingJournal()
        journal.inFlight = ["ROMs/a/x.sfc"]
        try store.save(journal)

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertEqual(store.load()?.phase, .copying)
        XCTAssertTrue(recorder.switches.isEmpty)
    }

    func testACopyingJournalWhoseSwitchLandedIsFinishedOnTheDestination() async throws {
        // performSwitch wrote the setting, then the process died before the journal said "switched".
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)
        var journal = try XCTUnwrap(store.load())
        journal.phase = .copying
        journal.inFlight = []
        try store.save(journal)

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertNil(read(group, "ROMs/a/Game.sfc"))
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
        XCTAssertNil(store.load())
    }

    func testASwitchedJournalOnTheSourceReassertsTheSetting() async throws {
        // The journal says "switched" but the setting was not persisted before the process died.
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        let outcome = await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertEqual(recorder.switches, [.appStorage, .appStorage], "the setting is written again so the next launch lands on the destination")
        XCTAssertEqual(store.load()?.phase, .switched)
        XCTAssertEqual(read(group, "ROMs/a/Game.sfc"), "rom", "nothing is deleted from this launch")
    }

    func testResumeFollowsTheLaunchAxisNotTheLiveICloudDriveMode() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)

        // iCloud Drive mode is on, so the live location is .iCloudDrive; the process still launched on app storage.
        let outcome = await coordinator(launched: .appStorage, live: .iCloudDrive).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertNil(read(group, "ROMs/a/Game.sfc"))
    }

    func testCleanupCarriesTopLevelEntriesCreatedAfterTheMoveStarted() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)
        // The old process kept running: a core made its first folder, a loose file appeared, the Realm was written.
        try write(group, "Azahar/sdmc/title.bin", "core data")
        try write(group, "late.txt", "written late")
        try write(group, "default.realm", "database")

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(local, "Azahar/sdmc/title.bin"), "core data")
        XCTAssertEqual(read(local, "late.txt"), "written late")
        XCTAssertNil(read(group, "Azahar/sdmc/title.bin"), "nothing is left invisible in the group")
        XCTAssertNil(read(group, "late.txt"))
        XCTAssertEqual(read(group, "default.realm"), "database", "the Realm is never moved or deleted")
        XCTAssertNil(store.load())
    }

    // MARK: - Lite and the full app share the App Group

    func testResumeRecordsThisAppsLocationInTheSharedDefaults() async {
        await coordinator(launched: .appGroup).resumeIfNeeded(progress: nil)
        XCTAssertEqual(defaults.string(forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.thisApp), "appGroup")
        await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)
        XCTAssertEqual(defaults.string(forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.thisApp), "appStorage")
    }

    func testMoveKeepsACopyWhileAnotherAppStillUsesTheAppGroup() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        defaults.set("appGroup", forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.otherApp)

        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(store.load()?.keepCopy, true)
        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(group, "ROMs/a/Game.sfc"), "rom", "the other app keeps its library")
        XCTAssertEqual(read(local, "ROMs/a/Game.sfc"), "rom")
    }

    func testCleanupForcesKeepCopyWhenAnotherAppAppearsAfterTheMove() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(store.load()?.keepCopy, false)
        defaults.set("appGroup", forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.otherApp)

        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(group, "ROMs/a/Game.sfc"), "rom")
    }

    func testOnlyOurOwnRecordOrAnAppOnAppStorageDoesNotForceKeepCopy() async throws {
        try write(group, "ROMs/a/Game.sfc", "rom")
        defaults.set("appGroup", forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.thisApp)
        defaults.set("appStorage", forKey: LibraryMoveFolders.variantLocationKeyPrefix + Self.otherApp)

        _ = try await coordinator(launched: .appGroup).moveToAppStorage(keepCopy: false, progress: nil)
        XCTAssertEqual(store.load()?.keepCopy, false)
        let outcome = await coordinator(launched: .appStorage).resumeIfNeeded(progress: nil)

        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertNil(read(group, "ROMs/a/Game.sfc"))
    }

    func testMissingSourceContainerKeepsTheJournal() async throws {
        _ = try copyingJournal()

        let outcome = await coordinator(launched: .appGroup, groupAvailable: false).resumeIfNeeded(progress: nil)

        XCTAssertNil(outcome)
        XCTAssertNotNil(store.load())
        XCTAssertTrue(recorder.switches.isEmpty)
    }
    #endif

    func testRootsAreUnavailableWhereTheEngineHasNoRoot() {
        #if os(tvOS)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appGroup))
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appStorage))
        XCTAssertNil(LibraryMoveCoordinator.defaultJournalStore(), "tvOS creates nothing on disk")
        #endif
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .iCloudDrive), "phase 5")
    }
}
