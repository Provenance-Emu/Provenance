import Foundation
import XCTest
import PVSystems
@testable import PVLibrary

/// A file detection cannot identify must still import once the user names its system.
final class ImportQueueItemSystemChoiceTests: XCTestCase {
    private func makeItem(chosen: SystemIdentifier?) -> ImportQueueItem {
        let item = ImportQueueItem(url: URL(fileURLWithPath: "/tmp/Homebrew.bin"), fileType: .game)
        item.userChosenSystem = chosen
        return item
    }

    func testWithoutAChoiceDetectionIsUnchanged() {
        let item = makeItem(chosen: nil)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: []), [])
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.SNES, .N64]), [.SNES, .N64])
    }

    func testChoiceStandsInWhenDetectionFindsNothing() {
        let item = makeItem(chosen: .AtariJaguarCD)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: []), [.AtariJaguarCD])
    }

    func testChoiceAmongDetectedCandidatesKeepsThemAllForConflictResolution() {
        let item = makeItem(chosen: .AtariJaguar)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.AtariJaguar, .AtariJaguarCD]), [.AtariJaguar, .AtariJaguarCD])
    }

    func testChoiceOutsideDetectedCandidatesOverridesThem() {
        let item = makeItem(chosen: .DOS)
        XCTAssertEqual(item.systems(applyingUserChoiceTo: [.AtariJaguar, .AtariJaguarCD]), [.DOS])
    }

    func testOverriddenSystemsMakeTheChoiceTheTarget() {
        let item = makeItem(chosen: .DOS)
        item.systems = item.systems(applyingUserChoiceTo: [])
        XCTAssertEqual(item.targetSystem(), .DOS)
    }
}
