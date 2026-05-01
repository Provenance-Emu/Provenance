//
//  ProvenanceUITests.swift
//  ProvenanceUITests
//
//  Smoke-level XCUITests for the Provenance iOS host. Keep these fast:
//  the goal is to catch obvious launch / first-screen regressions before
//  TestFlight, not to drive deep flows.
//

import XCTest

final class ProvenanceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // The app reaches a stable foregrounded state. We don't assert on
        // specific labels here because the home screen contents depend on
        // imported games / async cloud sync — keep the smoke test resilient.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "App did not reach foregrounded state within 30s")
    }

    @MainActor
    func testHomeScreenScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "App did not reach foregrounded state within 30s")

        // Give SwiftUI a beat to settle the initial layout before capturing.
        Thread.sleep(forTimeInterval: 1.0)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "home-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
