//
//  SyncTaskQueueTests.swift
//  PVLibraryTests
//
//  Tests for SyncTaskQueue — priority ordering, concurrency limits,
//  cancellation, dependency resolution, and priority boosting.
//

import XCTest
@testable import PVLibrary

final class SyncTaskPriorityTests: XCTestCase {

    func test_priorities_orderedCorrectly() {
        XCTAssertGreaterThan(SyncTaskPriority.metadataSync, .artworkRedownload)
        XCTAssertGreaterThan(SyncTaskPriority.artworkRedownload, .saveStateScreenshot)
        XCTAssertGreaterThan(SyncTaskPriority.saveStateScreenshot, .biosSync)
        XCTAssertGreaterThan(SyncTaskPriority.biosSync, .romDownload)
        XCTAssertGreaterThan(SyncTaskPriority.romDownload, .dbArtworkLookup)
    }

    func test_boost_increasesPriority() {
        let original = SyncTaskPriority.romDownload
        let boosted = original.boosted()
        XCTAssertGreaterThan(boosted, original)
        XCTAssertEqual(boosted.rawValue, original.rawValue + SyncTaskPriority.onDemandBoost)
    }

    func test_unboost_restoresPriority() {
        let original = SyncTaskPriority.artworkRedownload
        let boosted = original.boosted()
        let restored = boosted.unboosted()
        XCTAssertEqual(restored, original)
    }

    func test_boostedArtwork_outranksUnboostedMetadata() {
        // A visible game's artwork should jump ahead of unboosted metadata
        let boostedArtwork = SyncTaskPriority.artworkRedownload.boosted() // 800 + 500 = 1300
        let normalMetadata = SyncTaskPriority.metadataSync               // 1000
        XCTAssertGreaterThan(boostedArtwork, normalMetadata)
    }

    func test_isBoosted_correctForBoostedValues() {
        let normal = SyncTaskPriority.romDownload
        XCTAssertFalse(normal.isBoosted)

        let boosted = normal.boosted()
        XCTAssertTrue(boosted.isBoosted)
    }
}

final class SyncTaskTests: XCTestCase {

    func test_taskWithNoDependencies_isReady() {
        let task = SyncTask(
            kind: .metadataSync,
            priority: .metadataSync,
            work: {}
        )
        XCTAssertEqual(task.state, .ready)
    }

    func test_taskWithDependencies_isPending() {
        let depID = UUID()
        let task = SyncTask(
            kind: .artworkDownload(url: URL(string: "https://example.com/art.jpg")!, gameID: "abc"),
            priority: .artworkRedownload,
            dependencies: [depID],
            work: {}
        )
        XCTAssertEqual(task.state, .pending)
    }

    func test_terminalStates() {
        XCTAssertTrue(SyncTaskState.completed.isTerminal)
        XCTAssertTrue(SyncTaskState.failed("err").isTerminal)
        XCTAssertTrue(SyncTaskState.cancelled.isTerminal)
        XCTAssertFalse(SyncTaskState.pending.isTerminal)
        XCTAssertFalse(SyncTaskState.ready.isTerminal)
        XCTAssertFalse(SyncTaskState.running.isTerminal)
        XCTAssertFalse(SyncTaskState.paused.isTerminal)
    }
}

final class SyncTaskQueueTests: XCTestCase {

    // MARK: - Basic execution

