import PMKWatchConnectivity
import WatchConnectivity
import PromiseKit
import XCTest

class WatchConnectivityTests: XCTestCase {
    class MockSession: WCSession {

        var fail = false

        override func sendMessage(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
            if fail {
                errorHandler?(NSError(domain: "Test", code: 1, userInfo: [:]))
            } else {
                replyHandler?(["response": "Success"])
            }
        }
    }

    func testSuccess() {

        let ex = expectation(description: "Success callback")
        let session = MockSession.default as! MockSession
        session.fail = false
        session.sendMessage(["message": "test"]).done { response in
            XCTAssertEqual(response as! [String: String], ["response": "Success"])
            ex.fulfill()
        }.catch { _ in
            XCTFail("Should not fail")
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testFailure() {
        class MockFailSession: WCSession {
             override func sendMessage(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
                errorHandler?(NSError(domain: "Test", code: 1, userInfo: [:]))
            }
        }

        let ex = expectation(description: "Error callback")
        let session = MockSession.default as! MockSession
        session.fail = true
        session.sendMessage(["message": "test"]).done { response in
            XCTFail("Should not succeed")
        }.catch { error in
            XCTAssertEqual((error as NSError).domain, "Test")
            ex.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
