import PromiseKit
import PMKUIKit
import XCTest
import UIKit

class UIViewTests: XCTestCase {
    func test() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")

        UIView.animate(.promise, duration: 0.1) {
            ex1.fulfill()
        }.done { _ in
            ex2.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