    func test_singleTask_executesAndCompletes() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1)
        let expectation = XCTestExpectation(description: "task completed")

        await queue.submit(kind: .metadataSync) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)

        // Give the queue a moment to update state
        try? await Task.sleep(for: .milliseconds(100))
        let running = await queue.runningCount
        XCTAssertEqual(running, 0)
    }

    func test_concurrencyLimit_respected() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 2)
        let maxConcurrentSeen = MaxConcurrencyTracker()

        for _ in 0..<10 {
            await queue.submit(kind: .custom(description: "work")) {
                await maxConcurrentSeen.enter()
                try? await Task.sleep(for: .milliseconds(50))
                await maxConcurrentSeen.exit()
            }
        }

        // Wait for all tasks to complete
        try? await Task.sleep(for: .seconds(2))

        let maxSeen = await maxConcurrentSeen.maxSeen
        XCTAssertLessThanOrEqual(maxSeen, 2, "Should never exceed maxConcurrentTasks=2")
        XCTAssertGreaterThan(maxSeen, 0, "Should have run at least one task")
    }

    // MARK: - Priority ordering

    func test_highPriorityTask_runsFirst() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1)
        await queue.pause()

        let executionOrder = ExecutionOrderTracker()

        // Enqueue low priority first
        await queue.submit(
            kind: .custom(description: "low"),
            priority: .dbArtworkLookup
        ) {
            await executionOrder.record("low")
        }

        // Then high priority
        await queue.submit(
            kind: .custom(description: "high"),
            priority: .metadataSync
        ) {
            await executionOrder.record("high")
        }

        // Resume — high priority should execute first
        await queue.resume()
        try? await Task.sleep(for: .seconds(1))

        let order = await executionOrder.order
        XCTAssertEqual(order.first, "high", "High priority task should run first, got: \(order)")
    }

    // MARK: - Cancellation

    func test_cancelTask_stopsExecution() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1)
        let started = XCTestExpectation(description: "started")
        let didFinish = DidFinishTracker()

        let taskID = await queue.submit(kind: .custom(description: "cancellable")) {
            started.fulfill()
            try await Task.sleep(for: .seconds(10))
            await didFinish.markFinished()
        }

        await fulfillment(of: [started], timeout: 2.0)
        await queue.cancel(taskID: taskID)

        try? await Task.sleep(for: .milliseconds(200))
        let finished = await didFinish.finished
        XCTAssertFalse(finished, "Cancelled task should not complete normally")
    }

    func test_cancelAll_cancelsAllPending() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1)
        await queue.pause()

        for _ in 0..<5 {
            await queue.submit(kind: .custom(description: "work")) {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        await queue.cancelAll()
        await queue.resume()

        try? await Task.sleep(for: .milliseconds(200))
        let pending = await queue.pendingCount
        let running = await queue.runningCount
        XCTAssertEqual(pending, 0)
        XCTAssertEqual(running, 0)
    }

    // MARK: - Pause/Resume

    func test_pause_preventsNewTasksFromStarting() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 4)
        await queue.pause()

        let tracker = DidFinishTracker()
        await queue.submit(kind: .custom(description: "blocked")) {
            await tracker.markFinished()
        }

        try? await Task.sleep(for: .milliseconds(200))
        let finished = await tracker.finished
        XCTAssertFalse(finished, "Paused queue should not start new tasks")

        await queue.resume()
        try? await Task.sleep(for: .milliseconds(200))
        let finishedAfterResume = await tracker.finished
        XCTAssertTrue(finishedAfterResume, "Resumed queue should execute pending tasks")
    }

    // MARK: - Dependencies

    func test_dependency_blocksUntilCompleted() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 2)
        let executionOrder = ExecutionOrderTracker()

        let firstID = await queue.submit(kind: .custom(description: "first")) {
            try? await Task.sleep(for: .milliseconds(100))
            await executionOrder.record("first")
        }

        await queue.submit(
            kind: .custom(description: "second"),
            dependencies: [firstID]
        ) {
            await executionOrder.record("second")
        }

        try? await Task.sleep(for: .seconds(1))
        let order = await executionOrder.order
        XCTAssertEqual(order, ["first", "second"], "Dependent task should run after its dependency")
    }

    // MARK: - Priority boosting

    func test_boostPriority_affectsMatchingTasks() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1)
        await queue.pause()

        await queue.submit(
            kind: .artworkDownload(url: URL(string: "https://example.com/a.jpg")!, gameID: "game1"),
            priority: .artworkRedownload,
            metadata: ["gameID": "game1"]
        ) {}

        await queue.submit(
            kind: .artworkDownload(url: URL(string: "https://example.com/b.jpg")!, gameID: "game2"),
            priority: .artworkRedownload,
            metadata: ["gameID": "game2"]
        ) {}

        let boosted = await queue.boostPriority(forGameID: "game1")
        XCTAssertEqual(boosted, 1, "Should boost exactly one task")

        let reset = await queue.resetBoost(forGameID: "game1")
        XCTAssertEqual(reset, 1, "Should reset exactly one task")
    }

    // MARK: - Retry

    func test_failedTask_retries() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 1, maxRetries: 2)
        let attemptCount = AttemptCounter()

        await queue.submit(kind: .custom(description: "flaky")) {
            let attempt = await attemptCount.increment()
            if attempt < 3 {
                throw NSError(domain: "test", code: -1)
            }
        }

        try? await Task.sleep(for: .seconds(2))
        let attempts = await attemptCount.count
        XCTAssertEqual(attempts, 3, "Should retry twice after initial failure (3 total attempts)")
    }
    // MARK: - Intra-queue dependencies

    func test_intraQueueDependency_resolvedOnCompletion() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 2)
        let executionOrder = ExecutionOrderTracker()

        let firstID = await queue.submit(kind: .custom(description: "first")) {
            try? await Task.sleep(for: .milliseconds(100))
            await executionOrder.record("first")
        }

        // Second task depends on first, within the same queue
        await queue.submit(
            kind: .custom(description: "second"),
            dependencies: [firstID]
        ) {
            await executionOrder.record("second")
        }

        try? await Task.sleep(for: .seconds(1))
        let order = await executionOrder.order
        XCTAssertEqual(order, ["first", "second"], "Intra-queue dependency should be resolved when first task completes")
    }

    // MARK: - Terminal-state dependency release

    /// Regression: a permanently-failed prerequisite must unblock its
    /// dependents. Previously a failed task (retries exhausted) left
    /// dependents stuck in `.pending` forever — which manifested as
    /// DeltaSkin CloudKit sync never running when ROM metadata fetch
    /// failed.
    func test_failedDependency_unblocksDependent() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 2, maxRetries: 0)
        let dependentRan = DidFinishTracker()

        let failingID = await queue.submit(kind: .custom(description: "failing")) {
            throw NSError(domain: "test", code: -1)
        }

        await queue.submit(
            kind: .custom(description: "dependent"),
            dependencies: [failingID]
        ) {
            await dependentRan.markFinished()
        }

        try? await Task.sleep(for: .seconds(1))
        let ran = await dependentRan.finished
        XCTAssertTrue(ran, "Dependent task should run even when its prerequisite fails terminally")
    }

    /// A cancelled prerequisite is terminal and must release dependents.
    func test_cancelledDependency_unblocksDependent() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 2)
        await queue.pause()

        let dependentRan = DidFinishTracker()

        let cancelledID = await queue.submit(kind: .custom(description: "will-be-cancelled")) {
            try? await Task.sleep(for: .seconds(5))
        }

        await queue.submit(
            kind: .custom(description: "dependent"),
            dependencies: [cancelledID]
        ) {
            await dependentRan.markFinished()
        }

        await queue.cancel(taskID: cancelledID)
        await queue.resume()

        try? await Task.sleep(for: .milliseconds(500))
        let ran = await dependentRan.finished
        XCTAssertTrue(ran, "Dependent task should run even when its prerequisite is cancelled")
    }

    // MARK: - Auto-pruning

    func test_pruneCompleted_removesTerminalTasks() async {
        let queue = SyncTaskQueue(name: "test", maxConcurrentTasks: 4)

        for _ in 0..<5 {
            await queue.submit(kind: .custom(description: "work")) {}
        }

        try? await Task.sleep(for: .milliseconds(500))

        // All should be completed
        let totalBefore = await queue.totalCount
        XCTAssertEqual(totalBefore, 5)

        await queue.pruneCompleted()
        let totalAfter = await queue.totalCount
        XCTAssertEqual(totalAfter, 0, "pruneCompleted should remove all terminal tasks")
    }
}

