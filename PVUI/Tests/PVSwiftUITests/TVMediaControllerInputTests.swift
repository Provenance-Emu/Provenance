#if os(iOS) || os(tvOS)
import XCTest
@testable import PVSwiftUI

/// Who owns a controller event in the tvOS-style layout on iOS, and where the cursor is drawn.
@MainActor
final class TVMediaControllerInputTests: XCTestCase {
    /// Runs after everything already on the main queue, which is when an event's owner snapshot is dropped.
    private func finishCurrentEvent() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    // MARK: Input owner

    func testContentOwnsInputByDefaultAndSidebarWhileExpanded() {
        let coordinator = TVMediaFocusCoordinator()
        XCTAssertEqual(coordinator.inputOwner, .content)
        coordinator.openSidebar()
        XCTAssertEqual(coordinator.inputOwner, .sidebar)
        coordinator.closeSidebar()
        XCTAssertEqual(coordinator.inputOwner, .content)
    }

    func testAlertsAndUntrackedOverlaysOwnInput() {
        let coordinator = TVMediaFocusCoordinator()
        coordinator.isAlertPresented = true
        XCTAssertEqual(coordinator.inputOwner, .overlay)
        coordinator.isAlertPresented = false

        var sheetIsUp = true
        coordinator.isExternalOverlayPresented = { sheetIsUp }
        XCTAssertEqual(coordinator.inputOwner, .overlay)
        sheetIsUp = false
        XCTAssertEqual(coordinator.inputOwner, .content)
    }

    /// The regression behind "B opens the sidebar and it closes again": the shell opened it,
    /// then the rail, handling the same press, saw it open and closed it.
    func testEverySubscriberOfOneEventSeesTheSameOwner() async {
        let coordinator = TVMediaFocusCoordinator()
        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .content)

        // First subscriber opens the sidebar while handling the press.
        coordinator.openSidebar()
        XCTAssertEqual(coordinator.inputOwner, .sidebar)
        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .content, "Later subscribers of the same press must not see the change")

        await finishCurrentEvent()
        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .sidebar, "The next press sees the new owner")
    }

    /// The A press that picks a sidebar item must not also reach the content it reveals.
    func testAPressThatClosesTheSidebarStaysWithTheSidebar() async {
        let coordinator = TVMediaFocusCoordinator()
        coordinator.openSidebar()
        await finishCurrentEvent()

        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .sidebar)
        coordinator.closeSidebar()
        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .sidebar)

        await finishCurrentEvent()
        XCTAssertEqual(coordinator.inputOwnerForCurrentEvent(), .content)
    }

    // MARK: Cursor

    func testCursorIsHiddenWhileTheSidebarHasIt() {
        let coordinator = TVMediaFocusCoordinator()
        coordinator.contentFocus.setCursor("game-1")
        XCTAssertEqual(coordinator.contentFocus.cursorID, "game-1")

        coordinator.openSidebar()
        XCTAssertNil(coordinator.contentFocus.cursorID, "Two highlights would say two things have the cursor")
        XCTAssertEqual(coordinator.contentFocus.contentCursorID, "game-1")

        coordinator.closeSidebar()
        XCTAssertEqual(coordinator.contentFocus.cursorID, "game-1", "The cursor returns to where it was")
    }

    func testAdoptingALayoutPutsTheCursorOnItsFirstItem() {
        let focus = TVMediaContentFocus()
        let layout = TVMediaCursorLayout(gridItems: ["a", "b", "c"], columns: 2)
        focus.adoptCursor(in: layout)
        XCTAssertEqual(focus.cursorID, "a")
    }

    func testAdoptingALayoutKeepsACursorThatIsStillOnScreen() {
        let focus = TVMediaContentFocus()
        focus.setCursor("c")
        focus.adoptCursor(in: TVMediaCursorLayout(gridItems: ["a", "b", "c"], columns: 2))
        XCTAssertEqual(focus.cursorID, "c")

        // The item went away (deleted, or another screen): back to the first one.
        focus.adoptCursor(in: TVMediaCursorLayout(gridItems: ["x", "y"], columns: 2))
        XCTAssertEqual(focus.cursorID, "x")
    }

    /// Save States: the filter button's row arrives first, the grid a moment later. The
    /// cursor must end up on the first save, unless the user already moved it.
    func testADefaultCursorFollowsTheLayoutUntilTheUserMovesIt() {
        typealias Row = TVMediaCursorLayout.Row
        let header = TVMediaCursorLayout(rows: [Row(id: "header", items: ["filter"], isHeader: true)])
        let loaded = header.appending(TVMediaCursorLayout(gridItems: ["s1", "s2"], columns: 2))

        let focus = TVMediaContentFocus()
        focus.adoptCursor(in: header)
        XCTAssertEqual(focus.cursorID, "filter")
        focus.adoptCursor(in: loaded)
        XCTAssertEqual(focus.cursorID, "s1")

        let moved = TVMediaContentFocus()
        moved.adoptCursor(in: loaded)
        moved.setCursor("filter")
        moved.adoptCursor(in: loaded)
        XCTAssertEqual(moved.cursorID, "filter", "A cursor the user placed stays where it is")
    }

    func testAnEmptyScreenClearsTheCursor() {
        let focus = TVMediaContentFocus()
        focus.setCursor("a")
        focus.adoptCursor(in: .empty)
        XCTAssertNil(focus.cursorID)
    }

    // MARK: Back button

    func testTheVisibleScreenGetsTheBackPressFirst() {
        let coordinator = TVMediaFocusCoordinator()
        XCTAssertFalse(coordinator.interceptBack(), "With no interceptor the shell handles B")

        var isFullscreen = true
        coordinator.setBackInterceptor(owner: "logs") {
            guard isFullscreen else { return false }
            isFullscreen = false
            return true
        }
        XCTAssertTrue(coordinator.interceptBack())
        XCTAssertFalse(coordinator.interceptBack(), "Nothing left to leave: the shell handles B")
    }

    /// The old screen disappears after the new one appeared; it must not take the new one's interceptor.
    func testAScreenLeavingDoesNotRemoveTheNextScreensInterceptor() {
        let coordinator = TVMediaFocusCoordinator()
        coordinator.setBackInterceptor(owner: "search") { true }
        coordinator.setBackInterceptor(owner: "logs") { true }
        coordinator.clearBackInterceptor(owner: "search")
        XCTAssertTrue(coordinator.interceptBack())

        coordinator.clearBackInterceptor(owner: "logs")
        XCTAssertFalse(coordinator.interceptBack())
    }

    // MARK: Sheets

    func testOnlyTheImportQueueHandlesItsOwnBackButton() {
        XCTAssertFalse(TVMediaModal.importQueue.usesShellBackButton)
        XCTAssertTrue(TVMediaModal.nearbyLibraries.usesShellBackButton)
        XCTAssertTrue(TVMediaModal.netplayLobby.usesShellBackButton)
        XCTAssertTrue(TVMediaModal.help.usesShellBackButton)
    }
}
#endif
