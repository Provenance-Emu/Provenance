import XCTest
@testable import PVSwiftUI

final class TVMediaCursorLayoutTests: XCTestCase {
    private typealias Row = TVMediaCursorLayout.Row

    /// Two shelves of different lengths, like Home.
    private let shelves = TVMediaCursorLayout(rows: [
        Row(id: "favorites", items: ["f1", "f2", "f3", "f4"]),
        Row(id: "gba", items: ["g1", "g2"])
    ])

    // MARK: Direction mapping

    func testGamepadAxisValuesMapToDirections() {
        XCTAssertEqual(TVMediaCursorDirection(verticalValue: -1), .down)
        XCTAssertEqual(TVMediaCursorDirection(verticalValue: 1), .up)
        XCTAssertEqual(TVMediaCursorDirection(horizontalValue: 1), .right)
        XCTAssertEqual(TVMediaCursorDirection(horizontalValue: -1), .left)
        XCTAssertNil(TVMediaCursorDirection(verticalValue: 0))
        XCTAssertNil(TVMediaCursorDirection(horizontalValue: 0))
    }

    // MARK: Input ownership

    func testOverlayOwnsInputEvenWithTheSidebarOpen() {
        XCTAssertEqual(TVMediaInputOwner.resolve(isOverlayPresented: true, isSidebarExpanded: true), .overlay)
        XCTAssertEqual(TVMediaInputOwner.resolve(isOverlayPresented: true, isSidebarExpanded: false), .overlay)
    }

    func testSidebarOwnsInputOnlyWhileExpanded() {
        XCTAssertEqual(TVMediaInputOwner.resolve(isOverlayPresented: false, isSidebarExpanded: true), .sidebar)
        XCTAssertEqual(TVMediaInputOwner.resolve(isOverlayPresented: false, isSidebarExpanded: false), .content)
    }

    // MARK: First press

    func testFirstPressLandsOnTheFirstItemWhateverTheDirection() {
        for direction in [TVMediaCursorDirection.up, .down, .left, .right] {
            XCTAssertEqual(shelves.move(from: nil, direction), .moved(item: "f1", row: "favorites"))
        }
    }

    func testACursorThatLeftTheScreenRestartsAtTheFirstItem() {
        XCTAssertEqual(shelves.move(from: "deleted", .down), .moved(item: "f1", row: "favorites"))
        XCTAssertEqual(shelves.validCursor("deleted"), "f1")
        XCTAssertEqual(shelves.validCursor("g2"), "g2")
        XCTAssertEqual(shelves.validCursor(nil), "f1")
    }

    // MARK: Moves inside a row

    func testRightAndLeftStepThroughARow() {
        XCTAssertEqual(shelves.move(from: "f1", .right), .moved(item: "f2", row: "favorites"))
        XCTAssertEqual(shelves.move(from: "f2", .left), .moved(item: "f1", row: "favorites"))
    }

    func testLeftInTheFirstColumnIsTheSidebarEdge() {
        XCTAssertEqual(shelves.move(from: "f1", .left), .leftEdge)
        XCTAssertEqual(shelves.move(from: "g1", .left), .leftEdge)
    }

    func testRightAtTheEndOfARowIsBlocked() {
        XCTAssertEqual(shelves.move(from: "f4", .right), .blocked)
    }

    // MARK: Moves between rows

    func testDownKeepsTheColumnWhenTheNextRowIsLongEnough() {
        XCTAssertEqual(shelves.move(from: "f2", .down), .moved(item: "g2", row: "gba"))
        XCTAssertEqual(shelves.move(from: "g2", .up), .moved(item: "f2", row: "favorites"))
    }

    func testDownIntoAShorterRowTakesItsLastItem() {
        XCTAssertEqual(shelves.move(from: "f4", .down), .moved(item: "g2", row: "gba"))
    }

