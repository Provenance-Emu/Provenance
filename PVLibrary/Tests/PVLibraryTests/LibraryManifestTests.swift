//
//  LibraryManifestTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryManifestTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryManifestTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(root)
    }

    func testFileNameIsTheContract() {
        XCTAssertEqual(LibraryManifest.fileName, ".provenance-library.json")
        XCTAssertEqual(LibraryManifest.currentVersion, 1)
    }

    func testWriteThenRead() throws {
        XCTAssertFalse(LibraryManifest.exists(in: root))
        XCTAssertTrue(try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.provenance-emu.provenance"))
        XCTAssertTrue(LibraryManifest.exists(in: root))
        let manifest = try LibraryManifest.read(from: root)
        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.createdBy, "org.provenance-emu.provenance")
        XCTAssertNotNil(manifest.createdAt)
    }

    func testJSONShapeIsTheContract() throws {
        try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.test")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: LibraryManifest.url(in: root))) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["createdBy"] as? String, "org.test")
        XCTAssertNotNil(json["createdAt"] as? String, "ISO 8601 string")
    }

    func testNeverOverwritesAnotherAppsManifest() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, #"{"version":1,"createdBy":"com.ifly","extra":true}"#)
        XCTAssertFalse(try LibraryManifest.writeIfAbsent(in: root, createdBy: "org.test"))
        let manifest = try LibraryManifest.read(from: root)
        XCTAssertEqual(manifest.createdBy, "com.ifly")
        XCTAssertNil(manifest.createdAt, "a missing createdAt is tolerated")
    }

    func testNewerVersionStillReads() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, #"{"version":7,"createdBy":"com.icube","createdAt":"2026-10-12T00:00:00Z"}"#)
        XCTAssertEqual(try LibraryManifest.read(from: root).version, 7)
    }

    func testUnreadableManifestThrows() throws {
        try LibraryMoveTestSupport.write(root, LibraryManifest.fileName, "{ not json")
        XCTAssertThrowsError(try LibraryManifest.read(from: root))
    }
}
