import XCTest
@testable import PVLibrary

@MainActor
final class BIOSDownloadTrackerTests: XCTestCase {
    func testBeginMarksDownloadingCaseInsensitively() {
        let tracker = BIOSDownloadTracker()
        tracker.begin("TOS.img")
        XCTAssertEqual(tracker.status(for: "tos.img"), .downloading)
    }

    func testSuccessfulFinishClearsStatus() {
        let tracker = BIOSDownloadTracker()
        tracker.begin("scph1001.bin")
        tracker.finish("scph1001.bin", success: true)
        XCTAssertNil(tracker.status(for: "scph1001.bin"))
        XCTAssertTrue(tracker.statuses.isEmpty)
    }

    func testFailedFinishIsRememberedUntilRetried() {
        let tracker = BIOSDownloadTracker()
        tracker.begin("bios.rom")
        tracker.finish("bios.rom", success: false)
        XCTAssertEqual(tracker.status(for: "bios.rom"), .failed)

        tracker.begin("bios.rom")
        XCTAssertEqual(tracker.status(for: "bios.rom"), .downloading)
    }
}
