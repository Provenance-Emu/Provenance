//
//  LibraryLocationTests.swift
//  PVLibraryTests
//
//  LibraryLocation is the one place that decides where library files live. Phase 1 of the
//  storage-locations spec only routes existing paths through it, so these tests pin today's
//  behaviour: the settings-to-location table, the root it resolves to, and the partial
//  paths stored for files under each kind of root.
//

import XCTest
@testable import PVFileSystem

final class LibraryLocationTests: XCTestCase {

    // MARK: - Settings to location

    func testICloudDriveNeedsSyncAndDriveMode() {
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: false, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: true, iCloudSync: true, iCloudDriveMode: true), .iCloudDrive)
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: false, iCloudSync: false, iCloudDriveMode: true), .appStorage)
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: false, iCloudSync: true, iCloudDriveMode: false), .appStorage)
    }

    func testAppGroupWithoutICloudDrive() {
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: true, iCloudSync: false, iCloudDriveMode: false), .appGroup)
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: true, iCloudSync: true, iCloudDriveMode: false), .appGroup)
    }

    func testDefaultIsAppStorage() {
        XCTAssertEqual(LibraryLocation.resolve(useAppGroups: false, iCloudSync: false, iCloudDriveMode: false), .appStorage)
    }

    // MARK: - Root

    func testICloudDriveRootFallsBackToDocumentsWithoutAContainer() {
        let documents = URL(fileURLWithPath: "/docs", isDirectory: true)
        let iCloud = URL(fileURLWithPath: "/icloud/Documents", isDirectory: true)

        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(documents: documents, iCloudDocuments: iCloud), iCloud)
        XCTAssertEqual(LibraryLocation.iCloudDrive.rootURL(documents: documents, iCloudDocuments: nil), documents)
        XCTAssertEqual(LibraryLocation.appStorage.rootURL(documents: documents, iCloudDocuments: iCloud), documents)
        XCTAssertEqual(LibraryLocation.appGroup.rootURL(documents: documents, iCloudDocuments: iCloud), documents)
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
