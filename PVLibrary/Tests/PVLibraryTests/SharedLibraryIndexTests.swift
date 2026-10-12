//
//  SharedLibraryIndexTests.swift
//  PVLibraryTests
//

import XCTest
import PVHashing
@testable import PVFileSystem

final class SharedLibraryIndexTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = try LibraryMoveTestSupport.makeTempDirectory(named: "SharedLibraryIndexTests")
    }

    override func tearDownWithError() throws {
        LibraryMoveTestSupport.removeTree(root)
    }

    private func index() throws -> SharedLibraryIndex {
        try SharedLibraryIndex(root: root, folders: ["ROMs", "BIOS"], fileManager: .default, md5Provider: FileManager.default)
    }

    func testMatchesBySizeThenMD5UnderAnotherName() throws {
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Game (USA).sfc", "same bytes")
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Other.sfc", "diff bytes")
        var index = try index()
        let md5 = try XCTUnwrap(FileManager.default.md5ForFile(at: root.appendingPathComponent("ROMs/com.provenance.snes/Game (USA).sfc"), fromOffset: 0))
        XCTAssertEqual(index.match(size: 10, md5: md5, excluding: "ROMs/com.provenance.snes/Game.sfc"), "ROMs/com.provenance.snes/Game (USA).sfc")
        XCTAssertNil(index.match(size: 10, md5: "0000", excluding: "ROMs/x"))
        XCTAssertNil(index.match(size: 3, md5: md5, excluding: "ROMs/x"))
    }

    func testTheSamePathIsNeverAMatch() throws {
        try LibraryMoveTestSupport.write(root, "ROMs/com.provenance.snes/Game.sfc", "same bytes")
        var index = try index()
        let md5 = try XCTUnwrap(FileManager.default.md5ForFile(at: root.appendingPathComponent("ROMs/com.provenance.snes/Game.sfc"), fromOffset: 0))
        XCTAssertNil(index.match(size: 10, md5: md5, excluding: "ROMs/com.provenance.snes/Game.sfc"))
    }

    func testOnlyTheListedFoldersAreIndexed() throws {
        try LibraryMoveTestSupport.write(root, "Save States/x/s.svs", "same bytes")
        try LibraryMoveTestSupport.write(root, "Conflicts/ROMs/x/y.sfc", "same bytes")
        var index = try index()
        XCTAssertNil(index.match(size: 10, md5: "any", excluding: ""))
    }

    func testMissingFoldersAreFine() throws {
        XCTAssertNoThrow(try index())
    }
}
