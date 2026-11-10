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

    func testRunSyncReturnsTheWorkResult() {
        XCTAssertEqual(BackgroundActivity.runSync("test") { 42 }, 42)
    }

    func testRunSyncRethrows() {
        struct Failure: Error {}
        XCTAssertThrowsError(try BackgroundActivity.runSync("test") { throw Failure() })
        // The shared assertion was released: a later call still runs.
        XCTAssertEqual(BackgroundActivity.runSync("test") { 1 }, 1)
    }

    func testNestedRunSyncDoesNotDeadlock() {
        let value = BackgroundActivity.runSync("outer") {
            BackgroundActivity.runSync("inner") { 7 }
        }
        XCTAssertEqual(value, 7)
    }

    /// Overlapping jobs share one assertion; every job must still run and release it.
    func testConcurrentRunSyncAllComplete() {
        let counter = Counter()
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            counter.add(BackgroundActivity.runSync("test") { index })
        }
        XCTAssertEqual(counter.total, (0..<200).reduce(0, +))
        XCTAssertEqual(BackgroundActivity.runSync("test") { 3 }, 3)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var sum = 0

    var total: Int {
        lock.lock()
        defer { lock.unlock() }
        return sum
    }

    func add(_ value: Int) {
        lock.lock()
        defer { lock.unlock() }
        sum += value
    }
}
