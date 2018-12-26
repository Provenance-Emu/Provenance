// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation
import XCTest
@testable import SWCompression

class Sha256Tests: XCTestCase {

    func test1() {
        let message = ""
        let answer = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let hash = Sha256.hash(data: message.data(using: .utf8)!)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test2() {
        let message = "a"
        let answer = "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test3() {
        let message = "abc"
        let answer = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test4() {
        let message = "message digest"
        let answer = "f7846f55cf23e14eebeab5b4e1550cad5b509e3348fbc4efa3a1413d393cb650"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test5() {
        let message = "abcdefghijklmnopqrstuvwxyz"
        let answer = "71c480df93d6ae2f1efad1447c66c9525e316218cf51fc8d9ed832f2daf18b73"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test6() {
        let message = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let answer = "db4bfcbd4da0cd85a60c3c37d3fbd8805c77f15fc6b1fdfe614ee0a7c8fdb4c0"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

    func test7() {
        let message = "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
        let answer = "f371bc4a311f2b009eef952dd83ca80e2b60026c8e935592d0f9c308453c813e"
        let data = message.data(using: .utf8)!
        let hash = Sha256.hash(data: data)
        XCTAssertEqual(hash.map { String(format: "%02x", $0) }.joined(), answer)
    }

}
