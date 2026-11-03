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

    func testBothSidebarSheetsBlockThePinnedLibrarySynchronously() {
        let model = PVRootViewModel()
        model.usesPinnedSidebar = true
        for sheet in LibrarySidebarSheet.allCases {
            model.sidebarSheet = sheet
            XCTAssertFalse(model.isMenuVisible)
            XCTAssertTrue(model.isLibraryInputBlocked, "\(sheet) must own A/directions before its view appears")
            model.sidebarSheet = nil
            XCTAssertTrue(model.isLibraryInputBlocked, "Dismissal animation still owns input")
            model.didDismissSidebarSheet()
            XCTAssertFalse(model.isLibraryInputBlocked)
        }
    }

    func testSidebarDismissalDoesNotReleaseOtherPresentationOwners() {
        for library in [false, true] {
            for coreOptions in [false, true] {
                let model = PVRootViewModel()
                model.inputOwnership.hasLibraryPresentation = library
                model.inputOwnership.hasCoreOptionsPresentation = coreOptions
                model.sidebarSheet = .nearbyLibraries
                model.sidebarSheet = nil
                model.didDismissSidebarSheet()
                XCTAssertEqual(model.isLibraryInputBlocked, library || coreOptions)
            }
        }
    }

    func testOtherPresentersCannotReleaseTheSidebarClaim() {
        var ownership = LibraryInputOwnership(hasLibraryPresentation: true, hasCoreOptionsPresentation: true, hasSidebarPresentation: true)
        ownership.hasLibraryPresentation = false
        ownership.hasCoreOptionsPresentation = false
        XCTAssertTrue(ownership.isBlocked)
        ownership.hasSidebarPresentation = false
        XCTAssertFalse(ownership.isBlocked)
    }

    func testSidebarDisappearanceKeepsRootSheetInputBlockedUntilDismissal() {
        let model = PVRootViewModel()
        model.usesPinnedSidebar = true
        model.sidebarSheet = .networkPlay
        model.dismissMenu()
        XCTAssertTrue(model.isSidebarCollapsed)
        XCTAssertTrue(model.isLibraryInputBlocked)
        model.usesPinnedSidebar = false
        XCTAssertTrue(model.isLibraryInputBlocked)
        model.sidebarSheet = nil
        model.didDismissSidebarSheet()
        XCTAssertFalse(model.isLibraryInputBlocked)
    }

    func testPreviousDismissalCannotReleaseANewSidebarSheet() {
        let model = PVRootViewModel()
        model.sidebarSheet = .nearbyLibraries
        model.sidebarSheet = nil
        model.sidebarSheet = .networkPlay
        model.didDismissSidebarSheet()
        XCTAssertTrue(model.isLibraryInputBlocked)
    }
}
