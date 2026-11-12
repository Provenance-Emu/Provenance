//
//  PauseMenuTabsTests.swift
//  PVUI
//

import CoreGraphics
import Testing
@testable import PVUIBase

@Suite("PauseMenuTab")
struct PauseMenuTabTests {

    private let root: [(id: String, tileIDs: [String])] = [
        (id: "game", tileIDs: ["resume", "saveQuit", "quit", "fastForwardToggle", "reset"]),
        (id: "statesData", tileIDs: ["saveState", "loadState", "browseSaves", "autoSaveState"]),
        (id: "menu", tileIDs: ["menu_recording"]),
        (id: "settingsData", tileIDs: ["core", "appSettings"]),
        (id: "controlsData", tileIDs: ["controllerProfile"]),
        (id: "quickSettingsData", tileIDs: ["rewindToggle"]),
        (id: "displayData", tileIDs: ["filterCycle", "fpsCounterToggle"])
    ]

    @Test("The pages are always in the same order")
    func fixedOrder() {
        #expect(PauseMenuTab.allCases == [.game, .display, .controls, .settings])
    }

    @Test("The Game page keeps its sections in a fixed order whatever order they were built in")
    func gamePageOrder() {
        #expect(PauseMenuTab.game.tileIDs(inRootSections: root)
                == ["fastForwardToggle", "reset", "autoSaveState", "rewindToggle", "menu_recording"])
        #expect(PauseMenuTab.game.tileIDs(inRootSections: root.reversed())
                == ["fastForwardToggle", "reset", "autoSaveState", "rewindToggle", "menu_recording"])
    }

    @Test("Exit buttons and the save row are chrome, not cells of a page")
    func chromeIsLeftOut() {
        for tab in PauseMenuTab.allCases {
            #expect(Set(tab.tileIDs(inRootSections: root)).isDisjoint(with: PauseMenuTab.chromeTileIDs))
        }
    }

    @Test("Each section is on one page")
    func sectionsMapToPages() {
        #expect(PauseMenuTab.display.tileIDs(inRootSections: root) == ["filterCycle", "fpsCounterToggle"])
        #expect(PauseMenuTab.controls.tileIDs(inRootSections: root) == ["controllerProfile"])
        #expect(PauseMenuTab.settings.tileIDs(inRootSections: root) == ["core", "appSettings"])
    }

    @Test("A section no page claims shows on Game, after the known ones")
    func unknownSectionGoesToGame() {
        let withNew = root + [(id: "somethingNew", tileIDs: ["newThing"])]
        #expect(PauseMenuTab.game.tileIDs(inRootSections: withNew).last == "newThing")
        #expect(PauseMenuTab.tab(forSectionID: "somethingNew") == .game)
    }

    @Test("Every control of the first level is on exactly one page or in the chrome")
    func nothingIsLostOrDuplicated() {
        let onPages = PauseMenuTab.allCases.flatMap { $0.tileIDs(inRootSections: root) }
        let all = root.flatMap(\.tileIDs)
        #expect(onPages.count == Set(onPages).count)
        #expect(Set(onPages).union(PauseMenuTab.chromeTileIDs) == Set(all))
    }

    @Test("L1 and R1 wrap around the ends")
    func shoulderButtonsWrap() {
        #expect(PauseMenuTab.game.next(by: 1) == .display)
        #expect(PauseMenuTab.settings.next(by: 1) == .game)
        #expect(PauseMenuTab.game.next(by: -1) == .settings)
    }
}

@Suite("PauseMenuLayoutMode")
struct PauseMenuLayoutModeTests {

    @Test("A phone held upright gets the bottom sheet")
    func phonePortrait() {
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 393, height: 759)) == .sheet)
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 440, height: 870)) == .sheet)
    }

    @Test("A phone on its side gets the rail")
    func phoneLandscape() {
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 759, height: 372)) == .rail)
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 932, height: 409)) == .rail)
    }

    @Test("iPad and Mac windows get the centred panel")
    func regular() {
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 1180, height: 820)) == .panel)
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 820, height: 1180)) == .panel)
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 600, height: 700)) == .panel)
    }

    @Test("An iPad in a narrow split or slide-over column is laid out like a phone")
    func narrowColumn() {
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 375, height: 1000)) == .sheet)
    }

    @Test("tvOS is always the centred panel")
    func television() {
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 1920, height: 1080), isTV: true) == .panel)
        #expect(PauseMenuLayoutMode.resolve(size: CGSize(width: 300, height: 300), isTV: true) == .panel)
    }
}

