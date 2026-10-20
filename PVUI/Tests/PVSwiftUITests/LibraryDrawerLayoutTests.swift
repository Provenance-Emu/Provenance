import XCTest
import CoreGraphics
@testable import PVSwiftUI

final class LibraryDrawerLayoutTests: XCTestCase {
    func testPhonePortraitKeepsDismissalAreaVisible() {
        let size = CGSize(width: 393, height: 852)
        let width = LibraryDrawerLayout.width(in: size)
        XCTAssertGreaterThanOrEqual(width, 280)
        XCTAssertLessThanOrEqual(width, size.width - 44)
    }

    func testLandscapeAndTabletDoNotCreateOversizedMenus() {
        for size in [CGSize(width: 852, height: 393), CGSize(width: 1366, height: 1024)] {
            XCTAssertLessThanOrEqual(LibraryDrawerLayout.width(in: size), 380)
        }
    }

    func testNarrowSplitWindowNeverOverflows() {
        for width in [0.0, 30, 200, 280, 320] {
            let panel = LibraryDrawerLayout.width(in: CGSize(width: width, height: 800))
            XCTAssertGreaterThanOrEqual(panel, 0)
            XCTAssertLessThanOrEqual(panel, max(0, width - 44))
        }
    }

    func testResizingUsesCurrentWindowGeometry() {
        let portrait = LibraryDrawerLayout.width(in: CGSize(width: 393, height: 852))
        let landscape = LibraryDrawerLayout.width(in: CGSize(width: 852, height: 393))
        XCTAssertNotEqual(portrait, landscape)
    }

    func testHiddenDrawerClearsLandscapeSafeAreaAndShadow() {
        let width = LibraryDrawerLayout.width(in: CGSize(width: 874, height: 402))
        for inset in [0.0, 44, 62] {
            let travel = LibraryDrawerLayout.hiddenTravel(width: width, sideInset: inset)
            XCTAssertGreaterThanOrEqual(travel - width - inset, LibraryDrawerLayout.shadowOverflow)
        }
    }
}

final class LibraryTabSelectionTests: XCTestCase {
    func testWrapsThroughHomeInBothDirections() {
        let systems = ["first", "last"]
        XCTAssertEqual(LibraryTabSelection.destination(from: "home", systems: systems, isNext: true), "first")
        XCTAssertEqual(LibraryTabSelection.destination(from: "last", systems: systems, isNext: true), "home")
        XCTAssertEqual(LibraryTabSelection.destination(from: "home", systems: systems, isNext: false), "last")
        XCTAssertEqual(LibraryTabSelection.destination(from: "first", systems: systems, isNext: false), "home")
    }

    func testEmptyLibraryStaysOnHome() {
        for next in [true, false] {
            XCTAssertEqual(LibraryTabSelection.destination(from: "home", systems: [], isNext: next), "home")
        }
    }

    func testRemovedConsoleReturnsToHome() {
        XCTAssertEqual(LibraryTabSelection.destination(from: "removed", systems: ["remaining"], isNext: true), "home")
    }
}
