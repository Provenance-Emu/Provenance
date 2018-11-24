import PMKStoreKit
import PromiseKit
import StoreKit
import XCTest

class SKProductsRequestTests: XCTestCase {
    func test() {
        class MockProductsRequest: SKProductsRequest {
            override func start() {
                after(seconds: 0.1).done {
                    self.delegate?.productsRequest(self, didReceive: SKProductsResponse())
                }
            }
        }

        let ex = expectation(description: "")
        MockProductsRequest().start(.promise).done { _ in
            ex.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
