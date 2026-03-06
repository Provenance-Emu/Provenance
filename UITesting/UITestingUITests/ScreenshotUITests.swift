//
//  ScreenshotUITests.swift
//  UITestingUITests
//
//  Captures App Store screenshots by navigating to key screens via
//  provenance:// deep links and the ScreenNavigator system.
//
//  Run via:
//    fastlane screenshots
//  or:
//    xcodebuild test -workspace Provenance.xcworkspace \
//      -scheme UITesting -destination "platform=iOS Simulator,name=iPhone 16 Pro"
//

import XCTest

final class ScreenshotUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Enable screenshot mode to skip core loading / bootup sequence overhead
        app.launchArguments += ["-SCREENSHOT_MODE", "1"]
        app.launch()
        // Allow splash/bootup animation to settle
        sleep(3)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Library

    @MainActor
    func testScreenshot_Library() throws {
        navigateTo(screen: "library")
        takeScreenshot(named: "01_Library")
    }

    // MARK: - Settings

    @MainActor
    func testScreenshot_Settings() throws {
        navigateTo(screen: "settings")
        takeScreenshot(named: "02_Settings")
    }

    @MainActor
    func testScreenshot_Settings_Video() throws {
        navigateTo(screen: "settings/video")
        takeScreenshot(named: "03_Settings_Video")
    }

    @MainActor
    func testScreenshot_Settings_Controller() throws {
        navigateTo(screen: "settings/controller")
        takeScreenshot(named: "04_Settings_Controller")
    }

    // MARK: - System Browser

    @MainActor
    func testScreenshot_SystemBrowser_NES() throws {
        navigateTo(screen: "system/com.provenance.nes")
        takeScreenshot(named: "05_SystemBrowser_NES")
    }

    @MainActor
    func testScreenshot_SystemBrowser_SNES() throws {
        navigateTo(screen: "system/com.provenance.snes")
        takeScreenshot(named: "06_SystemBrowser_SNES")
    }

    // MARK: - Helpers

    /// Open a provenance://screen/<path> deep link and wait for the UI to settle.
    private func navigateTo(screen path: String) {
        let urlString = "provenance://screen/\(path)"
        guard let url = URL(string: urlString) else {
            XCTFail("Invalid URL string: \(urlString)")
            return
        }
        app.open(url)
        sleep(1)
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

// MARK: - XCUIApplication convenience

private extension XCUIApplication {
    func open(_ url: URL) {
#if os(tvOS)
        // tvOS does not have Safari. Deep links must be triggered by re-launching
        // the app with the URL as a launch argument, or handled another way.
        // For now, activate the app so screenshots still run against the default state.
        self.activate()
        sleep(1)
#else
        // Use Safari as a proxy to open the URL scheme, then return to the app.
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        safari.launch()
        let addressBar = safari.textFields["Address"]
        if addressBar.waitForExistence(timeout: 5) {
            addressBar.tap()
            addressBar.clearAndEnterText(text: url.absoluteString)
            safari.keyboards.buttons["Go"].tap()
            // Allow the deep link to resolve and the app to reopen
            sleep(2)
        }
        // Return to the test app
        self.activate()
        sleep(1)
#endif
    }
}

private extension XCUIElement {
    func clearAndEnterText(text: String) {
        guard let stringValue = self.value as? String else {
            typeText(text)
            return
        }
        let deleteCount = stringValue.count
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount)
        typeText(deleteString)
        typeText(text)
    }
}
