import XCTest
@testable import PVUIBase

final class RetroLogControllerNavigationTests: XCTestCase {
    private let rows = (0..<25).map { _ in UUID() }
    private typealias Navigation = RetroLogControllerNavigation

    func testFirstDownPressLandsOnTheFirstRow() {
        XCTAssertEqual(Navigation.moveVertical(from: nil, by: 1, rowIDs: rows), .row(rows[0]))
    }

    func testFirstUpPressLandsOnTheToolbar() {
        XCTAssertEqual(Navigation.moveVertical(from: nil, by: -1, rowIDs: rows), .toolbar(.autoScroll))
    }

    func testDownAndUpStepThroughRows() {
        XCTAssertEqual(Navigation.moveVertical(from: .row(rows[3]), by: 1, rowIDs: rows), .row(rows[4]))
        XCTAssertEqual(Navigation.moveVertical(from: .row(rows[3]), by: -1, rowIDs: rows), .row(rows[2]))
    }

    func testUpFromTheFirstRowReachesTheToolbarAndDownReturns() {
        XCTAssertEqual(Navigation.moveVertical(from: .row(rows[0]), by: -1, rowIDs: rows), .toolbar(.autoScroll))
        XCTAssertEqual(Navigation.moveVertical(from: .toolbar(.clear), by: 1, rowIDs: rows), .row(rows[0]))
        XCTAssertEqual(Navigation.moveVertical(from: .toolbar(.clear), by: -1, rowIDs: rows), .toolbar(.clear))
    }

    func testPagingClampsToTheEnds() {
        let page = Navigation.pageSize
        XCTAssertEqual(Navigation.moveVertical(from: .row(rows[20]), by: page, rowIDs: rows), .row(rows[24]))
        XCTAssertEqual(Navigation.moveVertical(from: .row(rows[4]), by: -page, rowIDs: rows), .row(rows[0]))
    }

    func testARowThatWasClearedRestartsAtTheFirstRow() {
        XCTAssertEqual(Navigation.moveVertical(from: .row(UUID()), by: 1, rowIDs: rows), .row(rows[0]))
        XCTAssertEqual(Navigation.moveVertical(from: .row(UUID()), by: 1, rowIDs: []), .toolbar(.autoScroll))
    }

    func testAnEmptyLogKeepsTheCursorOnTheToolbar() {
        XCTAssertEqual(Navigation.moveVertical(from: .toolbar(.details), by: 1, rowIDs: []), .toolbar(.details))
        XCTAssertEqual(Navigation.moveVertical(from: nil, by: 1, rowIDs: []), .toolbar(.autoScroll))
    }

    func testLeftAndRightWalkTheToolbarAndStopAtItsEnds() {
        XCTAssertEqual(Navigation.moveHorizontal(from: .toolbar(.autoScroll), by: 1), .toolbar(.sortOrder))
        XCTAssertEqual(Navigation.moveHorizontal(from: .toolbar(.autoScroll), by: -1), .toolbar(.autoScroll))
        XCTAssertEqual(Navigation.moveHorizontal(from: .toolbar(.fullscreen), by: 1), .toolbar(.fullscreen))
    }

    func testLeftAndRightDoNothingOnARow() {
        XCTAssertEqual(Navigation.moveHorizontal(from: .row(rows[2]), by: 1), .row(rows[2]))
        XCTAssertNil(Navigation.moveHorizontal(from: nil, by: 1))
    }
}