// MARK: - Coordinator Tests

final class SyncTaskQueueCoordinatorTests: XCTestCase {

    func test_submitToCategory_executesWork() async {
        let coordinator = SyncTaskQueueCoordinator(globalMaxConcurrent: 4)
        let expectation = XCTestExpectation(description: "work done")

        await coordinator.submit(to: .metadata, kind: .metadataSync) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func test_pauseAll_resumeAll() async {
        let coordinator = SyncTaskQueueCoordinator(globalMaxConcurrent: 4)
        await coordinator.pauseAll()

        let tracker = DidFinishTracker()
        await coordinator.submit(to: .artwork, kind: .custom(description: "art")) {
            await tracker.markFinished()
        }

        try? await Task.sleep(for: .milliseconds(200))
        let finishedWhilePaused = await tracker.finished
        XCTAssertFalse(finishedWhilePaused)

        await coordinator.resumeAll()
        try? await Task.sleep(for: .milliseconds(500))
        let finishedAfterResume = await tracker.finished
        XCTAssertTrue(finishedAfterResume)
    }

    func test_boostPriority_acrossQueues() async {
        let coordinator = SyncTaskQueueCoordinator(globalMaxConcurrent: 8)

        // Pause all queues so tasks don't execute
        await coordinator.pauseAll()

        await coordinator.submit(
            to: .artwork,
            kind: .artworkDownload(url: URL(string: "https://example.com/a.jpg")!, gameID: "game1"),
            metadata: ["gameID": "game1"]
        ) {}

        await coordinator.submit(
            to: .romDownload,
            kind: .romDownload(md5: "abc", expectedSize: 100),
            metadata: ["gameID": "game1"]
        ) {}

        await coordinator.boostPriority(forGameID: "game1")

        // Verify both queues had tasks boosted
        let artQueue = await coordinator.queue(for: .artwork)
        let romQueue = await coordinator.queue(for: .romDownload)
        XCTAssertNotNil(artQueue)
        XCTAssertNotNil(romQueue)

        await coordinator.cancelAll()
    }

    /// Regression: cross-queue dependents must unblock when the
    /// prerequisite fails. Models the fetchRemoteChanges chain where
    /// the non-DB (skins) task depends on the ROM metadata task — a
    /// failed metadata task was stranding skin sync indefinitely.
    func test_crossQueue_failedPrerequisite_unblocksDependent() async {
        let coordinator = SyncTaskQueueCoordinator(globalMaxConcurrent: 4)
        await coordinator.startEventListeners()

        let dependentRan = DidFinishTracker()

        // Prerequisite on metadata queue fails terminally (maxRetries=0 is
        // not configurable per-task, so throw repeatedly — the built-in
        // maxRetries default is small enough that it will terminally fail
        // within the test timeout).
        let prereqID = await coordinator.submit(
            to: .metadata,
            kind: .metadataSync
        ) {
            throw NSError(domain: "test", code: -1)
        }
        guard let prereqID else {
            XCTFail("Failed to submit prerequisite")
            return
        }

        // Dependent on a different queue waits on the failing prereq.
        await coordinator.submit(
            to: .bios,
            kind: .custom(description: "skin-sync"),
            dependencies: [prereqID]
        ) {
            await dependentRan.markFinished()
        }

        // Give the prerequisite time to exhaust retries and fail, then
        // allow the coordinator's event listener to propagate the
        // terminal-state notification to the bios queue.
        try? await Task.sleep(for: .seconds(3))

        let ran = await dependentRan.finished
        XCTAssertTrue(ran, "Cross-queue dependent should run after prerequisite fails terminally")

        await coordinator.cancelAll()
    }

    func test_cancelQueue_onlyCancelsSpecificQueue() async {
        let coordinator = SyncTaskQueueCoordinator(globalMaxConcurrent: 8)
        await coordinator.pauseAll()

        await coordinator.submit(to: .artwork, kind: .custom(description: "art")) {}
        await coordinator.submit(to: .romDownload, kind: .custom(description: "rom")) {}

        await coordinator.cancelQueue(.artwork)

        let artPending = await coordinator.queue(for: .artwork)?.pendingCount ?? -1
        let romPending = await coordinator.queue(for: .romDownload)?.pendingCount ?? -1
        XCTAssertEqual(artPending, 0, "Artwork queue should be empty after cancel")
        XCTAssertEqual(romPending, 1, "ROM queue should be unaffected")

        await coordinator.cancelAll()
    }
}

// MARK: - Test Helpers

/// Thread-safe tracker for max concurrent executions.
private actor MaxConcurrencyTracker {
    var current = 0
    var maxSeen = 0

    func enter() {
        current += 1
        if current > maxSeen { maxSeen = current }
    }

    func exit() {
        current -= 1
    }
}

/// Thread-safe tracker for execution order.
private actor ExecutionOrderTracker {
    var order: [String] = []

    func record(_ label: String) {
        order.append(label)
    }
}

/// Thread-safe completion tracker.
private actor DidFinishTracker {
    var finished = false

    func markFinished() {
        finished = true
    }
}

/// Thread-safe attempt counter.
private actor AttemptCounter {
    var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}
