//
//  Provenance_Mini_Watch_AppUITestsLaunchTests.swift
//  Provenance Mini Watch AppUITests
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import XCTest

final class Provenance_Mini_Watch_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
