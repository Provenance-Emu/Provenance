//
//  LibraryLocationTests.swift
//  PVLibraryTests
//
//  LibraryLocation is the one place that decides where library files live. Phase 1 of the
//  storage-locations spec routes existing paths through it, and phase 2 adds the stored
//  setting: these tests pin the settings-to-location table, the root each location
//  resolves to, and the partial paths stored for files under each kind of root.
//

import XCTest
import Defaults
import PVSettings
@testable import PVFileSystem

final class LibraryLocationTests: XCTestCase {

    // MARK: - Settings to location

    func testRawValuesArePinned() {
        // Stored in UserDefaults and in move-journal.json: renaming one breaks resume and downgrade.
        XCTAssertEqual(LibraryLocation.appStorage.rawValue, "appStorage")
        XCTAssertEqual(LibraryLocation.appGroup.rawValue, "appGroup")
        XCTAssertEqual(LibraryLocation.iCloudDrive.rawValue, "iCloudDrive")
        XCTAssertEqual(LibraryLocation.pickedFolder.rawValue, "pickedFolder")
        XCTAssertEqual(LibraryLocation.allCases.count, 4)
    }

    func testICloudDriveNeedsSyncAndDriveMode() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: false, iCloudDriveMode: true), .appStorage)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: true, iCloudDriveMode: false), .appStorage)
    }

    func testAppGroupWithoutICloudDrive() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appGroup)
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: true, iCloudSync: true, iCloudDriveMode: false), .appGroup)
    }

    func testDefaultIsAppStorage() {
        XCTAssertEqual(LibraryLocation.resolve(stored: nil, useAppGroups: false, iCloudSync: false, iCloudDriveMode: false), .appStorage)
    }

    func testStoredLocationWinsOverLegacyToggle() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .appStorage, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appStorage)
        XCTAssertEqual(LibraryLocation.resolve(stored: .appGroup, useAppGroups: false, iCloudSync: false, iCloudDriveMode: false), .appGroup)
    }

    func testICloudDriveStillWinsOverStoredLocation() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .appStorage, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
    }

    func testStoredICloudDriveIsIgnoredUntilPhase5() {
        // Phase 5 moves the iCloud axis into the stored value; until then a stored iCloudDrive falls back to the legacy toggle.
        XCTAssertEqual(LibraryLocation.resolve(stored: .iCloudDrive, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appGroup)
    }

    // MARK: - Root

    private let local = URL(fileURLWithPath: "/docs", isDirectory: true)
    private let group = URL(fileURLWithPath: "/group/Documents", isDirectory: true)
    private let iCloud = URL(fileURLWithPath: "/icloud/Documents", isDirectory: true)

    func testAppStorageRootIsLocalDocumentsEvenWhenAGroupExists() {
        XCTAssertEqual(LibraryLocation.appStorage.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: iCloud, usesAppGroupContainer: false), local)
    }

    func testAppGroupRootIsTheGroupDocumentsAndFallsBackToLocal() {
        XCTAssertEqual(LibraryLocation.appGroup.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: true), group)
        XCTAssertEqual(LibraryLocation.appGroup.rootURL(localDocuments: local, appGroupDocuments: nil, iCloudDocuments: nil, usesAppGroupContainer: true), local)
    }

    func testICloudDriveRootFallsBackToTheAppFilesRoot() {
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: iCloud, usesAppGroupContainer: false), iCloud)
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: false), local)
        // Phase 1 behaviour kept: an App Group user without an iCloud container stays in the group.
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, usesAppGroupContainer: true), group)
    }

    // MARK: - Launch snapshot

    func testAppGroupAxisFollowsStoredThenLaunchToggle() {
        XCTAssertTrue(LibraryLocation.usesAppGroupContainer(stored: .appGroup, useAppGroupsAtLaunch: false))
        XCTAssertFalse(LibraryLocation.usesAppGroupContainer(stored: .appStorage, useAppGroupsAtLaunch: true))
        XCTAssertTrue(LibraryLocation.usesAppGroupContainer(stored: nil, useAppGroupsAtLaunch: true))
        XCTAssertFalse(LibraryLocation.usesAppGroupContainer(stored: nil, useAppGroupsAtLaunch: false))
        // A stored iCloudDrive is ignored (like `resolve`), so the toggle decides.
        XCTAssertTrue(LibraryLocation.usesAppGroupContainer(stored: .iCloudDrive, useAppGroupsAtLaunch: true))
        XCTAssertFalse(LibraryLocation.usesAppGroupContainer(stored: .iCloudDrive, useAppGroupsAtLaunch: false))
    }

    func testSwitchStoredWritesTheSettingMirrorsTheToggleAndPostsOnce() throws {
        // Force the launch snapshots before this test writes anything.
        _ = LibraryLocation.storedAtLaunch
        _ = LibraryLocation.useAppGroupsAtLaunch
        let savedLocation = Defaults[.libraryLocation]
        let savedToggle = Defaults[.useAppGroups]
        addTeardownBlock {
            Defaults[.libraryLocation] = savedLocation
            Defaults[.useAppGroups] = savedToggle
        }

        var received: [Notification] = []
        let token = NotificationCenter.default.addObserver(forName: .libraryLocationDidChange, object: nil, queue: nil) { received.append($0) }
        addTeardownBlock { NotificationCenter.default.removeObserver(token) }

        try LibraryLocation.switchStored(to: .appGroup)
        XCTAssertEqual(Defaults[.libraryLocation], "appGroup")
        XCTAssertTrue(Defaults[.useAppGroups])
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.userInfo?[LibraryLocation.requiresRelaunchUserInfoKey] as? Bool, true)

        try LibraryLocation.switchStored(to: .appStorage)
        XCTAssertEqual(Defaults[.libraryLocation], "appStorage")
        XCTAssertFalse(Defaults[.useAppGroups])
        XCTAssertEqual(received.count, 2)
    }

    func testSwitchStoredDoesNotMoveTheRunningProcess() throws {
        // The first switch of a legacy user rewrites useAppGroups; the library root and the app-files
        // root of this process must stay where they were at launch.
        _ = LibraryLocation.storedAtLaunch
        _ = LibraryLocation.useAppGroupsAtLaunch
        let savedLocation = Defaults[.libraryLocation]
        let savedToggle = Defaults[.useAppGroups]
        addTeardownBlock {
            Defaults[.libraryLocation] = savedLocation
            Defaults[.useAppGroups] = savedToggle
        }

        let axisBefore = LibraryLocation.usesAppGroupContainer
        let currentBefore = LibraryLocation.current
        let documentsBefore = URL.documentsPath
        let cachesBefore = URL.cachesPath
        let legacyBefore = URL.USE_APP_GROUPS

        try LibraryLocation.switchStored(to: axisBefore ? .appStorage : .appGroup)

        XCTAssertEqual(LibraryLocation.usesAppGroupContainer, axisBefore)
        XCTAssertEqual(LibraryLocation.current, currentBefore)
        XCTAssertEqual(URL.documentsPath, documentsBefore)
        XCTAssertEqual(URL.cachesPath, cachesBefore)
        XCTAssertEqual(URL.USE_APP_GROUPS, legacyBefore)
        XCTAssertEqual(URL.documentsiCloudOrLocalPath, currentBefore.rootURL)
    }

    func testLibraryAccessorsUseTheCurrentRoot() {
        let root = LibraryLocation.current.rootURL
        XCTAssertEqual(URL.documentsiCloudOrLocalPath, root)
        XCTAssertEqual(Paths.romsPath, root.appendingPathComponent("ROMs", isDirectory: true))
        XCTAssertEqual(Paths.biosesPath, root.appendingPathComponent("BIOS", isDirectory: true))
        #if !os(tvOS)
        XCTAssertEqual(Paths.systemPath, root.appendingPathComponent("System", isDirectory: true))
        #endif
    }

    // MARK: - Picked folder

    func testStoredPickedFolderIsHonoured() {
        XCTAssertEqual(LibraryLocation.resolve(stored: .pickedFolder, useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .pickedFolder)
        XCTAssertEqual(LibraryLocation.resolve(stored: .pickedFolder, useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertFalse(LibraryLocation.usesAppGroupContainer(stored: .pickedFolder, useAppGroupsAtLaunch: true))
    }

    func testPickedFolderRootFallsBackToLocalDocuments() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.pickedFolder.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: picked, usesAppGroupContainer: false), picked)
        XCTAssertEqual(LibraryLocation.pickedFolder.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: nil, usesAppGroupContainer: false), local)
        // The other cases ignore the picked folder.
        XCTAssertEqual(LibraryLocation.appStorage.rootURL(localDocuments: local, appGroupDocuments: group, iCloudDocuments: nil, pickedFolder: picked, usesAppGroupContainer: false), local)
    }

    func testSavesRootStaysInTheAppUnlessIncluded() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.pickedFolder.savesRootURL(rootURL: picked, appFilesRoot: local, includesSaves: false), local)
        XCTAssertEqual(LibraryLocation.pickedFolder.savesRootURL(rootURL: picked, appFilesRoot: local, includesSaves: true), picked)
        XCTAssertEqual(LibraryLocation.appStorage.savesRootURL(rootURL: local, appFilesRoot: local, includesSaves: false), local)
        XCTAssertEqual(LibraryLocation.appGroup.savesRootURL(rootURL: group, appFilesRoot: group, includesSaves: false), group)
    }

    func testRootForPartialPathSplitsSharedAndSaves() {
        let picked = URL(fileURLWithPath: "/picked", isDirectory: true)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "ROMs/com.provenance.snes/Game.sfc", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "BIOS/scph5501.bin", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "System/PSP/x", libraryRoot: picked, savesRoot: local), picked)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "Save States/Game/s.svs", libraryRoot: picked, savesRoot: local), local)
        XCTAssertEqual(LibraryLocation.root(forPartialPath: "/ROMs/x", libraryRoot: picked, savesRoot: local), picked)
    }

    func testLaunchStateFromStore() throws {
        let base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryLocationTests")
        addTeardownBlock { LibraryMoveTestSupport.removeTree(base) }
        let suite = "LibraryLocationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = PickedLibraryFolderStore(defaults: defaults, key: "k")

        XCTAssertEqual(LibraryLocation.launchState(folder: nil, store: store), .unavailable(reason: "No library folder is saved."))

        let folder = PickedLibraryFolder(bookmark: try LibraryFolderBookmark.make(from: base), displayName: "x", includesSaves: false)
        try store.save(folder)
        XCTAssertEqual(LibraryLocation.launchState(folder: folder, store: store).url?.resolvingSymlinksInPath().path, base.resolvingSymlinksInPath().path)

        let broken = PickedLibraryFolder(bookmark: Data("junk".utf8), displayName: "x", includesSaves: false)
        XCTAssertTrue(LibraryLocation.launchState(folder: broken, store: store).isUnavailable)
    }

    func testSwitchStoredToPickedFolderNeedsAFolder() {
        XCTAssertThrowsError(try LibraryLocation.switchStored(to: .pickedFolder, pickedFolder: nil)) { error in
            XCTAssertEqual(error as? LibraryFolderError, .missingPickedFolder)
        }
    }

    func testSavesAccessorsUseTheSavesRoot() {
        let saves = LibraryLocation.current.savesRootURL
        XCTAssertEqual(URL.savesRootPath, saves)
        XCTAssertEqual(Paths.saveSavesPath, saves.appendingPathComponent("Save States", isDirectory: true))
        XCTAssertEqual(Paths.batterySavesPath, saves.appendingPathComponent("Battery States", isDirectory: true))
        XCTAssertEqual(Paths.cheatsPath, saves.appendingPathComponent("Cheats", isDirectory: true))
    }

    // MARK: - Stored partial paths (unchanged by phase 1)

    private func partialPath(_ path: String) -> String {
        RelativeRoot.documents.createRelativePath(fromURL: URL(fileURLWithPath: path))
    }

    func testPartialPathUnderAppDocuments() {
        let url = URL.documentsPath.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc")
        XCTAssertEqual(RelativeRoot.documents.createRelativePath(fromURL: url), "ROMs/com.provenance.snes/Game.sfc")
    }

    func testPartialPathUnderAppGroupDocuments() {
        XCTAssertEqual(partialPath("/private/var/mobile/Containers/Shared/AppGroup/0A1B/Documents/ROMs/com.provenance.snes/Game.sfc"),
                       "ROMs/com.provenance.snes/Game.sfc")
    }

    func testPartialPathUnderICloudDriveDocuments() {
        XCTAssertEqual(partialPath("/private/var/mobile/Library/Mobile Documents/iCloud~org~provenance-emu~provenance/Documents/Save States/Game/s.svs"),
                       "Save States/Game/s.svs")
    }

    func testPartialPathUnderTVOSCaches() {
        XCTAssertEqual(partialPath("/private/var/mobile/Containers/Data/Application/0A1B/Library/Caches/ROMs/com.provenance.snes/Game.sfc"),
                       "ROMs/com.provenance.snes/Game.sfc")
    }
}
