// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class ZlibTests: XCTestCase {

    private static let testType: String = "zlib"

    func testZlib() throws {
        let testName = "test"

        let testData = try Constants.data(forTest: testName, withType: ZlibTests.testType)
        let testZlibHeader = try ZlibHeader(archive: testData)

        XCTAssertEqual(testZlibHeader.compressionMethod, .deflate)
        XCTAssertEqual(testZlibHeader.compressionLevel, .defaultAlgorithm)
        XCTAssertEqual(testZlibHeader.windowSize, 32768)
    }

    func testZlibFull() throws {
        let testData = try Constants.data(forTest: "random_file", withType: ZlibTests.testType)
        let decompressedData = try ZlibArchive.unarchive(archive: testData)

        let answerData = try Constants.data(forAnswer: "test9")
        XCTAssertEqual(decompressedData, answerData)
    }

    func testCreateZlib() throws {
        let testData = try Constants.data(forAnswer: "test9")
        let archiveData = ZlibArchive.archive(data: testData)
        let reextractedData = try ZlibArchive.unarchive(archive: archiveData)

        XCTAssertEqual(testData, reextractedData)
    }

}
