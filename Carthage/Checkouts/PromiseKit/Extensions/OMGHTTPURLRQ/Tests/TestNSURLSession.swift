import PMKOMGHTTPURLRQ
import OHHTTPStubs
import PromiseKit
import XCTest

class NSURLSessionTests: XCTestCase {
    func test1() {
        let json: NSDictionary = ["key1": "value1", "key2": ["value2A", "value2B"]]

        OHHTTPStubs.stubRequests(passingTest: { $0.url!.host == "example.com" }) { _ in
            return OHHTTPStubsResponse(jsonObject: json, statusCode: 200, headers: nil)
        }

        let ex = expectation(description: "")
        URLSession.shared.GET("http://example.com").compactMap {
            try JSONSerialization.jsonObject(with: $0.data)
        }.done {
            XCTAssertEqual(json, $0 as? NSDictionary)
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func test2() {

        // test that Promise<Data> chains thens
        // this test because I don’t trust the Swift compiler

        let dummy = ("fred" as NSString).data(using: String.Encoding.utf8.rawValue)!

        OHHTTPStubs.stubRequests(passingTest: { $0.url!.host == "example.com" }) { _ in
            return OHHTTPStubsResponse(data: dummy, statusCode: 200, headers: [:])
        }

        let ex = expectation(description: "")

        after(seconds: 0.1).then {
            URLSession.shared.GET("http://example.com")
        }.done {
            XCTAssertEqual($0.data, dummy)
            ex.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testSyntax() {
        let json: NSDictionary = ["key1": "value1", "key2": ["value2A", "value2B"]]

        OHHTTPStubs.stubRequests(passingTest: {
            $0.url!.host == "example.com"
        }, withStubResponse: { _ in
            OHHTTPStubsResponse(jsonObject: json, statusCode: 200, headers: nil)
        })

        let p = URLSession.shared.GET("http://example.com", query: [
            "1": 1,
            "2": 2
        ])

        let ex = expectation(description: "")
        p.compactMap {
            try JSONSerialization.jsonObject(with: $0.data)
        }.done {
            XCTAssertEqual(json, $0 as? NSDictionary)
            ex.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
    
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
    }
}
