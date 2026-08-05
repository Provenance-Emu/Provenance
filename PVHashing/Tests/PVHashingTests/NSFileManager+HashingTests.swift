//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 5/14/24.
//

import XCTest
#if canImport(Combine)
import Combine
#endif
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

    #if canImport(Combine)
    func testCalculateMD5Asynchronously() throws {
        let expectation = XCTestExpectation(description: "Calculate MD5 asynchronously")

        // The cancellable must be retained for the duration of the wait: discarding
        // it (`_ = ...sink`) cancels the subscription immediately, so the value never
        // arrives and this test times out unconditionally — which is exactly how it
        // sat broken on develop, unnoticed because CI only tests changed modules.
        let subscription = calculateMD5(of: testFileURL)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Failed with error: \(error)")
                }
            }, receiveValue: { md5Hash in
                // The hashing APIs return UPPERCASE hex (see calculateMD5Attempt and
                // the async-await tests below asserting the same hash uppercased).
                XCTAssertEqual(md5Hash, "746308829575E17C3331BBCB00C0898B")
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 5.0)
        subscription.cancel()
    }
    #endif

    func testCalculateMD5Synchronously() {
        // MD5 of the test file — the API contract is UPPERCASE hex, matching
        // testCalculateMD5WithAsyncAwait / testURLMD5Async above this same hash.
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
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

    // MARK: - Async/await tests

    func testCalculateMD5WithAsyncAwait() async throws {
        // MD5 of the test file ("Hello, world!\n")
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        let md5Hash = try await calculateMD5Async(of: testFileURL)
        XCTAssertEqual(md5Hash, expectedHash)
    }

    func testURLMD5Async() async throws {
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        let md5Hash = try await testFileURL.md5Async()
        XCTAssertEqual(md5Hash, expectedHash)
    }

    func testCalculateMD5AsyncWithOffset() async throws {
        // Hashing from offset 0 should equal a full-file hash.
        let full = try await calculateMD5Async(of: testFileURL)
        let fromZero = try await calculateMD5Async(of: testFileURL, startingAt: 0)
        XCTAssertEqual(full, fromZero)
    }

    // MARK: - Streaming API tests

    func testCalculateMD5StreamCompletedEvent() async throws {
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        var lastEvent: MD5HashingEvent?

        for try await event in calculateMD5Stream(of: testFileURL) {
            lastEvent = event
        }

        guard case .completed(let hash) = lastEvent else {
            XCTFail("Expected a .completed event as the last stream event")
            return
        }
        XCTAssertEqual(hash, expectedHash)
    }

    func testCalculateMD5StreamProgressEvents() async throws {
        var progressSeen = false

        // Check file size to determine if progress events are expected
        let attributes = try FileManager.default.attributesOfItem(atPath: testFileURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let bufferSize: UInt64 = 1024 * 1024 // 1 MB

        for try await event in calculateMD5Stream(of: testFileURL) {
            if case .progress(let bytesProcessed, let totalBytes) = event {
                progressSeen = true
                XCTAssertGreaterThan(bytesProcessed, 0)
                XCTAssertGreaterThanOrEqual(totalBytes, bytesProcessed)
            }
        }

        // Only assert progress for files larger than buffer size
        if fileSize >= bufferSize {
            XCTAssertTrue(progressSeen, "Expected progress events for file larger than 1 MB")
        }
        // For small files, at least verify the stream completed without crash
    }

    func testURLMD5Stream() async throws {
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        var lastEvent: MD5HashingEvent?

        for try await event in testFileURL.md5Stream() {
            lastEvent = event
        }

        guard case .completed(let hash) = lastEvent else {
            XCTFail("Expected a .completed event as the last stream event")
            return
        }
        XCTAssertEqual(hash, expectedHash)
    }

    // MARK: - MD5Provider protocol async tests

    func testFileManagerMD5ProviderAsync() async throws {
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        let hash = try await FileManager.default.md5ForFileAsync(at: testFileURL)
        XCTAssertEqual(hash, expectedHash)
    }

    func testFileManagerMD5ProviderStream() async throws {
        let expectedHash = "746308829575E17C3331BBCB00C0898B"
        var completedHash: String?

        for try await event in FileManager.default.md5StreamForFile(at: testFileURL) {
            if case .completed(let hash) = event {
                completedHash = hash
            }
        }

        XCTAssertEqual(completedHash, expectedHash)
    }
}