@Suite("PauseMenuCursorGrid")
struct PauseMenuCursorGridTests {

    /// Exit buttons over the save row over a four-column page with a short last row.
    private let grid = PauseMenuCursorGrid(
        above: [["quit", "saveQuit", "resume"], ["save", "load", "all"]],
        cells: [["a", "b", "c", "d"], ["e", "f", "g", "h"], ["i", "j"]],
        columns: 4)

    @Test("A cursor that is nowhere starts on the first cell of the page, not on the chrome above it")
    func startsHome() {
        #expect(grid.move(from: nil, .down) == "a")
        #expect(grid.move(from: "gone", .left) == "a")
    }

    @Test("Left and right stay in the row and stop at its ends")
    func horizontal() {
        #expect(grid.move(from: "b", .right) == "c")
        #expect(grid.move(from: "d", .right) == "d")
        #expect(grid.move(from: "a", .left) == "a")
        #expect(grid.move(from: "resume", .left) == "saveQuit")
    }

    @Test("Up and down keep the column between rows of the same length")
    func verticalSameLength() {
        #expect(grid.move(from: "c", .down) == "g")
        #expect(grid.move(from: "g", .up) == "c")
    }

    @Test("A short last row sits under the first columns: down clamps to it, up keeps the column")
    func verticalToShorterRow() {
        #expect(grid.move(from: "e", .down) == "i")
        #expect(grid.move(from: "f", .down) == "j")
        #expect(grid.move(from: "h", .down) == "j")
        #expect(grid.move(from: "j", .up) == "f")
    }

    @Test("The chrome rows are reachable from the grid and back")
    func reachesChrome() {
        #expect(grid.move(from: "a", .up) == "save")
        #expect(grid.move(from: "d", .up) == "all")
        #expect(grid.move(from: "all", .up) == "resume")
        #expect(grid.move(from: "quit", .down) == "save")
        #expect(grid.move(from: "load", .down) == "c")
    }

    @Test("With the exit buttons under the grid, as on the phone sheet, down from the last row reaches them")
    func chromeBelow() {
        let sheet = PauseMenuCursorGrid(above: [["save", "load", "all"]], cells: [["a", "b", "c", "d"], ["e"]],
                                        below: [["quit", "resume"]], columns: 4)
        #expect(sheet.home == "a")
        #expect(sheet.move(from: "e", .down) == "quit")
        #expect(sheet.move(from: "resume", .up) == "e")
        #expect(sheet.move(from: "resume", .down) == "resume")
    }

    @Test("The top and bottom rows are the edges")
    func verticalEdges() {
        #expect(grid.move(from: "quit", .up) == "quit")
        #expect(grid.move(from: "i", .down) == "i")
    }

    @Test("Every control can be reached from home")
    func everythingReachable() {
        var seen: Set<String> = ["a"]
        var frontier = ["a"]
        while let id = frontier.popLast() {
            for direction in [PauseMenuCursorGrid.Direction.up, .down, .left, .right] {
                if let next = grid.move(from: id, direction), seen.insert(next).inserted { frontier.append(next) }
            }
        }
        #expect(seen == Set(grid.ids))
    }

    @Test("Empty rows are dropped, and an empty grid has nowhere to go")
    func emptyRows() {
        let sparse = PauseMenuCursorGrid(above: [[]], cells: [[], ["x", "y"]], below: [[]], columns: 4)
        #expect(sparse.ids == ["x", "y"])
        #expect(sparse.home == "x")
        #expect(PauseMenuCursorGrid(cells: [], columns: 4).move(from: nil, .down) == nil)
    }

    @Test("Cells are split into rows of the column count")
    func chunking() {
        #expect(PauseMenuCursorGrid.chunk(["a", "b", "c", "d", "e"], columns: 2) == [["a", "b"], ["c", "d"], ["e"]])
        #expect(PauseMenuCursorGrid.chunk([], columns: 4).isEmpty)
    }
}
