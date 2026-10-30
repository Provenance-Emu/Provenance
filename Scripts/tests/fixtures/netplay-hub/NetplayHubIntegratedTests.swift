import XCTest

final class NetplayHubIntegratedTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testRealLibraryHub() throws {
        let bundle = ProcessInfo.processInfo.environment["NETPLAY_APP_BUNDLE"] ?? "org.provenance-emu.provenance.dev.coreless"
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-netplayEnabled", "YES", "-iCloudSync", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 40))
        #if os(tvOS)
        let libraryGame = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Theme Preview")).firstMatch
        XCTAssertTrue(libraryGame.waitForExistence(timeout: 90))
        focus(libraryGame, in: app)
        for _ in 0..<4 {
            XCUIRemote.shared.press(.left)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        #else
        let menu = app.buttons["Open Library Menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 90))
        menu.tap()
        #endif
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Network Play")).firstMatch
        #if os(tvOS)
        for _ in 0..<20 {
            if entry.exists { break }
            XCUIRemote.shared.press(.down)
        }
        #endif
        #if os(tvOS)
        let railEntry = entry.exists ? entry : app.buttons["network"].firstMatch
        XCTAssertTrue(railEntry.waitForExistence(timeout: 20))
        select(railEntry, in: app)
        #else
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        select(entry, in: app)
        #endif
        XCTAssertTrue(app.staticTexts["Pick a game. Bring your friends."].waitForExistence(timeout: 20))
        #if os(tvOS)
        let settings = app.navigationBars["Network Play"].buttons["Settings"]
        #else
        let settings = app.buttons["netplay.hub.settings"]
        #endif
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        #if os(tvOS)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Opening the hub must not force a full-screen search keyboard")
        let search = app.textFields["netplay.hub.search"]
        XCTAssertTrue(search.exists)
        select(search, in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["netplay.hub.heading"].exists)
        #endif
        save("Real library netplay hub")
        select(settings, in: app)
        let toggle = app.descendants(matching: .any)["netplay.showUnverified"].firstMatch
        #if os(tvOS)
        for _ in 0..<12 {
            if toggle.exists { break }
            XCUIRemote.shared.press(.down)
        }
        #endif
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if ["0", "Off"].contains(toggle.value as? String ?? "") { select(toggle, in: app) }
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        select(app.buttons["Done"].firstMatch, in: app)
        #endif
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        #if !os(tvOS)
        select(app.descendants(matching: .any)["netplay.gameList"].firstMatch, in: app)
        #endif
        let unverified = app.buttons["Unverified"].firstMatch
        XCTAssertTrue(unverified.waitForExistence(timeout: 5))
        selectList(unverified, in: app)
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "netplay.game."))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "Expected the imported synthetic Theme Preview ROM in the separate Unverified list")
        save("Real hub - unverified library artwork")
        select(cards.firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["Multiplayer Unverified"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Host This Game"].exists)
        save("Real game details - unverified cannot host")
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        select(app.buttons["Back"].firstMatch, in: app)
        #endif
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Multiplayer Unverified"].exists, "Back must not reopen details")
        #if !os(tvOS)
        select(app.descendants(matching: .any)["netplay.gameList"].firstMatch, in: app)
        #endif
        selectList(app.buttons["Suggested"].firstMatch, in: app)
        XCTAssertFalse(cards.firstMatch.exists, "Unknown multiplayer must never appear in recommendations")
        XCTAssertTrue(app.staticTexts["No Compatible Games"].exists)
        #if !os(tvOS)
        select(app.buttons["Nearby Rooms"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["Looking for rooms nearby"].waitForExistence(timeout: 5))
        select(app.buttons["Your Games"].firstMatch, in: app)
        #else
        XCTAssertTrue(app.staticTexts["Looking for rooms nearby"].exists)
        #endif
        save("Real hub - recommendations exclude unknown game")
        print("NETPLAY HUB TREE\n" + app.debugDescription)
    }

    @MainActor func testGameContextMenuOpensDetailsOnce() throws {
        let bundle = ProcessInfo.processInfo.environment["NETPLAY_APP_BUNDLE"] ?? "org.provenance-emu.provenance.dev.coreless"
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-netplayEnabled", "YES", "-iCloudSync", "NO"]
        app.launch()
        let game = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Theme Preview")).firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 90))
        #if os(tvOS)
        focus(game, in: app)
        XCUIRemote.shared.press(.select, forDuration: 1.2)
        #else
        game.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3)).press(forDuration: 1.5)
        #endif
        let network = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Network Play")).firstMatch
        XCTAssertTrue(network.waitForExistence(timeout: 10))
        #if os(tvOS)
        // The native context-menu action is exposed as Other and starts focused.
        XCUIRemote.shared.press(.select)
        #else
        network.tap()
        #endif
        XCTAssertTrue(app.staticTexts["Multiplayer Unverified"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Host This Game"].exists)
        save("Context menu opens exact ROM multiplayer details")
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        select(app.buttons["Back"].firstMatch, in: app)
        #endif
        XCTAssertTrue(app.staticTexts["netplay.hub.heading"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Multiplayer Unverified"].exists)
        #if os(tvOS)
        select(app.navigationBars["Network Play"].buttons["Done"], in: app)
        #else
        select(app.buttons["netplay.hub.done"], in: app)
        #endif
    }

    @MainActor private func selectList(_ target: XCUIElement, in app: XCUIApplication) {
        #if os(tvOS)
        focus(target, in: app)
        // tvOS segmented pickers select on focus; pressing Select again can race
        // the focus-driven SwiftUI update and activate the preceding segment.
        let selected = NSPredicate(format: "selected == true")
        if !target.isSelected { XCUIRemote.shared.press(.select) }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: selected, object: target)], timeout: 3), .completed)
        #else
        select(target, in: app)
        #endif
    }

    #if os(tvOS)
    @MainActor private func focus(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<50 {
            if target.hasFocus { return }
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            if !focused.exists { XCUIRemote.shared.press(.down); continue }
            let from = focused.frame
            let to = target.frame
            if abs(to.midY - from.midY) > max(15, from.height / 2) {
                XCUIRemote.shared.press(to.midY > from.midY ? .down : .up)
            } else { XCUIRemote.shared.press(to.midX > from.midX ? .right : .left) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTFail("Could not focus \(target.label)")
    }
    #endif

    @MainActor private func select(_ target: XCUIElement, in app: XCUIApplication) {
        #if os(tvOS)
        for _ in 0..<50 {
            if target.hasFocus { XCUIRemote.shared.press(.select); return }
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            if !focused.exists { XCUIRemote.shared.press(.down); continue }
            let from = focused.frame
            let to = target.frame
            if abs(to.midY - from.midY) > max(15, from.height / 2) {
                XCUIRemote.shared.press(to.midY > from.midY ? .down : .up)
            } else { XCUIRemote.shared.press(to.midX > from.midX ? .right : .left) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTFail("Could not focus \(target.label)")
        #else
        if !target.isHittable { app.swipeUp() }
        target.tap()
        #endif
    }

    @MainActor private func save(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
