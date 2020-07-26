//
//  PVSettingsTests.swift
//  PVSupportTests
//
//  Created by Joseph Mattiello on 11/22/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

@testable import PVSupport
import XCTest

class PVSettingsTests: XCTestCase {
    var settings: PVSettingsModel!

    override func setUp() {
        settings = PVSettingsModel()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSettings() {
        XCTAssertTrue(settings.askToAutoLoad)
        XCTAssertTrue(settings.buttonTints)
        XCTAssertEqual(settings.timedAutoSaveInterval, minutes(10))

        settings.askToAutoLoad = false

        XCTAssertFalse(settings.askToAutoLoad)

        settings.toggle(\PVSettingsModel.askToAutoLoad)
        XCTAssertTrue(settings.askToAutoLoad)
        let icValue = UserDefaults.standard.bool(forKey: "askToAutoLoad")
        XCTAssertTrue(icValue)

        XCTAssertFalse(settings.debugOptions.iCloudSync)
        settings.debugOptions.iCloudSync = true
        XCTAssertTrue(settings.debugOptions.iCloudSync)
        let icValue2 = UserDefaults.standard.bool(forKey: "debugOptions.iCloudSync")
        XCTAssertTrue(icValue2)

        settings.toggle(\PVSettingsModel.debugOptions.iCloudSync)
        XCTAssertFalse(settings.debugOptions.iCloudSync)

        XCTAssertFalse(settings.debugOptions.multiThreadedGL)
        settings.debugOptions.multiThreadedGL = true
        XCTAssertTrue(settings.debugOptions.multiThreadedGL)
    }
}
