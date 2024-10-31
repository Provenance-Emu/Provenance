//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 5/14/24.
//

import XCTest
@testable import PVHashing

class ChecksumTests: XCTestCase {

    let testFileURL = Bundle.module.url(forResource: "testFile", withExtension: "txt")!

    override func setUpWithError() throws {
        super.setUp()
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//        // Create test file if necessary
//        let text = "Hello, world!"
//        try text.write(to: testFileURL, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        // Clean up any resources here, such as deleting test files
//        try FileManager.default.removeItem(at: testFileURL)
    }

    func testUsingResourceFile() {
        let bundle = Bundle.module
        let url = bundle.url(forResource: "testFile", withExtension: "txt")!
        let content = try! String(contentsOf: url)
    }

    func testCalculateMD5Asynchronously() throws {
        let expectation = XCTestExpectation(description: "Calculate MD5 asynchronously")

        _ = calculateMD5(of: testFileURL)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Failed with error: \(error)")
                }
            }, receiveValue: { md5Hash in
                XCTAssertEqual(md5Hash, "746308829575e17c3331bbcb00c0898b")
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 5.0)
    }

    func testCalculateMD5Synchronously() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "746308829575e17c3331bbcb00c0898b"
        do {
            let md5Hash = try calculateMD5Synchronously(of: testFileURL)
            XCTAssertEqual(md5Hash, expectedHash, "The MD5 hash did not match the expected value.")
        } catch {
            XCTFail("Failed with error: \(error)")
        }
    }

    func testStringMD5() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "6cd3556deb0da54bca060b4c39479839"
        let testString = "Hello, world!"
        XCTAssertEqual(expectedHash, testString.MD5)
    }

    func testDataMD5() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "6cd3556deb0da54bca060b4c39479839"
        let testString = "Hello, world!"
        let testData = testString.data(using: .utf8)!
        XCTAssertEqual(expectedHash, testData.md5)
    }

    func testDataSha1() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "943a702d06f34599aee1f8da8ef9f7296031d699"
        let testString = "Hello, world!"
        let testData = testString.data(using: .utf8)!
        XCTAssertEqual(expectedHash, testData.sha1)
    }

    func testNSDataMD5() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "6cd3556deb0da54bca060b4c39479839"
        let testString = "Hello, world!"
        let testData: NSData = testString.data(using: .utf8)! as NSData
        XCTAssertEqual(expectedHash, testData.md5)
    }

    func testNSDataSha1() {
        // This hash corresponds to "Hello, world!" with MD5
        let expectedHash = "943a702d06f34599aee1f8da8ef9f7296031d699"
        let testString = "Hello, world!"
        let testData: NSData = testString.data(using: .utf8)! as NSData
        XCTAssertEqual(expectedHash, testData.sha1)
    }
}
