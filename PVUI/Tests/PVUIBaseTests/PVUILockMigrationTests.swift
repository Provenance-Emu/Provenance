import Testing
import os
import Foundation

/// Tests verifying the OSAllocatedUnfairLock migration from NSLock/objc_sync patterns.
///
/// These tests exercise the lock semantics in isolation — no Realm or UIKit needed.
/// They validate:
/// - withLock { } guards critical sections from concurrent mutation
/// - withLock { } returns values correctly (used to replace bare lock/unlock pairs)
/// - Re-entrance is NOT attempted (OSAllocatedUnfairLock is non-reentrant by design)
@Suite("Lock Migration Tests — OSAllocatedUnfairLock")
struct PVUILockMigrationTests {

    // MARK: - withLock returns value

    @Test("withLock correctly returns computed value")
    func withLockReturnsValue() {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var counter = 0

        let result = lock.withLock { () -> Int in
            counter += 1
            return counter
        }

        #expect(result == 1)
        #expect(counter == 1)
    }

    @Test("withLock returns Bool for test-and-set pattern")
    func withLockTestAndSet() {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var didPost = false

        // Simulates the markFramePresented() first-frame pattern
        let shouldPost = lock.withLock { () -> Bool in
            let result = !didPost
            if result { didPost = true }
            return result
        }

        #expect(shouldPost == true)
        #expect(didPost == true)

        // Second call: shouldPost should be false
        let shouldPost2 = lock.withLock { () -> Bool in
            let result = !didPost
            if result { didPost = true }
            return result
        }

        #expect(shouldPost2 == false)
    }

    // MARK: - Concurrent mutation safety

    @Test("withLock serialises concurrent mutations to a counter")
    func concurrentCounterSafety() async {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var counter = 0
        let iterations = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    lock.withLock { counter += 1 }
                }
            }
        }

        #expect(counter == iterations)
    }

    @Test("withLock serialises concurrent writes to a dictionary cache")
    func concurrentDictionarySafety() async {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var cache: [Int: String] = [:]
        let count = 500

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    lock.withLock { cache[i] = "value-\(i)" }
                }
            }
        }

        // All entries should have been written
        #expect(cache.count == count)
    }

    // MARK: - Frame-timestamp ring-buffer pattern

    /// Replicates the PVGPUViewController frame-timestamp accumulation
    /// protected by OSAllocatedUnfairLock<Void>, replacing NSLock bare pairs.
    @Test("Frame timestamp ring buffer is concurrency-safe")
    func frameTimestampRingBuffer() async {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var timestamps: [Double] = []
        let maxCount = 60
        let frameCount = 300

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<frameCount {
                group.addTask {
                    lock.withLock {
                        timestamps.append(Double(i))
                        if timestamps.count > maxCount {
                            timestamps.removeFirst()
                        }
                    }
                }
            }
        }

        // After all tasks, the ring buffer must not exceed maxCount
        #expect(timestamps.count <= maxCount)
    }

    // MARK: - Cache read/write isolation (simulates RealmSaveStateDriver)

    @Test("Cache check-then-insert does not produce duplicate entries under concurrency")
    func cacheCheckThenInsert() async {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var cache: [String: Int] = [:]
        var insertCount = 0

        let key = "test-id"
        let workerCount = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<workerCount {
                group.addTask {
                    lock.withLock {
                        if cache[key] == nil {
                            cache[key] = i
                            insertCount += 1
                        }
                    }
                }
            }
        }

        // Exactly one worker should have inserted
        #expect(insertCount == 1)
        #expect(cache[key] != nil)
    }

    // MARK: - Task-ID guard pattern (simulates RealmSaveStateDriver.isTaskActive)

    @Test("Task-ID guard allows only the active task")
    func taskIdGuard() {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var currentTaskId = UUID()
        var task: Task<Void, Never>? = nil

        // Simulate starting a new task
        let newId = UUID()
        lock.withLock { currentTaskId = newId }

        // Create a dummy task
        task = Task {}

        // isTaskActive: same id → active
        let active = lock.withLock { () -> Bool in
            guard task != nil else { return false }
            return newId == currentTaskId
        }
        #expect(active == true)

        // Simulate task replacement
        let replacedId = UUID()
        lock.withLock { currentTaskId = replacedId }

        // Old task id is now stale
        let stale = lock.withLock { () -> Bool in
            guard task != nil else { return false }
            return newId == currentTaskId  // newId != replacedId
        }
        #expect(stale == false)

        task?.cancel()
    }

    // MARK: - deinit pattern (simulates RealmSaveStateDriver.deinit)

    @Test("deinit pattern cancels and nils task under lock")
    func deinitTaskCancellation() {
        let lock = OSAllocatedUnfairLock<Void>(initialState: ())
        var conversionTask: Task<Void, Never>? = Task { try? await Task.sleep(nanoseconds: 10_000_000_000) }

        // Simulate deinit
        lock.withLock {
            conversionTask?.cancel()
            conversionTask = nil
        }

        #expect(conversionTask == nil)
    }
}
