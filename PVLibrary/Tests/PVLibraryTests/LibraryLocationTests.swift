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
@testable import PVFileSystem

final class LibraryLocationTests: XCTestCase {

    // MARK: - Settings to location

    func testRawValuesArePinned() {
        // Stored in UserDefaults and in move-journal.json: renaming one breaks resume and downgrade.
        XCTAssertEqual(LibraryLocation.appStorage.rawValue, "appStorage")
        XCTAssertEqual(LibraryLocation.appGroup.rawValue, "appGroup")
        XCTAssertEqual(LibraryLocation.iCloudDrive.rawValue, "iCloudDrive")
        XCTAssertEqual(LibraryLocation.allCases.count, 3)
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

    func testAppFilesRootFollowsTheSameAxisAsTheLibraryRoot() {
        // documentsPath is fixed at launch from the same precedence LibraryLocation uses.
        #if os(tvOS)
        XCTAssertEqual(URL.documentsPath, URL.cachesPathLocal)
        #else
        let expected = LibraryLocation.usesAppGroupContainer ? (URL.documentsPathAppGroup ?? URL.documentsPathLocal) : URL.documentsPathLocal
        XCTAssertEqual(URL.documentsPath, expected)
        #endif
    }

    func testLibraryAccessorsUseTheCurrentRoot() {
        let root = LibraryLocation.current.rootURL
        XCTAssertEqual(URL.documentsiCloudOrLocalPath, root)
        XCTAssertEqual(Paths.romsPath, root.appendingPathComponent("ROMs", isDirectory: true))
        XCTAssertEqual(Paths.biosesPath, root.appendingPathComponent("BIOS", isDirectory: true))
        XCTAssertEqual(Paths.saveSavesPath, root.appendingPathComponent("Save States", isDirectory: true))
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
