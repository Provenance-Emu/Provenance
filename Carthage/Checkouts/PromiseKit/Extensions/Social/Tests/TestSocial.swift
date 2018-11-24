import PromiseKit
import PMKSocial
import Social
import XCTest

class SLRequestTests: XCTestCase {
    func testSLRequest() {
        // I tried to just override SLRequest, but Swift wouldn't let me
        // then use the long initializer, and an exception is thrown inside
        // init()

        swizzle(SLRequest.self, #selector(SLRequest.perform(handler:))) {
            let url = URL(string: "https://api.twitter.com/1.1/statuses/user_timeline.json")
            let params = ["foo": "bar"]
            let rq = SLRequest(forServiceType: SLServiceTypeTwitter, requestMethod: .GET, url: url, parameters: params)!

            let ex = expectation(description: "")
            rq.perform().done {
                XCTAssertEqual($0.data, Data())
                ex.fulfill()
            }.catch {
                XCTFail("\($0)")
            }
            waitForExpectations(timeout: 1, handler: nil)
        }
    }
}

extension SLRequest {
    @objc private func pmk_performRequestWithHandler(_ handler: @escaping SLRequestHandler) {
        after(seconds: 0).done { _ in
            let rsp = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: "2.0", headerFields: [:])
            handler(Data(), rsp, nil)
        }
    }
}


import ObjectiveC

func swizzle(_ foo: AnyClass, _ from: Selector, isClassMethod: Bool = false, body: () -> Void) {
    let originalMethod: Method!
    let swizzledMethod: Method!

    if isClassMethod {
        originalMethod = class_getClassMethod(foo, from)
        swizzledMethod = class_getClassMethod(foo, Selector("pmk_\(from)"))
    } else {
        originalMethod = class_getInstanceMethod(foo, from)
        swizzledMethod = class_getInstanceMethod(foo, Selector("pmk_\(from)"))
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
    body()
    method_exchangeImplementations(swizzledMethod, originalMethod)
}
