//
//  PickedLibraryFolderTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class PickedLibraryFolderTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private let key = "libraryPickedFolder"

    override func setUpWithError() throws {
        suite = "PickedLibraryFolderTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testRoundTripKeepsEveryField() throws {
        let store = PickedLibraryFolderStore(defaults: defaults, key: key)
        let picked = Date(timeIntervalSinceReferenceDate: 1234.5678)
        let folder = PickedLibraryFolder(bookmark: Data([1, 2, 3]), displayName: "Retro", includesSaves: true, pickedAt: picked)
        try store.save(folder)
        XCTAssertEqual(store.load(), folder)
        XCTAssertEqual(store.load()?.version, PickedLibraryFolder.currentVersion)
    }

    func testEmptyStoreLoadsNil() {
        XCTAssertNil(PickedLibraryFolderStore(defaults: defaults, key: key).load())
    }

    func testClearRemovesTheValue() throws {
        let store = PickedLibraryFolderStore(defaults: defaults, key: key)
        try store.save(PickedLibraryFolder(bookmark: Data(), displayName: "x", includesSaves: false))
        store.clear()
        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: key))
    }

    func testUnreadableValueLoadsNil() {
        defaults.set(Data("{ nope".utf8), forKey: key)
        XCTAssertNil(PickedLibraryFolderStore(defaults: defaults, key: key).load())
    }
}
