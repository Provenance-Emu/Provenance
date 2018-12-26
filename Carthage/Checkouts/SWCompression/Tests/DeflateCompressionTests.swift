// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class DeflateCompressionTests: XCTestCase {

    func answerTest(_ testName: String) throws {
        let answerData = try Constants.data(forAnswer: testName)

        let compressedData = Deflate.compress(data: answerData)

        if testName != "test5" { // Compression ratio is always bad for empty file.
            let compressionRatio = Double(answerData.count) / Double(compressedData.count)
            print("Deflate.\(testName).compressionRatio = \(compressionRatio)")
        } else {
            print("No compression ratio for test5.")
        }

        let reUncompData = try Deflate.decompress(data: compressedData)
        XCTAssertEqual(answerData, reUncompData)
    }

    func testDeflate1() throws {
        try self.answerTest("test1")
    }

    func testDeflate2() throws {
        try self.answerTest("test2")
    }

    func testDeflate3() throws {
        try self.answerTest("test3")
    }

    func testDeflate4() throws {
        try self.answerTest("test4")
    }

    func testDeflate5() throws {
        try self.answerTest("test5")
    }

    func testDeflate6() throws {
        try self.answerTest("test6")
    }

    func testDeflate7() throws {
        try self.answerTest("test7")
    }

    func testDeflate8() throws {
        try self.answerTest("test8")
    }

    func testDeflate9() throws {
        try self.answerTest("test9")
    }

}
