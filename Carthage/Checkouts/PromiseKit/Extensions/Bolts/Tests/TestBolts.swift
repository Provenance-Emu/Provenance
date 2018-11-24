import PromiseKit
import PMKBolts
import XCTest
import Bolts

class TestBolts: XCTestCase {
    func test() {
        let ex = expectation(description: "")

        let value = { NSString(string: "1") }

        firstly { () -> Promise<Void> in
            return Promise()
        }.then { _ -> BFTask<NSString> in
            return BFTask(result: value())
        }.done { obj in
            XCTAssertEqual(obj, value())
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
