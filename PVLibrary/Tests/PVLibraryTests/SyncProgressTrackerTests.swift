import XCTest
@testable import PVLibrary

final class SyncProgressTrackerTests: XCTestCase {
    func testDownloadKindIdentifiersAreUniquePerType() {
        let romKind = SyncProgressTracker.DownloadKind.rom(md5: "ABC123")
        let saveKind = SyncProgressTracker.DownloadKind.saveState(recordID: "ABC123")

        XCTAssertNotEqual(
            romKind.identifier,
            saveKind.identifier,
            "ROM and save-state download kinds should never collide even if their raw values match."
        )

        XCTAssertNotEqual(
            romKind.description,
            saveKind.description,
            "Descriptions should reflect the underlying item type for logging clarity."
        )
    }
}
