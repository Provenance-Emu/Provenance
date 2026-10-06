import XCTest
@testable import PVLibrary

final class BackgroundActivityTests: XCTestCase {
    func testReturnsTheWorkResult() async {
        let value = await BackgroundActivity.run("test") { 42 }
        XCTAssertEqual(value, 42)
    }

    func testRunsAwaitedWorkToCompletion() async {
        let value = await BackgroundActivity.run("test") { () async -> String in
            try? await Task.sleep(nanoseconds: 10_000_000)
            return "done"
        }
        XCTAssertEqual(value, "done")
    }

    /// Each run holds a thread inside `performExpiringActivity` until its work
    /// returns. Back-to-back runs must each release theirs, or they would
    /// exhaust the dispatch thread pool.
    func testManySequentialRunsDoNotHang() async {
        for index in 0..<200 {
            let value = await BackgroundActivity.run("test") { index }
            XCTAssertEqual(value, index)
        }
    }

    func testConcurrentRunsAllComplete() async {
        let total = await withTaskGroup(of: Int.self) { group in
            for index in 0..<50 {
                group.addTask { await BackgroundActivity.run("test") { index } }
            }
            return await group.reduce(0, +)
        }
        XCTAssertEqual(total, (0..<50).reduce(0, +))
    }
}