    func testUpFromTheFirstRowAndDownFromTheLastAreBlocked() {
        XCTAssertEqual(shelves.move(from: "f1", .up), .blocked)
        XCTAssertEqual(shelves.move(from: "g1", .down), .blocked)
    }

    // MARK: Grids

    func testGridChunksItemsIntoRows() {
        let grid = TVMediaCursorLayout(gridItems: ["a", "b", "c", "d", "e"], columns: 2)
        XCTAssertEqual(grid.rows.map(\.items), [["a", "b"], ["c", "d"], ["e"]])
        XCTAssertEqual(grid.move(from: "b", .down), .moved(item: "d", row: "row-1"))
        XCTAssertEqual(grid.move(from: "d", .down), .moved(item: "e", row: "row-2"))
        XCTAssertEqual(grid.move(from: "c", .left), .leftEdge)
    }

    func testGridWithANonPositiveColumnCountStillHasOneColumn() {
        let grid = TVMediaCursorLayout(gridItems: ["a", "b"], columns: 0)
        XCTAssertEqual(grid.rows.map(\.items), [["a"], ["b"]])
    }

    /// The Save States screen: the filter button sits above the grid and must be reachable.
    func testAHeaderRowAboveAGridIsReachable() {
        let header = TVMediaCursorLayout(rows: [Row(id: "header", items: ["filter"], isHeader: true)])
        let layout = header.appending(TVMediaCursorLayout(gridItems: ["s1", "s2", "s3"], columns: 3))
        XCTAssertEqual(layout.move(from: "s3", .up), .moved(item: "filter", row: "header"))
        XCTAssertEqual(layout.move(from: "filter", .down), .moved(item: "s1", row: "row-0"))
        XCTAssertEqual(layout.rowID(of: "filter"), "header")
    }

    func testTheCursorStartsBelowHeaderRows() {
        let header = TVMediaCursorLayout(rows: [Row(id: "header", items: ["filter"], isHeader: true)])
        XCTAssertEqual(header.defaultItem, "filter", "A header is the default while it is all there is")

        let layout = header.appending(TVMediaCursorLayout(gridItems: ["s1", "s2"], columns: 2))
        XCTAssertEqual(layout.defaultItem, "s1")
        XCTAssertEqual(layout.firstItem, "filter")
        XCTAssertEqual(layout.validCursor("gone"), "s1")
    }

    // MARK: Grid columns

    /// An iPad's system games grid: 1014 pt wide, items 260...300, 20 apart. SwiftUI draws three
    /// columns there; counting one made left and right do nothing.
    func testAdaptiveColumnCountMatchesWhatTheGridDraws() {
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 1014, minItemWidth: 260, spacing: 20), 3)
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 1100, minItemWidth: 260, spacing: 20), 4)
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 540, minItemWidth: 260, spacing: 20), 2)
    }

    func testAdaptiveColumnCountIsAtLeastOne() {
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 100, minItemWidth: 260, spacing: 20), 1)
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 0, minItemWidth: 260, spacing: 20), 1)
        XCTAssertEqual(TVMediaGridMetrics.adaptiveColumnCount(availableWidth: 800, minItemWidth: 0, spacing: 20), 1)
    }

    // MARK: Empty screens

    func testEmptyRowsAreDropped() {
        let layout = TVMediaCursorLayout(rows: [Row(id: "empty", items: []), Row(id: "gba", items: ["g1"])])
        XCTAssertEqual(layout.rows.map(\.id), ["gba"])
        XCTAssertEqual(layout.firstItem, "g1")
    }

    func testAnEmptyScreenStillLetsLeftReachTheSidebar() {
        XCTAssertTrue(TVMediaCursorLayout.empty.isEmpty)
        XCTAssertEqual(TVMediaCursorLayout.empty.move(from: nil, .left), .leftEdge)
        XCTAssertEqual(TVMediaCursorLayout.empty.move(from: nil, .down), .blocked)
        XCTAssertNil(TVMediaCursorLayout.empty.validCursor("x"))
    }
}
