import XCTest
@testable import PVLibrary

final class NewSaveStateUploadTests: XCTestCase {
    func testALocalSaveStateIsQueued() {
        XCTAssertEqual(NewSaveStateUpload.decide(hasCloudRecord: false, isManualCadence: false), .enqueue)
    }

    func testManualFrequencyHoldsItForTheNextSync() {
        XCTAssertEqual(NewSaveStateUpload.decide(hasCloudRecord: false, isManualCadence: true), .hold)
    }

    func testASaveStateThatCameFromICloudIsNotUploadedAgain() {
        XCTAssertEqual(NewSaveStateUpload.decide(hasCloudRecord: true, isManualCadence: false), .ignore)
        XCTAssertEqual(NewSaveStateUpload.decide(hasCloudRecord: true, isManualCadence: true), .ignore)
    }
}
