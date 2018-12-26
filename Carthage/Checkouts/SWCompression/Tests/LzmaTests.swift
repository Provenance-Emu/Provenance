// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class LzmaTests: XCTestCase {

    private static let testType: String = "lzma"

    func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: LzmaTests.testType)
        let decompressedData = try LZMA.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: "test8")
        XCTAssertEqual(decompressedData, answerData)
    }

    func testLzma8() throws {
        try self.perform(test: "test8")
    }

    func testLzma9() throws {
        try self.perform(test: "test9")
    }

    func testLzma10() throws {
        try self.perform(test: "test10")
    }

    func testLzma11() throws {
        try self.perform(test: "test11")
    }

}
