import XCTest
import Combine
@testable import PVSwiftUI

final class LibraryDrawerObservationTests: XCTestCase {
    func testMenuVisibilityUpdatesOnlyDrawerObservers() {
        let model = PVRootViewModel()
        var libraryChanges = 0
        var drawerChanges = 0
        let libraryObservation = model.objectWillChange.sink { _ in libraryChanges += 1 }
        let drawerObservation = model.drawerState.objectWillChange.sink { _ in drawerChanges += 1 }
        defer { libraryObservation.cancel(); drawerObservation.cancel() }

        model.isMenuVisible = true

        XCTAssertTrue(model.isMenuVisible)
        XCTAssertEqual(drawerChanges, 1)
        XCTAssertEqual(libraryChanges, 0)
    }

    func testRepeatedCloseDoesNotPublishDrawerChanges() {
        let model = PVRootViewModel()
        var changes = 0
        let observation = model.drawerState.objectWillChange.sink { _ in changes += 1 }
        defer { observation.cancel() }

        model.isMenuVisible = false
        model.isMenuVisible = true
        model.isMenuVisible = false
        model.isMenuVisible = false

        XCTAssertEqual(changes, 2)
    }

    func testLibrarySettingsStillPublishIndependentlyOfDrawer() {
        let model = PVRootViewModel()
        var libraryChanges = 0
        var drawerChanges = 0
        let libraryObservation = model.objectWillChange.sink { _ in libraryChanges += 1 }
        let drawerObservation = model.drawerState.objectWillChange.sink { _ in drawerChanges += 1 }
        defer { libraryObservation.cancel(); drawerObservation.cancel() }

        model.sortGamesAscending.toggle()

        XCTAssertEqual(libraryChanges, 1)
        XCTAssertEqual(drawerChanges, 0)
    }
}
