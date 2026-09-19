//
//  ScreenshotUITests.swift
//  UITestingUITests
//
//  Captures App Store screenshots by launching the UITesting app in
//  `-SCREENSHOT_MODE` and pointing it at a screen via a
//  `-deepLink provenance://screen/<path>` launch argument. The app replays the
//  deep link through NavigationRouter / ScreenNavigator once bootup completes,
//  and PVRootViewController performs the navigation.
//
//  Launching per screen (instead of opening the URL from Safari) works on tvOS,
//  where there is no browser, and never depends on the Safari UI.
//
//  Run via:
//    fastlane screenshots
//  or:
//    xcodebuild test -workspace Provenance.xcworkspace \
//      -scheme Provenance-Screenshots -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
//

import XCTest

final class ScreenshotUITests: XCTestCase {

    var app: XCUIApplication!

    /// How long to wait for the app to boot (first launch scans systems and builds the mock library).
    private let bootTimeout: TimeInterval = 180
    /// Settle time after navigation so transitions and artwork finish rendering.
    private let settleSeconds: UInt32 = 3

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Library

    @MainActor
    func testScreenshot_Library() throws {
        launch(screen: "library")
        takeScreenshot(named: "01_Library")
    }

    // MARK: - Settings

    @MainActor
    func testScreenshot_Settings() throws {
        launch(screen: "settings")
        takeScreenshot(named: "02_Settings")
    }

    @MainActor
    func testScreenshot_Settings_Video() throws {
        launch(screen: "settings/video")
        takeScreenshot(named: "03_Settings_Video")
    }

    @MainActor
    func testScreenshot_Settings_Controller() throws {
        launch(screen: "settings/controller")
        takeScreenshot(named: "04_Settings_Controller")
    }

    // MARK: - System Browser

    @MainActor
    func testScreenshot_SystemBrowser_NES() throws {
        launch(screen: "system/com.provenance.nes")
        takeScreenshot(named: "05_SystemBrowser_NES")
    }

    @MainActor
    func testScreenshot_SystemBrowser_SNES() throws {
        launch(screen: "system/com.provenance.snes")
        takeScreenshot(named: "06_SystemBrowser_SNES")
    }

    // MARK: - Helpers

    /// Launch the app in screenshot mode targeting `provenance://screen/<path>`,
    /// then wait until bootup has finished and the main UI is on screen.
    private func launch(screen path: String) {
        let urlString = "provenance://screen/\(path)"
        app.launchArguments = [
            "-SCREENSHOT_MODE", "1",
            "-useMockLibrary",
            "-deepLink", urlString,
        ]
        app.launch()

        let mainContent = app.otherElements["screenshot.mainContent"]
        let bootup = app.otherElements["screenshot.bootup"]
        let deadline = Date().addingTimeInterval(bootTimeout)
        var ready = false
        while Date() < deadline {
            let bootScreenGone = !bootup.exists && !app.staticTexts["PROVENANCE"].exists
            if mainContent.exists || (app.state == .runningForeground && bootScreenGone) {
                ready = true
                break
            }
            sleep(1)
        }
        XCTAssertTrue(ready, "App did not finish booting within \(Int(bootTimeout))s for \(urlString)")

        // Allow the deep-link navigation and transitions to settle.
        sleep(settleSeconds)
    }

    /// Save a screenshot as an XCTAttachment with a given name for fastlane snapshot.
    private func takeScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
