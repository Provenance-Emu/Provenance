import EmulatorContentClient
import XCTest

final class ResumePlannerTests: XCTestCase {
    func testPartialDownloadRequestsTheRemainingRange() {
        let plan = ResumePlan.plan(localBytes: 4, totalBytes: 10)
        XCTAssertEqual(plan.offset, 4)
        XCTAssertEqual(plan.range, "bytes=4-")
    }

    func testWholeFileResponseDuringResumeRestarts() {
        XCTAssertEqual(interpretDownload(statusCode: 206, requestedOffset: 4), .append(offset: 4))
        XCTAssertEqual(interpretDownload(statusCode: 200, requestedOffset: 4), .restart)
        XCTAssertEqual(interpretDownload(statusCode: 304, requestedOffset: 4), .notModified)
        XCTAssertEqual(interpretDownload(statusCode: 416, requestedOffset: 4), .unsatisfiable)
    }
}
