//
//  FileStabilityCheckerTests.swift
//  PVLibraryTests
//
//  Tests for kqueue-based file stability detection.
//

import XCTest
@testable import PVLibrary

final class FileStabilityCheckerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileStabilityCheckerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try FileManager.default.removeItem(at: tempDir)
        }
        try super.tearDownWithError()
    }

    /// A file that already exists and isn't being written to should
    /// stabilize almost immediately (within the quiesce interval).
    func testImmediateStability() async throws {
        let file = tempDir.appendingPathComponent("stable.bin")
        try Data(repeating: 0xAA, count: 1024).write(to: file)

        let start = Date()
        let result = await FileStabilityChecker.waitForStability(
            at: file, quiesceInterval: 0.2, timeout: 5.0
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertTrue(result, "File should be detected as stable")
        XCTAssertLessThan(elapsed, 2.0, "Stable file should resolve quickly")
    }

    /// When a file is continuously written to, the checker should
    /// time out and return `false`. Time is driven by a manual clock: each
    /// step appends to the file, waits until the checker has re-armed its
    /// quiesce timer, then advances by half the quiesce window, so the quiet
    /// period can never elapse however slowly the runner schedules the test.
    func testTimeoutOnContinuousWrites() async throws {
        let file = tempDir.appendingPathComponent("busy.bin")
        try Data(repeating: 0xBB, count: 64).write(to: file)
        let clock = ManualStabilityClock()

        let check = Task {
            await FileStabilityChecker.waitForStability(
                at: file, quiesceInterval: 2, timeout: 10, scheduler: clock
            )
        }
        // The hard timeout and the first quiesce timer.
        try await clock.waitForSchedules(atLeast: 2)

        for _ in 0..<10 {
            let armed = clock.scheduleCount
            try append(Data(repeating: 0xCC, count: 8), to: file)
            try await clock.waitForSchedules(atLeast: armed + 1)
            clock.advance(by: 1)
        }

        let result = await check.value
        XCTAssertFalse(result, "Continuously written file should time out")
    } // testTimeoutOnContinuousWrites

    /// Control for the timeout test: on the same clock, once the writes
    /// stop the file is reported stable after one quiet window, before the
    /// timeout. Shows the manual clock does not force a timeout by itself.
    func testStableOnceWritesStop() async throws {
        let file = tempDir.appendingPathComponent("settling.bin")
        try Data(repeating: 0xBB, count: 64).write(to: file)
        let clock = ManualStabilityClock()

        let check = Task {
            await FileStabilityChecker.waitForStability(
                at: file, quiesceInterval: 2, timeout: 10, scheduler: clock
            )
        }
        try await clock.waitForSchedules(atLeast: 2)

        for _ in 0..<3 {
            let armed = clock.scheduleCount
            try append(Data(repeating: 0xCC, count: 8), to: file)
            try await clock.waitForSchedules(atLeast: armed + 1)
            clock.advance(by: 1)
        }
        clock.advance(by: 2)

        let result = await check.value
        XCTAssertTrue(result, "File should be stable once writes stop")
    }

    /// Cancelling the enclosing Task should cause `waitForStability`
    /// to return `false` promptly and release resources. The manual clock
    /// never advances, so no timer can fire: `false` can only come from
    /// cancellation.
    func testTaskCancellation() async throws {
        let file = tempDir.appendingPathComponent("cancel.bin")
        try Data(repeating: 0xDD, count: 64).write(to: file)
        let clock = ManualStabilityClock()

        let start = Date()
        let stabilityTask = Task {
            await FileStabilityChecker.waitForStability(
                at: file, quiesceInterval: 2, timeout: 10, scheduler: clock
            )
        }
        try await clock.waitForSchedules(atLeast: 2)

        stabilityTask.cancel()
        let result = await stabilityTask.value
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(result, "Cancelled task should return false")
        XCTAssertLessThan(elapsed, 5.0, "Cancellation should resolve promptly")
    }

    /// When the file doesn't exist (open fails), the checker should
    /// return `true` optimistically so callers proceed to their own
    /// readability checks.
    func testNonexistentFileReturnsTrue() async {
        let file = tempDir.appendingPathComponent("does-not-exist.bin")
        let result = await FileStabilityChecker.waitForStability(at: file)
        XCTAssertTrue(result, "Missing file should return true (proceed optimistically)")
    }

    private func append(_ data: Data, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}

/// Virtual clock for `FileStabilityChecker`. Timers only fire when the test
/// calls `advance(by:)`, which hands every due, uncancelled item to the
/// checker's queue in deadline order.
private final class ManualStabilityClock: StabilityTimerScheduler, @unchecked Sendable {
    /// Real time allowed for the checker to arm a timer before the test fails.
    private static let scheduleWaitLimit: TimeInterval = 10
    private static let schedulePollNanoseconds: UInt64 = 5_000_000

    private struct Pending {
        let deadline: TimeInterval
        let queue: DispatchQueue
        let work: DispatchWorkItem
    }

    private let lock = NSLock()
    private var now: TimeInterval = 0
    private var pending: [Pending] = []
    private var count = 0

    /// Timers scheduled so far, including ones since cancelled.
    var scheduleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func schedule(after interval: TimeInterval, on queue: DispatchQueue, _ work: DispatchWorkItem) {
        lock.lock()
        defer { lock.unlock() }
        pending.append(Pending(deadline: now + interval, queue: queue, work: work))
        count += 1
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        now += interval
        let due = pending.filter { $0.deadline <= now }.sorted { $0.deadline < $1.deadline }
        pending.removeAll { $0.deadline <= now }
        lock.unlock()
        for item in due where !item.work.isCancelled {
            item.queue.async(execute: item.work)
        }
    }

    func waitForSchedules(atLeast target: Int, file: StaticString = #filePath, line: UInt = #line) async throws {
        let limit = Date().addingTimeInterval(Self.scheduleWaitLimit)
        while scheduleCount < target {
            guard Date() < limit else {
                XCTFail("Checker armed \(scheduleCount) timers, expected \(target)", file: file, line: line)
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: Self.schedulePollNanoseconds)
        }
    }
}
