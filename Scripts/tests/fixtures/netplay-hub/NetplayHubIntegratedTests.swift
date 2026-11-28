import XCTest

final class NetplayHubIntegratedTests: XCTestCase {
    private var fixtureTitle: String { ProcessInfo.processInfo.environment["NETPLAY_GAME_TITLE"] ?? "Theme Preview" }

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testRealLibraryHub() throws {
        let bundle = ProcessInfo.processInfo.environment["NETPLAY_APP_BUNDLE"] ?? "org.provenance-emu.provenance.dev.coreless"
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-netplayEnabled", "YES", "-iCloudSync", "NO"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 40))
        #if os(tvOS)
        let libraryGame = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureTitle)).firstMatch
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
        let settings = app.buttons["netplay.pane.settings"]
        let games = app.buttons["netplay.pane.games"]
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
        // Settings is a tab of the hub, not a screen over it.
        select(settings, in: app)
        XCTAssertTrue(app.staticTexts["Player Profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["netplay.hub.heading"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["netplay.showUnverified"].exists, "No setting edits which games are offered")
        save("Real hub - settings tab")
        select(games, in: app)
        // Every list is the same set of games; none is a recommendation.
        for title in ["All Games", "Recent", "Favorites"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "Missing list \(title)")
        }
        XCTAssertFalse(app.buttons["Suggested"].exists)
        XCTAssertFalse(app.buttons["Unverified"].exists)
        // The fixture app has no netplay core for the fixture game's system, which is the
        // only reason a game is left out.
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "netplay.game."))
        if !cards.firstMatch.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.descendants(matching: .any)["netplay.hub.empty"].exists)
        }
        #if !os(tvOS)
        select(app.buttons["netplay.pane.rooms"], in: app)
        XCTAssertTrue(app.staticTexts["Looking for rooms nearby"].waitForExistence(timeout: 5))
        select(games, in: app)
        #else
        XCTAssertTrue(app.staticTexts["Looking for rooms nearby"].exists)
        #endif
        save("Real hub - games list")
        print("NETPLAY HUB TREE\n" + app.debugDescription)
    }

    @MainActor func testGameContextMenuOpensDetailsOnce() throws {
        let bundle = ProcessInfo.processInfo.environment["NETPLAY_APP_BUNDLE"] ?? "org.provenance-emu.provenance.dev.coreless"
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-netplayEnabled", "YES", "-iCloudSync", "NO"]
        app.launch()
        let game = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fixtureTitle)).firstMatch
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
        // Details open for the exact ROM: hosting where a netplay core is installed, else the reason.
        let host = app.buttons["Host This Game"]
        let unavailable = app.descendants(matching: .any)["netplay.detail.unavailable"]
        XCTAssertTrue(host.waitForExistence(timeout: 15) || unavailable.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Review Multiplayer Details"].exists)
        save("Context menu opens exact ROM network play details")
        #if os(tvOS)
        XCUIRemote.shared.press(.menu)
        #else
        select(app.buttons["Back"].firstMatch, in: app)
        #endif
        XCTAssertTrue(app.staticTexts["netplay.hub.heading"].waitForExistence(timeout: 10))
        XCTAssertFalse(host.exists || unavailable.exists, "Back must not reopen details")
        #if os(tvOS)
        select(app.navigationBars["Network Play"].buttons["Done"], in: app)
        #else
        select(app.buttons["netplay.hub.done"], in: app)
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
