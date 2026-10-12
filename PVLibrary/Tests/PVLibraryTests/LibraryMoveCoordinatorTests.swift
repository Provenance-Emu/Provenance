//
//  LibraryMoveCoordinatorTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

// swiftlint:disable:next type_body_length
final class LibraryMoveCoordinatorTests: XCTestCase {
    private var base: URL!
    private var group: URL!
    private var local: URL!
    private var picked: URL!
    private var picked2: URL!
    private var store = LibraryMoveJournalStore(url: URL(fileURLWithPath: NSTemporaryDirectory()))
    private var recorder = Recorder()
    private var defaults: UserDefaults!
    private var defaultsSuite = ""
    private var folderStore: PickedLibraryFolderStore!

    private static let thisApp = "org.test.full"
    private static let otherApp = "org.test.lite"

    private final class Recorder: @unchecked Sendable {
        var switches: [LibraryLocation] = []
        var switchedFolders: [PickedLibraryFolder?] = []
        var remaps: [[String: String]] = []
        var sourceExistedWhenApplied = false
        func record(_ location: LibraryLocation, _ folder: PickedLibraryFolder?) {
            switches.append(location)
            switchedFolders.append(folder)
        }
    }

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryMoveCoordinatorTests")
        group = base.appendingPathComponent("group/Documents", isDirectory: true)
        local = base.appendingPathComponent("app/Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        picked = base.appendingPathComponent("picked/A", isDirectory: true)
        picked2 = base.appendingPathComponent("picked/B", isDirectory: true)
        try FileManager.default.createDirectory(at: picked, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: picked2, withIntermediateDirectories: true)
        store = LibraryMoveJournalStore(url: base.appendingPathComponent("support/move-journal.json"))
        recorder = Recorder()
        defaultsSuite = "LibraryMoveCoordinatorTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        folderStore = PickedLibraryFolderStore(defaults: defaults, key: "libraryPickedFolder")
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuite)
        LibraryMoveTestSupport.removeTree(base)
    }

    /// - Parameters:
    ///   - launched: the launch axis (`appGroup`, `appStorage` or `pickedFolder`).
    ///   - launchedFolder: the stored picked folder when `launched == .pickedFolder`.
    ///   - live: what `LibraryLocation.current` reports (it also follows iCloud Drive mode); defaults to `launched`.
    private func coordinator(launched: LibraryLocation, launchedFolder: PickedLibraryFolder? = nil, live: LibraryLocation? = nil,
                             groupAvailable: Bool = true, variantID: String = LibraryMoveCoordinatorTests.thisApp) -> LibraryMoveCoordinator {
        let record = recorder
        let group = groupAvailable ? self.group : nil
        let local: URL = self.local
        let picked: URL = self.picked
        let picked2: URL = self.picked2
        return LibraryMoveCoordinator(journalStore: store,
                                      rootProvider: { location, folder in
                                          switch location {
                                          case .appGroup: return group
                                          case .appStorage: return local
                                          case .iCloudDrive: return nil
                                          // Tests name picked roots by display name: "A" is `picked`, "B" is `picked2`.
                                          case .pickedFolder: return (folder ?? launchedFolder)?.displayName == "B" ? picked2 : picked
                                          }
                                      },
                                      launchedLocation: { live ?? launched },
                                      resumeLocation: { launched },
                                      launchedFolder: { launchedFolder },
                                      switchLocation: { record.record($0, $1) },
                                      folderStore: folderStore,
                                      planner: LibraryMovePlanner(availableCapacity: { _ in .max }),
                                      sharedDefaults: defaults,
                                      variantID: variantID)
    }

    private func folderA(includesSaves: Bool = false) -> PickedLibraryFolder {
        PickedLibraryFolder(bookmark: Data([1]), displayName: "A", includesSaves: includesSaves, pickedAt: Date(timeIntervalSinceReferenceDate: 1))
    }

    private func write(_ root: URL, _ relativePath: String, _ text: String) throws {
        try LibraryMoveTestSupport.write(root, relativePath, text)
    }

    private func write(_ root: URL, _ relativePath: String, bytes: Int) throws {
        try LibraryMoveTestSupport.write(root, relativePath, bytes: bytes)
    }

    private func read(_ root: URL, _ relativePath: String) -> String? {
        LibraryMoveTestSupport.read(root, relativePath)
    }

    private func exists(_ root: URL, _ relativePath: String) -> Bool {
        LibraryMoveTestSupport.exists(root, relativePath)
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

    // MARK: - Picked folder (phase 3)

    func testMoveToPickedFolderCopiesSharedFoldersOnly() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(local, "BIOS/x.bin", "bios")
        try write(local, "Save States/Game/s.svs", "save")
        try write(local, "Imports/new.zip", "zip")
        let c = coordinator(launched: .appStorage)
        let outcome = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(picked, "BIOS/x.bin"), "bios")
        XCTAssertFalse(exists(picked, "Save States/Game/s.svs"))
        XCTAssertFalse(exists(picked, "Imports/new.zip"))
        XCTAssertTrue(LibraryManifest.exists(in: picked))
        XCTAssertEqual(recorder.switches, [.pickedFolder])
        let folder = try XCTUnwrap(recorder.switchedFolders.last ?? nil)
        XCTAssertEqual(folder.displayName, "A")
        XCTAssertFalse(folder.includesSaves)
        XCTAssertNoThrow(try LibraryFolderBookmark.resolve(folder.bookmark))
        XCTAssertEqual(try XCTUnwrap(store.load()).keepCopy, false)
    }

    func testIncludeSavesMovesTheSavesFoldersToo() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(local, "Save States/Game/s.svs", "save")
        try write(local, "Battery States/Game/g.sav", "sram")
        let c = coordinator(launched: .appStorage)
        _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: true)
        XCTAssertEqual(read(picked, "Save States/Game/s.svs"), "save")
        XCTAssertEqual(read(picked, "Battery States/Game/g.sav"), "sram")
        XCTAssertEqual((recorder.switchedFolders.last ?? nil)?.includesSaves, true)
    }

    func testMoveToPickedFolderFromAppGroupIsRefused() async throws {
        let c = coordinator(launched: .appGroup)
        do {
            _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .appGroup, to: .pickedFolder))
        }
        XCTAssertFalse(c.hasPendingMove)
    }

    func testMoveToPickedFolderWhileICloudDriveModeIsOnIsRefused() async throws {
        let c = coordinator(launched: .appStorage, live: .iCloudDrive)
        do {
            _ = try await c.moveToPickedFolder(picked, displayName: "A", includeSaves: false)
            XCTFail("expected unsupportedMove")
        } catch {
            XCTAssertEqual(error as? LibraryMoveError, .unsupportedMove(from: .iCloudDrive, to: .pickedFolder))
        }
    }

    func testLeavingAPickedFolderKeepsACopyAndCarriesItsSaves() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "Save States/Game/s.svs", "save")
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: true))
        let outcome = try await c.moveToAppStorage(keepCopy: false)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(local, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        XCTAssertEqual(read(local, "Save States/Game/s.svs"), "save")
        let journal = try XCTUnwrap(store.load())
        XCTAssertTrue(journal.keepCopy, "the shared folder is left untouched")
        XCTAssertEqual(journal.sourceFolder?.displayName, "A")
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertNil(recorder.switchedFolders.last ?? nil)
    }

    func testLeavingAPickedFolderWithoutSavesLeavesSavesAlone() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "Save States/Game/s.svs", "someone else's")
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: false))
        _ = try await c.moveToAppStorage()
        XCTAssertFalse(exists(local, "Save States/Game/s.svs"))
    }

    #if !os(tvOS)
    func testCleanupAfterLeavingResolvesTheOldFolderFromTheJournal() async throws {
        // The stored folder was cleared at the switch; the journal's sourceFolder names the old root.
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let leaving = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        _ = try await leaving.moveToAppStorage()
        let relaunched = coordinator(launched: .appStorage)
        let outcome = await relaunched.resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "rom", "keep-copy: nothing deleted in the shared folder")
        XCTAssertFalse(relaunched.hasPendingMove)
    }

    func testMovingBetweenTwoPickedFoldersTellsThemApartByPick() async throws {
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        let a = folderA()
        let c = coordinator(launched: .pickedFolder, launchedFolder: a)
        let outcome = try await c.moveToPickedFolder(picked2, displayName: "B", includeSaves: false)
        XCTAssertEqual(outcome, .switched)
        XCTAssertEqual(read(picked2, "ROMs/com.provenance.snes/Game.sfc"), "rom")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.sourceFolder, a)
        XCTAssertEqual(journal.destinationFolder?.displayName, "B")
        XCTAssertTrue(journal.keepCopy)

        // Relaunch still on A (the setting didn't stick): the switch is re-asserted, cleanup waits.
        let stillOnA = coordinator(launched: .pickedFolder, launchedFolder: a)
        let waiting = await stillOnA.resumeIfNeeded(progress: nil)
        XCTAssertNil(waiting)
        XCTAssertEqual(recorder.switches.last, .pickedFolder)
        XCTAssertEqual((recorder.switchedFolders.last ?? nil)?.displayName, "B")

        // Relaunch on B: cleanup runs.
        let b = try XCTUnwrap(journal.destinationFolder)
        let onB = coordinator(launched: .pickedFolder, launchedFolder: b)
        let cleaned = await onB.resumeIfNeeded(progress: nil)
        XCTAssertEqual(cleaned, .cleanedUp)
    }
    #endif

    // MARK: - Remaps (phase 4)

    #if !os(tvOS)
    private func switchedJoinJournal() throws -> LibraryMoveJournal {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        try write(picked, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: local, destinationRoot: picked,
                                                        folders: ["ROMs"], keepCopy: false, destinationFolder: folderA()))
        journal.phase = .switched
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 10, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Game.sfc"),
                                                                     state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Game (USA).sfc")
        journal.remaps = ["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"]
        try store.save(journal)
        return journal
    }

    func testRemapsAreAppliedBeforeCleanupDeletesSources() async throws {
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        let record = recorder
        let localRoot: URL = local
        c.setPathRemapApplier { remaps in
            record.remaps.append(remaps)
            // The record is rewritten first; the source must still be there while it is.
            record.sourceExistedWhenApplied = LibraryMoveTestSupport.exists(localRoot, "ROMs/com.provenance.snes/Game.sfc")
            return Set(remaps.keys)
        }
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(recorder.remaps, [["ROMs/com.provenance.snes/Game.sfc": "ROMs/com.provenance.snes/Game (USA).sfc"]])
        XCTAssertTrue(recorder.sourceExistedWhenApplied, "cleanup deletes sources only after the applier ran")
        XCTAssertFalse(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game (USA).sfc"), "same bytes")
        XCTAssertFalse(exists(picked, "ROMs/com.provenance.snes/Game.sfc"), "a confirmed remap is not copied under its own name")
    }

    func testAnApplierThatConfirmsNothingGetsTheSourceCopiedNotDeleted() async throws {
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        c.setPathRemapApplier { _ in [] }
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "same bytes", "the sweep copied the source under its own name")
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game (USA).sfc"), "same bytes")
        XCTAssertFalse(c.hasPendingMove)
    }

    func testASharedCopyDeletedBeforeRelaunchGetsTheSourceCopiedAndSkipsTheApplier() async throws {
        _ = try switchedJoinJournal()
        try FileManager.default.removeItem(at: picked.appendingPathComponent("ROMs/com.provenance.snes/Game (USA).sfc"))
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        let record = recorder
        c.setPathRemapApplier { remaps in
            record.remaps.append(remaps)
            return Set(remaps.keys)
        }
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertTrue(recorder.remaps.isEmpty, "there is no shared copy left to point a record at")
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Game.sfc"), "same bytes")
    }

    func testAnApplierThatConfirmsASubsetOnlyCleansUpThatSubset() async throws {
        _ = try switchedJoinJournal()
        try write(local, "ROMs/com.provenance.snes/Other.sfc", "other bytes")
        try write(picked, "ROMs/com.provenance.snes/Other (USA).sfc", "other bytes")
        var journal = try XCTUnwrap(store.load())
        journal.entries["ROMs/com.provenance.snes/Other.sfc"] = .init(size: 11, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Other.sfc"),
                                                                     state: .deduplicated, destinationPath: "ROMs/com.provenance.snes/Other (USA).sfc")
        journal.remaps?["ROMs/com.provenance.snes/Other.sfc"] = "ROMs/com.provenance.snes/Other (USA).sfc"
        try store.save(journal)
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        c.setPathRemapApplier { _ in ["ROMs/com.provenance.snes/Game.sfc"] }
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(picked, "ROMs/com.provenance.snes/Game.sfc"), "confirmed: the record follows the shared copy")
        XCTAssertEqual(read(picked, "ROMs/com.provenance.snes/Other.sfc"), "other bytes", "unconfirmed: copied under its own name")
        XCTAssertFalse(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testCleanupWaitsWhenTheRemapApplierThrows() async throws {
        // Review Focus 4: a record that still names the old path must not lose its file.
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        struct Boom: Error {}
        c.setPathRemapApplier { _ in throw Boom() }
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertNil(outcome)
        XCTAssertTrue(c.hasPendingMove)
        XCTAssertTrue(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testCleanupWaitsWhenNoApplierIsRegistered() async throws {
        _ = try switchedJoinJournal()
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        let outcome = await c.resumeIfNeeded(progress: nil)
        XCTAssertNil(outcome)
        XCTAssertTrue(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testAJournalWithoutRemapsNeedsNoApplier() async throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: local, destinationRoot: picked,
                                                        folders: ["ROMs"], keepCopy: false, destinationFolder: folderA()))
        journal.phase = .switched
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 3, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Game.sfc"),
                                                                     state: .copied, destinationPath: nil)
        try store.save(journal)
        let outcome = await coordinator(launched: .pickedFolder, launchedFolder: folderA()).resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
    }
    #endif

    func testPreviewCountsTheFilesThatWouldMove() throws {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", bytes: 10)
        try write(local, "Save States/Game/s.svs", bytes: 5)
        let c = coordinator(launched: .appStorage)
        let withoutSaves = try c.preview(destinationRoot: picked, includeSaves: false)
        XCTAssertEqual(withoutSaves.fileCount, 1)
        XCTAssertEqual(withoutSaves.totalBytes, 10)
        XCTAssertEqual(withoutSaves.requiredBytes, LibraryMovePlanner.requiredBytes(for: 10))
        XCTAssertTrue(withoutSaves.fits)
        XCTAssertEqual(try c.preview(destinationRoot: picked, includeSaves: true).fileCount, 2)
    }

    func testRebindSavesAFreshBookmarkWithoutAMove() throws {
        try folderStore.save(folderA(includesSaves: true))
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA(includesSaves: true))
        try c.rebindPickedFolder(to: picked2, displayName: "Moved")
        XCTAssertEqual(recorder.switches, [.pickedFolder])
        let folder = try XCTUnwrap(recorder.switchedFolders.last ?? nil)
        XCTAssertEqual(folder.displayName, "Moved")
        XCTAssertTrue(folder.includesSaves, "inherited from the previous pick")
        XCTAssertFalse(c.hasPendingMove)
    }

    func testAbandonSwitchesToAppStorageWithoutAMove() throws {
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        try c.abandonPickedFolder()
        XCTAssertEqual(recorder.switches, [.appStorage])
        XCTAssertNil(recorder.switchedFolders.last ?? nil)
        XCTAssertFalse(c.hasPendingMove)
        XCTAssertThrowsError(try coordinator(launched: .appStorage).abandonPickedFolder())
    }

    #if !os(tvOS)
    private func pendingMoveToFolderA(phase: LibraryMovePhase) throws -> LibraryMoveJournal {
        try write(local, "ROMs/com.provenance.snes/Game.sfc", "rom")
        try write(picked, "ROMs/com.provenance.snes/Game.sfc", "rom")
        var journal = LibraryMoveJournal(request: .init(source: .appStorage, destination: .pickedFolder, sourceRoot: local, destinationRoot: picked,
                                                        folders: ["ROMs"], keepCopy: false, destinationFolder: folderA()))
        journal.phase = phase
        journal.entries["ROMs/com.provenance.snes/Game.sfc"] = .init(size: 3, md5: nil, modified: try LibraryMoveTestSupport.modificationDate(local, "ROMs/com.provenance.snes/Game.sfc"),
                                                                     state: .copied, destinationPath: nil)
        try store.save(journal)
        return journal
    }

    func testRebindKeepsThePickAndUpdatesAPendingJournalsBookmark() async throws {
        _ = try pendingMoveToFolderA(phase: .switched)
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        try c.rebindPickedFolder(to: picked2, displayName: "Moved")
        let rebound = try XCTUnwrap(recorder.switchedFolders.last ?? nil)
        XCTAssertEqual(rebound.pickedAt, folderA().pickedAt, "the same pick, so the launch still recognises it")
        let journal = try XCTUnwrap(store.load())
        XCTAssertEqual(journal.destinationFolder?.bookmark, rebound.bookmark)
        XCTAssertEqual(journal.destinationFolder?.pickedAt, folderA().pickedAt)
        XCTAssertNotEqual(journal.destinationFolder?.bookmark, folderA().bookmark)

        // The next launch is on the rebound folder and still cleans up.
        let outcome = await coordinator(launched: .pickedFolder, launchedFolder: rebound).resumeIfNeeded(progress: nil)
        XCTAssertEqual(outcome, .cleanedUp)
        XCTAssertFalse(exists(local, "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testRebindLeavesAJournalForAnotherFolderAlone() throws {
        var journal = try pendingMoveToFolderA(phase: .switched)
        journal.destinationFolder = PickedLibraryFolder(bookmark: Data([9]), displayName: "B", includesSaves: false, pickedAt: Date(timeIntervalSinceReferenceDate: 99))
        try store.save(journal)
        try coordinator(launched: .pickedFolder, launchedFolder: folderA()).rebindPickedFolder(to: picked2, displayName: "Moved")
        XCTAssertEqual(store.load()?.destinationFolder?.bookmark, Data([9]))
    }

    func testAbandonDropsAPendingMoveToThatFolder() throws {
        for phase in [LibraryMovePhase.copying, .switched] {
            _ = try pendingMoveToFolderA(phase: phase)
            let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
            try c.abandonPickedFolder()
            XCTAssertFalse(c.hasPendingMove, "\(phase) journal is dropped")
            XCTAssertTrue(exists(local, "ROMs/com.provenance.snes/Game.sfc"), "the source is intact")
        }
        XCTAssertEqual(recorder.switches, [.appStorage, .appStorage])
    }

    func testAbandonDuringCleanupIsRefusedAndKeepsTheJournal() throws {
        _ = try pendingMoveToFolderA(phase: .cleaning)
        let c = coordinator(launched: .pickedFolder, launchedFolder: folderA())
        XCTAssertThrowsError(try c.abandonPickedFolder()) { XCTAssertEqual($0 as? LibraryMoveError, .moveInProgress) }
        XCTAssertTrue(c.hasPendingMove)
        XCTAssertTrue(recorder.switches.isEmpty)
    }
    #endif

    func testRootsAreUnavailableWhereTheEngineHasNoRoot() {
        #if os(tvOS)
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appGroup, folder: nil))
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .appStorage, folder: nil))
        XCTAssertNil(LibraryMoveCoordinator.defaultJournalStore(), "tvOS creates nothing on disk")
        #endif
        XCTAssertNil(LibraryMoveCoordinator.defaultRoot(for: .iCloudDrive, folder: nil), "phase 5")
    }
}
