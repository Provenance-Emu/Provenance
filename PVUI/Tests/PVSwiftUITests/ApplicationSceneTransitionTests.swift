import XCTest
import SwiftUI
@testable import PVSwiftUI

final class ApplicationSceneTransitionTests: XCTestCase {
    func testLeavingActiveSavesWithOrWithoutAnInactivePhase() {
        XCTAssertTrue(ApplicationSceneTransition.shouldSave(from: .active, to: .inactive))
        XCTAssertTrue(ApplicationSceneTransition.shouldSave(from: .active, to: .background))
    }

    func testEnteringBackgroundDoesNotSaveTwice() {
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: .inactive, to: .background))
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: .background, to: .background))
    }

    func testColdLaunchAndForegroundingDoNotSave() {
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: nil, to: .inactive))
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: nil, to: .background))
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: .background, to: .inactive))
        XCTAssertFalse(ApplicationSceneTransition.shouldSave(from: .inactive, to: .active))
    }
}
