//
//  PVSettingsTests.swift
//  PVSupportTests
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import XCTest
@testable import PVSupport

class PVSettingsTests: XCTestCase {

    var settings : PVSettingsModel!

    override func setUp() {
        settings = PVSettingsModel()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSettings() {
        XCTAssertTrue(settings.askToAutoLoad)
        XCTAssertTrue(settings.buttonTints)
//        XCTAssertEqual(settings.timedAutoSaves, minutes(10))

        settings.askToAutoLoad = false

        XCTAssertFalse(settings.askToAutoLoad)
    }

}
