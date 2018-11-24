import PMKAVFoundation
import AVFoundation
import PromiseKit
import XCTest

class Test_AVAudioSession_Swift: XCTestCase {
    func test() {
        let ex = expectation(description: "")

        AVAudioSession().requestRecordPermission().done { _ in
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testNotAmbiguous() {
        let ex = expectation(description: "")
        AVAudioSession().requestRecordPermission { _ in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}
