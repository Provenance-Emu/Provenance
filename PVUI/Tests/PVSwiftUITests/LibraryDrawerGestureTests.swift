import XCTest
import CoreGraphics
@testable import PVSwiftUI

/// The drawer's drag decisions are pure functions of the gesture values, so each rule is checked directly.
final class LibraryDrawerGestureTests: XCTestCase {
    private let width: CGFloat = 320

    func testCommitDistanceNeverExceedsDismissalDistance() {
        XCTAssertEqual(LibraryDrawerLayout.commitDistance(width: 90), 30)
        XCTAssertEqual(LibraryDrawerLayout.commitDistance(width: width), LibraryDrawerLayout.dismissalDistance)
    }

    func testVerticalScrollNeverOpensOrClosesTheMenu() {
        let translation = CGSize(width: 40, height: 120)
        let predicted = CGSize(width: 400, height: 600)
        XCTAssertFalse(LibraryDrawerLayout.isHorizontal(translation))
        XCTAssertFalse(LibraryDrawerLayout.shouldOpen(predictedEnd: predicted, translation: translation, width: width, direction: 1))
        XCTAssertFalse(LibraryDrawerLayout.shouldClose(predictedEnd: CGSize(width: -400, height: 600), translation: translation, width: width, direction: 1))
    }

    func testEdgeFlingOpensOnceProjectedTravelPassesTheThreshold() {
        let translation = CGSize(width: 30, height: 4)
        XCTAssertFalse(LibraryDrawerLayout.shouldOpen(predictedEnd: CGSize(width: 50, height: 4), translation: translation, width: width, direction: 1))
        XCTAssertTrue(LibraryDrawerLayout.shouldOpen(predictedEnd: CGSize(width: 90, height: 4), translation: translation, width: width, direction: 1))
    }

    func testDraggingTheOpenPanelBackClosesIt() {
        let translation = CGSize(width: -40, height: 2)
        XCTAssertTrue(LibraryDrawerLayout.shouldClose(predictedEnd: CGSize(width: -120, height: 2), translation: translation, width: width, direction: 1))
        XCTAssertFalse(LibraryDrawerLayout.shouldClose(predictedEnd: CGSize(width: -20, height: 2), translation: translation, width: width, direction: 1))
        XCTAssertFalse(LibraryDrawerLayout.shouldOpen(predictedEnd: CGSize(width: -120, height: 2), translation: translation, width: width, direction: 1))
    }

    func testRightToLeftLayoutsMirrorEveryDecision() {
        let opening = CGSize(width: -90, height: 0)
        XCTAssertTrue(LibraryDrawerLayout.shouldOpen(predictedEnd: opening, translation: opening, width: width, direction: -1))
        XCTAssertFalse(LibraryDrawerLayout.shouldOpen(predictedEnd: opening, translation: opening, width: width, direction: 1))
        let closing = CGSize(width: 90, height: 0)
        XCTAssertTrue(LibraryDrawerLayout.shouldClose(predictedEnd: closing, translation: closing, width: width, direction: -1))
        XCTAssertEqual(LibraryDrawerLayout.revealProgress(dragTranslation: -160, width: width, direction: -1), 0.5)
    }

    func testRevealProgressIsClampedToThePanel() {
        XCTAssertEqual(LibraryDrawerLayout.revealProgress(dragTranslation: -50, width: width, direction: 1), 0)
        XCTAssertEqual(LibraryDrawerLayout.revealProgress(dragTranslation: 80, width: width, direction: 1), 0.25)
        XCTAssertEqual(LibraryDrawerLayout.revealProgress(dragTranslation: 1000, width: width, direction: 1), 1)
        XCTAssertEqual(LibraryDrawerLayout.revealProgress(dragTranslation: 80, width: 0, direction: 1), 0)
    }

    func testOpenPanelFollowsTheFingerOnlyTowardsClosed() {
        XCTAssertEqual(LibraryDrawerLayout.openPanelOffset(dragTranslation: 60, width: width, direction: 1), 0)
        XCTAssertEqual(LibraryDrawerLayout.openPanelOffset(dragTranslation: -100, width: width, direction: 1), -100)
        XCTAssertEqual(LibraryDrawerLayout.openPanelOffset(dragTranslation: -900, width: width, direction: 1), -width)
        XCTAssertEqual(LibraryDrawerLayout.openPanelOffset(dragTranslation: 100, width: width, direction: -1), 100)
    }
}
