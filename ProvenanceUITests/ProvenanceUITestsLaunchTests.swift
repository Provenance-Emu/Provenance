//
//  ProvenanceUITestsLaunchTests.swift
//  ProvenanceUITests
//
//  Captures a launch-screen attachment per device/configuration so reviewers
//  can spot regressions in the Splash → Home transition.
//

import XCTest

final class ProvenanceUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
