import SwiftUI
import XCTest
@testable import PVUIBase

/// Controller navigation of the Network Play screens: the cursor math they share with the
/// tvOS-style layout, what one command does to a screen, and which screen owns the pad.
@MainActor
final class NetplayControllerNavigationTests: XCTestCase {
    private final class Box<Value> {
        var value: Value
        init(_ value: Value) { self.value = value }
        var binding: Binding<Value> { Binding(get: { self.value }, set: { self.value = $0 }) }
    }

    /// A header row of two chips, a two-by-two grid with one item on its last row, and a button.
    private var hub: ControllerCursorLayout {
        ControllerCursorLayout(rows: [
            .init(id: "header", items: ["tab.games", "settings"], isHeader: true)
        ] + NetplayHubCursor.gridRows(["a", "b", "c"], columns: 2) + [
            .init(id: "more", items: ["showMore"])
        ])
    }

    // MARK: Commands

    func testBackAlwaysLeavesTheScreen() {
        XCTAssertEqual(NetplayControllerAction.resolve(.back, layout: hub, cursor: nil), .back)
        XCTAssertEqual(NetplayControllerAction.resolve(.back, layout: .empty, cursor: "x"), .back)
    }

    func testFirstAShowsTheCursorOnTheFirstGameInsteadOfActivating() {
        XCTAssertEqual(NetplayControllerAction.resolve(.activate, layout: hub, cursor: nil), .moveCursor("game.a"))
        XCTAssertEqual(NetplayControllerAction.resolve(.activate, layout: hub, cursor: "gone"), .moveCursor("game.a"))
    }

    /// A pad connected after the screen opened: its first press lands on the first game,
    /// not on the header row above it.
    func testFirstDirectionShowsTheCursorOnTheFirstGame() {
        XCTAssertEqual(NetplayControllerAction.resolve(.down, layout: hub, cursor: nil), .moveCursor("game.a"))
        XCTAssertEqual(NetplayControllerAction.resolve(.up, layout: hub, cursor: "gone"), .moveCursor("game.a"))
    }

    func testAActivatesTheItemUnderTheCursor() {
        XCTAssertEqual(NetplayControllerAction.resolve(.activate, layout: hub, cursor: "settings"), .activate("settings"))
    }

    func testDirectionsMoveThroughHeaderGridAndButton() {
        XCTAssertEqual(NetplayControllerAction.resolve(.up, layout: hub, cursor: "game.b"), .moveCursor("settings"))
        XCTAssertEqual(NetplayControllerAction.resolve(.down, layout: hub, cursor: "game.b"), .moveCursor("game.c"))
        XCTAssertEqual(NetplayControllerAction.resolve(.right, layout: hub, cursor: "game.a"), .moveCursor("game.b"))
        XCTAssertEqual(NetplayControllerAction.resolve(.down, layout: hub, cursor: "game.c"), .moveCursor("showMore"))
    }

    func testEdgesDoNothing() {
        XCTAssertEqual(NetplayControllerAction.resolve(.left, layout: hub, cursor: "game.a"), .none)
        XCTAssertEqual(NetplayControllerAction.resolve(.right, layout: hub, cursor: "game.b"), .none)
        XCTAssertEqual(NetplayControllerAction.resolve(.down, layout: hub, cursor: "showMore"), .none)
        XCTAssertEqual(NetplayControllerAction.resolve(.up, layout: hub, cursor: "tab.games"), .none)
    }

    func testPauseMenuOnlyButtonsDoNothing() {
        for command in [PauseMenuNavigationCommand.previousTab, .nextTab, .quickSave, .quickLoad] {
            XCTAssertEqual(NetplayControllerAction.resolve(command, layout: hub, cursor: "game.a"), .none)
            XCTAssertEqual(NetplayControllerAction.resolve(command, layout: hub, cursor: nil), .none)
        }
    }

    func testAnEmptyScreenOnlyGoesBack() {
        XCTAssertEqual(NetplayControllerAction.resolve(.activate, layout: .empty, cursor: nil), .none)
        XCTAssertEqual(NetplayControllerAction.resolve(.down, layout: .empty, cursor: nil), .none)
    }

    // MARK: Rows

    func testRowsBecomeALayoutAndFindTheirTargets() {
        var ran: [String] = []
        let rows = [
            NetplayCursorRow(id: "choices", isHeader: true, targets: [
                NetplayCursorTarget(id: "one") { ran.append("one") },
                NetplayCursorTarget(id: "two") { ran.append("two") }
            ]),
            .single(NetplayCursorTarget(id: "start", isEnabled: false) { ran.append("start") })
        ]
        XCTAssertEqual(rows.cursorLayout.rows.map(\.items), [["one", "two"], ["start"]])
        XCTAssertEqual(rows.cursorLayout.defaultItem, "start")
        rows.target("two")?.action()
        XCTAssertEqual(ran, ["two"])
        XCTAssertEqual(rows.target("start")?.isEnabled, false)
        XCTAssertNil(rows.target("missing"))
    }

    func testGameGridRowsFollowTheColumnCount() {
        let rows = NetplayHubCursor.gridRows(["a", "b", "c", "d", "e"], columns: 3)
        XCTAssertEqual(rows.map(\.items), [["game.a", "game.b", "game.c"], ["game.d", "game.e"]])
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    func testStepperRowClampsAndDisablesAtTheEnds() {
        let value = Box(2)
        let row = NetplayStepperView.cursorRow("players", value: value.binding, in: 2...4)
        XCTAssertEqual(row.targets.map(\.id), ["players.minus", "players.plus"])
        XCTAssertEqual(row.targets.map(\.isEnabled), [false, true])
        row.targets[1].action()
        row.targets[1].action()
        row.targets[1].action()
        XCTAssertEqual(value.value, 4)
        row.targets[0].action()
        XCTAssertEqual(value.value, 3)
    }

    func testChoiceRowSelectsByPosition() {
        let style = Box("any")
        let row = NetplayChoiceRow<String>.cursorRow("style", choices: ["any", "shared", "linked"], selection: style.binding)
        XCTAssertTrue(row.isHeader)
        XCTAssertEqual(row.targets.map(\.id), ["style.0", "style.1", "style.2"])
        row.targets[2].action()
        XCTAssertEqual(style.value, "linked")
    }

    // MARK: Screen stack

    func testOnlyTheTopScreenOwnsThePad() {
        let hubScreen = UUID()
        let detail = UUID()
        var stack = NetplayScreenStack()
        stack.push(hubScreen)
        XCTAssertTrue(stack.isTop(hubScreen))
        stack.push(detail)
        XCTAssertFalse(stack.isTop(hubScreen))
        XCTAssertTrue(stack.isTop(detail))
        stack.remove(detail)
        XCTAssertTrue(stack.isTop(hubScreen))
        stack.remove(hubScreen)
        XCTAssertTrue(stack.isEmpty)
    }

    /// A sheet's disappearance can arrive after the next sheet appeared: removing it must not
    /// take the top away from the newer one.
    func testLateRemovalKeepsTheNewerScreenOnTop() {
        let hubScreen = UUID()
        let old = UUID()
        let new = UUID()
        var stack = NetplayScreenStack()
        stack.push(hubScreen)
        stack.push(old)
        stack.push(new)
        stack.remove(old)
        XCTAssertTrue(stack.isTop(new))
        stack.push(hubScreen)
        XCTAssertTrue(stack.isTop(hubScreen))
        XCTAssertEqual(stack.screens.count, 2)
    }
}
