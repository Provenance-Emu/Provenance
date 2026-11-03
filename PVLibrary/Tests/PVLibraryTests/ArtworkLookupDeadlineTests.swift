import XCTest
@testable import PVLibrary

final class ArtworkLookupDeadlineTests: XCTestCase {
    private actor Provider {
        private var continuation: CheckedContinuation<String?, Never>?
        private var released = false

        func lookup() async -> String? {
            if released { return "late" }
            return await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume(returning: "late")
            continuation = nil
        }
    }

    func testTimeoutDoesNotWaitForUncooperativeProvider() async {
        let provider = Provider()
        let returned = expectation(description: "importer released before provider")
        let task = Task {
            let result = await ArtworkLookupDeadline.value(timeoutNanoseconds: 20_000_000) {
                await provider.lookup()
            }
            XCTAssertNil(result)
            returned.fulfill()
        }
        await fulfillment(of: [returned], timeout: 1)
        // Release only after the deadline assertion, including on failure, to avoid leaked tasks.
        await provider.release()
        await task.value
    }

    func testCallerCancellationReleasesUncooperativeProvider() async {
        let provider = Provider()
        let returned = expectation(description: "cancelled importer released")
        let task = Task {
            let result = await ArtworkLookupDeadline.value(timeoutNanoseconds: 60_000_000_000) {
                await provider.lookup()
            }
            XCTAssertNil(result)
            returned.fulfill()
        }
        task.cancel()
        await fulfillment(of: [returned], timeout: 1)
        await provider.release()
        await task.value
    }

    func testImmediateSuccessWinsAndCancelsDeadline() async {
        let result = await ArtworkLookupDeadline.value(timeoutNanoseconds: 60_000_000_000) { "cover" }
        XCTAssertEqual(result, "cover")
    }

    func testImmediateNoMatchWins() async {
        let result = await ArtworkLookupDeadline.value(timeoutNanoseconds: 60_000_000_000) { nil }
        XCTAssertNil(result)
    }

    func testSimultaneousCompletionResumesExactlyOnce() async {
        for _ in 0..<100 {
            let result = await ArtworkLookupDeadline.value(timeoutNanoseconds: 0) { "cover" }
            XCTAssertTrue(result == nil || result == "cover")
        }
    }
}
