// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import XCTest
import SWCompression

class BZip2Tests: XCTestCase {

    private static let testType: String = "bz2"

    func perform(test testName: String) throws {
        let testData = try Constants.data(forTest: testName, withType: BZip2Tests.testType)
        let decompressedData = try BZip2.decompress(data: testData)

        let answerData = try Constants.data(forAnswer: testName)
        XCTAssertEqual(decompressedData, answerData)
    }

    func test1BZip2() throws {
        try self.perform(test: "test1")
    }

    func test2BZip2() throws {
        try self.perform(test: "test2")
    }

    func test3BZip2() throws {
        try self.perform(test: "test3")
    }

    func test4BZip2() throws {
        try self.perform(test: "test4")
    }

    func test5BZip2() throws {
        try self.perform(test: "test5")
    }

    func test6BZip2() throws {
        try self.perform(test: "test6")
    }

    func test7BZip2() throws {
        try self.perform(test: "test7")
    }

    func test8BZip2() throws {
        try self.perform(test: "test8")
    }

    func test9BZip2() throws {
        try self.perform(test: "test9")
    }

}
