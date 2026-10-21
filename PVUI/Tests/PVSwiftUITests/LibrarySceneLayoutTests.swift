import XCTest
import CoreGraphics
@testable import PVSwiftUI

final class LibrarySceneLayoutTests: XCTestCase {
    func testPhonesKeepThePagedLibraryInEitherOrientation() {
        XCTAssertFalse(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 402, height: 874)))
        XCTAssertFalse(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 874, height: 402)))
    }

    func testNarrowAndShortWindowsKeepThePagedLibrary() {
        XCTAssertFalse(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 600, height: 1024)))
        XCTAssertFalse(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 1200, height: 400)))
    }

    func testRoomyTabletAndDesktopWindowsSupportMediaNavigation() {
        XCTAssertTrue(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 1194, height: 834)))
        XCTAssertTrue(LibrarySceneLayout.supportsMediaNavigation(in: CGSize(width: 1200, height: 800)))
    }
}
