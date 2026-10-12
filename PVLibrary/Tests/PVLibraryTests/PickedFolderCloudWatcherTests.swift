//
//  PickedFolderCloudWatcherTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVLibrary

final class PickedFolderCloudWatcherTests: XCTestCase {
    #if !os(tvOS)
    func testPredicateScopesToTheFolder() {
        let predicate = PickedFolderCloudWatcher.predicate(rootPath: "/x/Lib")
        XCTAssertTrue(predicate.evaluate(with: ["kMDItemPath": "/x/Lib/ROMs/a"]))
        XCTAssertFalse(predicate.evaluate(with: ["kMDItemPath": "/x/Other/ROMs/a"]))
        XCTAssertFalse(predicate.evaluate(with: ["kMDItemPath": "/x/Library/ROMs/a"]), "a sibling that shares the prefix is not inside the folder")
    }
    #endif

    func testOnlySharedFoldersAreDownloaded() {
        XCTAssertTrue(PickedFolderCloudWatcher.shouldDownload(relativePath: "ROMs/com.provenance.snes/Game.sfc"))
        XCTAssertTrue(PickedFolderCloudWatcher.shouldDownload(relativePath: "BIOS/x.bin"))
        XCTAssertFalse(PickedFolderCloudWatcher.shouldDownload(relativePath: "Save States/x/s.svs"))
        XCTAssertTrue(PickedFolderCloudWatcher.shouldDownload(relativePath: "Conflicts/ROMs/x"), "a remapped record can point at a copy filed under Conflicts/")
    }
}
