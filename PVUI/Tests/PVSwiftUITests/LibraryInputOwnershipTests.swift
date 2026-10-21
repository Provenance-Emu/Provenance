import XCTest
@testable import PVSwiftUI

final class LibraryInputOwnershipTests: XCTestCase {
    func testLibraryCanNavigateWithoutPresentations() {
        XCTAssertFalse(LibraryInputOwnership().isBlocked)
    }

    func testDismissingCoreOptionsRetainsAnotherPresentersInputClaim() {
        var ownership = LibraryInputOwnership(hasLibraryPresentation: true, hasCoreOptionsPresentation: true)
        ownership.hasCoreOptionsPresentation = false
        XCTAssertTrue(ownership.isBlocked)
        ownership.hasLibraryPresentation = false
        XCTAssertFalse(ownership.isBlocked)
    }

    func testDismissingLibrarySheetRetainsCoreOptionsInputClaim() {
        var ownership = LibraryInputOwnership(hasLibraryPresentation: true, hasCoreOptionsPresentation: true)
        ownership.hasLibraryPresentation = false
        XCTAssertTrue(ownership.isBlocked)
        ownership.hasCoreOptionsPresentation = false
        XCTAssertFalse(ownership.isBlocked)
    }
}
