//
//  PVLoggingTests.swift
//  PVLoggingTests
//
//  Created by Joseph Mattiello on 1/4/23.
//  Copyright © 2023 Provenance Emu. All rights reserved.
//

@testable import PVLogging
import XCTest

class PVLoggingTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    func testLogEntry() {
        let newEntry = PVLogEntry(message: "Message")
        XCTAssertEqual(newEntry.text, "Message")
    }
}
