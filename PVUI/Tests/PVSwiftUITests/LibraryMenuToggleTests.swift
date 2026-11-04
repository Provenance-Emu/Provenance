import XCTest
@testable import PVSwiftUI

/// The header button, gamepad menu toggle and menu rows all go through these three entry points.
final class LibraryMenuToggleTests: XCTestCase {
    func testOverlayDrawerTogglesThroughTheDrawerState() {
        let model = PVRootViewModel()
        XCTAssertFalse(model.isMenuShown)
        model.toggleMenu()
        XCTAssertTrue(model.isMenuVisible)
        XCTAssertTrue(model.drawerState.isPresented)
        XCTAssertTrue(model.isMenuShown)
        XCTAssertFalse(model.isSidebarCollapsed, "An overlay toggle must not touch the iPad sidebar")
        model.toggleMenu()
        XCTAssertFalse(model.isMenuVisible)
    }

    func testPinnedSidebarTogglesCollapseInstead() {
        let model = PVRootViewModel()
        model.usesPinnedSidebar = true
        XCTAssertTrue(model.isMenuShown, "A regular-width iPad starts with its sidebar open")
        model.toggleMenu()
        XCTAssertTrue(model.isSidebarCollapsed)
        XCTAssertFalse(model.isMenuShown)
        XCTAssertFalse(model.isMenuVisible, "A pinned toggle must not slide the overlay drawer out")
        model.toggleMenu()
        XCTAssertFalse(model.isSidebarCollapsed)
    }

    func testDismissClosesWhicheverPresentationIsActive() {
        let overlay = PVRootViewModel()
        overlay.isMenuVisible = true
        overlay.dismissMenu()
        XCTAssertFalse(overlay.isMenuVisible)

        let pinned = PVRootViewModel()
        pinned.usesPinnedSidebar = true
        pinned.dismissMenu()
        XCTAssertTrue(pinned.isSidebarCollapsed)
        pinned.dismissMenu()
        XCTAssertTrue(pinned.isSidebarCollapsed, "Dismissing an already collapsed sidebar stays collapsed")
    }

    func testSwitchingToPinnedLayoutLeavesTheOverlayStateUntouched() {
        let model = PVRootViewModel()
        model.isMenuVisible = true
        model.usesPinnedSidebar = true
        XCTAssertTrue(model.isMenuVisible, "The drawer binding keeps its value until the host closes it")
        XCTAssertTrue(model.isMenuShown)
        model.dismissMenu()
        XCTAssertTrue(model.isSidebarCollapsed)
        XCTAssertTrue(model.isMenuVisible, "Pinned dismissal only collapses the sidebar")
    }
}
