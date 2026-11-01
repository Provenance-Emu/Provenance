import XCTest
import Combine
@testable import PVSwiftUI

final class LibrarySearchStateTests: XCTestCase {
    func testHidingRequestedSearchClearsQueryInSmallLibraries() {
        for count in [0, 8] {
            for preference in [false, true] {
                let model = PVRootViewModel()
                model.showsLibrarySearch = true
                model.librarySearch.query = "Neon"
                XCTAssertTrue(model.librarySearch.isFieldVisible(gameCount: count, prefersSearchbar: preference))

                model.showsLibrarySearch.toggle()

                XCTAssertTrue(model.librarySearch.query.isEmpty)
                XCTAssertFalse(model.librarySearch.isFieldVisible(gameCount: count, prefersSearchbar: preference))
            }
        }
    }

    func testHidingRequestedSearchWithAutomaticSearchDisabledClearsQuery() {
        let model = PVRootViewModel()
        model.showsLibrarySearch = true
        model.librarySearch.query = "Neon"
        XCTAssertTrue(model.librarySearch.isFieldVisible(gameCount: 100, prefersSearchbar: false))
        model.showsLibrarySearch = false
        XCTAssertTrue(model.librarySearch.query.isEmpty)
        XCTAssertFalse(model.librarySearch.isFieldVisible(gameCount: 100, prefersSearchbar: false))

        model.showsLibrarySearch = true
        XCTAssertTrue(model.librarySearch.query.isEmpty, "Reopening must not revive the old results overlay")
    }

    func testAlwaysVisibleSearchRemainsEditableButDismissalClearsResults() {
        let model = PVRootViewModel()
        model.showsLibrarySearch = true
        model.librarySearch.query = "Neon"
        model.showsLibrarySearch = false
        XCTAssertTrue(model.librarySearch.isFieldVisible(gameCount: 9, prefersSearchbar: true))
        XCTAssertTrue(model.librarySearch.query.isEmpty)
    }

    func testTypingOnlyNotifiesSearchObservers() {
        let model = PVRootViewModel()
        var libraryChanges = 0
        var searchChanges = 0
        let libraryObservation = model.objectWillChange.sink { libraryChanges += 1 }
        let searchObservation = model.librarySearch.objectWillChange.sink { searchChanges += 1 }
        defer { libraryObservation.cancel(); searchObservation.cancel() }

        model.librarySearch.query = "Neon"

        XCTAssertEqual(searchChanges, 1)
        XCTAssertEqual(libraryChanges, 0)
    }
}
