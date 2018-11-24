import PMKQuartzCore
import PromiseKit
import QuartzCore
import XCTest

class TestCALayer: XCTestCase {
    func test() {
        let ex = expectation(description: "")

        CALayer().add(.promise, animation: CAAnimation()).done { _ in
            ex.fulfill()
        }

        wait(for: [ex], timeout: 10)
    }
}
