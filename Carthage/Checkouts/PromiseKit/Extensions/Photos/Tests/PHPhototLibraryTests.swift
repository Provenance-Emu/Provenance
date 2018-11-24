import PromiseKit
import PMKPhotos
import Photos
import XCTest

class PHTestCase: XCTestCase {
    func test() {
        let ex = expectation(description: "")
        PHPhotoLibrary.requestAuthorization().done{ _ in ex.fulfill() }
        waitForExpectations(timeout: 10)
    }
}
