//
//  LibraryFolderBookmarkTests.swift
//  PVLibraryTests
//

import XCTest
@testable import PVFileSystem

final class LibraryFolderBookmarkTests: XCTestCase {
    private var base: URL!

    override func setUpWithError() throws {
        base = try LibraryMoveTestSupport.makeTempDirectory(named: "LibraryFolderBookmarkTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(base)
    }

    private func makeFolder(_ name: String) throws -> URL {
        let url = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRoundTripResolvesToTheSameFolder() throws {
        let folder = try makeFolder("Library")
        let data = try LibraryFolderBookmark.make(from: folder)
        let resolution = try LibraryFolderBookmark.resolve(data)
        XCTAssertEqual(resolution.url.resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
        XCTAssertFalse(resolution.isStale)
    }

    func testGarbageDataIsUnresolvable() {
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(Data("not a bookmark".utf8))) { error in
            guard case LibraryFolderError.bookmarkUnresolvable = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testDeletedFolderDoesNotResolve() throws {
        let folder = try makeFolder("Gone")
        let data = try LibraryFolderBookmark.make(from: folder)
        try FileManager.default.removeItem(at: folder)
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(data))
    }

    func testAFileIsNotAFolder() throws {
        let file = try LibraryMoveTestSupport.write(base, "file.txt", "x")
        let data = try LibraryFolderBookmark.make(from: file)
        XCTAssertThrowsError(try LibraryFolderBookmark.resolve(data)) { error in
            guard case LibraryFolderError.notADirectory = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testErrorsHaveDescriptions() {
        XCTAssertNotNil(LibraryFolderError.unreachable("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.isCurrentRoot("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.notWritable("/x").errorDescription)
        XCTAssertNotNil(LibraryFolderError.missingPickedFolder.errorDescription)
    }
}
