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

    func testRunSyncRequiringGrantRunsWhenGranted() throws {
        XCTAssertEqual(try BackgroundActivity.runSyncRequiringGrant("test") { 5 }, 5)
    }

    // MARK: - SharedAssertion

    func testRefusedActivityDoesNotStartWorkThatRequiresIt() {
        let system = FakeActivitySystem(answer: .refuse)
        let shared = SharedAssertion(request: system.request)

        XCTAssertFalse(shared.begin("test", waitForGrant: true))
        // The refused caller left again: the next one asks iOS afresh.
        system.answer = .grant
        XCTAssertTrue(shared.begin("test", waitForGrant: true))
        shared.end()
        XCTAssertEqual(system.requestCount, 2)
    }

    func testRefusedActivityStillRunsWorkThatDoesNotRequireIt() {
        let system = FakeActivitySystem(answer: .refuse)
        let shared = SharedAssertion(request: system.request)

        XCTAssertTrue(shared.begin("test"))
        shared.end()
    }

    /// The crash this guards against: iOS revoked the activity during a commit, the
    /// assertion was released at once, and the process was suspended mid-commit.
    func testRevocationKeepsTheActivityUntilTheLastCallerEnds() {
        let system = FakeActivitySystem(answer: .grant)
        let shared = SharedAssertion(request: system.request)

        XCTAssertTrue(shared.begin("test", waitForGrant: true))
        system.waitUntilHeld()
        system.expire()
        XCTAssertTrue(system.isHeld, "released while a caller was still working")
        // Nothing new may start once iOS has taken the activity back.
        XCTAssertFalse(shared.begin("test", waitForGrant: true))
        XCTAssertTrue(system.isHeld)

        shared.end()
        system.waitUntilReleased()
        XCTAssertFalse(system.isHeld)
    }

    func testUnansweredRequestIsTreatedAsGranted() {
        let system = FakeActivitySystem(answer: .ignore)
        let shared = SharedAssertion(grantTimeout: 0.05, request: system.request)

        XCTAssertTrue(shared.begin("test", waitForGrant: true))
        shared.end()
    }
}

/// Stands in for `ProcessInfo.performExpiringActivity`.
private final class FakeActivitySystem: @unchecked Sendable {
    enum Answer { case grant, refuse, ignore }

    private let condition = NSCondition()
    private var held = false
    private var requests = 0
    private var block: (@Sendable (Bool) -> Void)?
    private var storedAnswer: Answer

    init(answer: Answer) { storedAnswer = answer }

    var answer: Answer {
        get { locked { storedAnswer } }
        set { locked { storedAnswer = newValue } }
    }

    var isHeld: Bool { locked { held } }
    var requestCount: Int { locked { requests } }

    var request: SharedAssertion.Requester {
        { [self] _, block in
            let answer: Answer = locked {
                requests += 1
                self.block = block
                return storedAnswer
            }
            switch answer {
            case .ignore:
                break
            case .refuse:
                block(true)
            case .grant:
                Thread.detachNewThread { [self] in
                    setHeld(true)
                    block(false)
                    setHeld(false)
                }
            }
        }
    }

    /// iOS takes the activity back, as it does shortly before suspending the process.
    func expire() {
        let block = locked { self.block }
        block?(true)
    }

    func waitUntilHeld() { wait(for: true) }
    func waitUntilReleased() { wait(for: false) }

    private func wait(for value: Bool) {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date(timeIntervalSinceNow: 5)
        while held != value {
            guard condition.wait(until: deadline) else { return }
        }
    }

    private func setHeld(_ value: Bool) {
        condition.lock()
        held = value
        condition.broadcast()
        condition.unlock()
    }

    private func locked<T>(_ body: () -> T) -> T {
        condition.lock()
        defer { condition.unlock() }
        return body()
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
