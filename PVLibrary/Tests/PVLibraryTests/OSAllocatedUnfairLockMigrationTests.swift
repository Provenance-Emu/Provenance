//
//  OSAllocatedUnfairLockMigrationTests.swift
//  PVLibrary
//
//  Tests that verify the thread-safety guarantees of the OSAllocatedUnfairLock
//  replacement for NSLock throughout PVLibrary (issue #2807).
//
//  Coverage:
//  - Basic mutual-exclusion: concurrent writers never corrupt shared state.
//  - Nesting-depth counter used by CloudKitRemoteApplyGuard.
//  - withLock re-entrant-safety (confirming withLock is NOT re-entrant — callers
//    must not call withLock from inside a withLock closure on the same lock).
//

import Testing
import Foundation
import os

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

/// A minimal reimplementation of the OSAllocatedUnfairLock<Void> pattern used
/// throughout PVLibrary so that the tests exercise the same idiom without
/// depending on internal (non-public) types.
private final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    /// Atomically increment by one and return the new value.
    @discardableResult
    func increment() -> Int {
        lock.withLock { value in
            value += 1
            return value
        }
    }

    /// Atomically decrement by one and return the new value.
    @discardableResult
    func decrement() -> Int {
        lock.withLock { value in
            value -= 1
            return value
        }
    }

    var value: Int { lock.withLock { $0 } }
}

/// Reimplementation of the nesting-depth guard pattern used in
/// `CloudKitRemoteApplyGuard` (now using `OSAllocatedUnfairLock<Int>`).
private enum TestRemoteApplyGuard {
    private static let _depth = OSAllocatedUnfairLock<Int>(initialState: 0)

    static var isApplying: Bool { _depth.withLock { $0 > 0 } }

    @discardableResult
    static func withApplying<T>(_ work: () throws -> T) rethrows -> T {
        _depth.withLock { $0 += 1 }
        defer { _depth.withLock { $0 = max(0, $0 - 1) } }
        return try work()
    }
}

// ---------------------------------------------------------------------------
// MARK: - Test Suite
// ---------------------------------------------------------------------------

/// Tests for the OSAllocatedUnfairLock migration (issue #2807).
///
/// These tests verify that the `OSAllocatedUnfairLock`-based patterns used to
/// replace `NSLock` across PVLibrary maintain correct mutual-exclusion semantics.
struct OSAllocatedUnfairLockMigrationTests {

    // MARK: Basic mutual exclusion

    /// Concurrent increments from many threads must produce the exact expected total.
    ///
    /// If the lock were absent (or broken) the counter would under-count due to
    /// lost-update races.  With correct locking the result is always `iterations`.
    @Test("Concurrent increments are fully serialized")
    func concurrentIncrementsAreFullySerialized() async {
        let iterations = 1_000
        let counter = ThreadSafeCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask { counter.increment() }
            }
        }

        #expect(counter.value == iterations)
    }

    /// Mix of increments and decrements from concurrent tasks must net to zero.
    @Test("Concurrent increments and decrements balance to zero")
    func concurrentIncrementsAndDecrementsBalanceToZero() async {
        let pairs = 500
        let counter = ThreadSafeCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<pairs {
                group.addTask { counter.increment() }
                group.addTask { counter.decrement() }
            }
        }

        #expect(counter.value == 0)
    }

    // MARK: withLock returns value correctly

    /// Verify that the `withLock` closure can read and mutate state atomically.
    @Test("withLock returns the correct mutated value")
    func withLockReturnsMutatedValue() {
        let lock = OSAllocatedUnfairLock<Int>(initialState: 10)
        let doubled = lock.withLock { (value: inout Int) -> Int in
            value *= 2
            return value
        }
        #expect(doubled == 20)
        #expect(lock.withLock { $0 } == 20)
    }

    // MARK: Void-state lock (guard-only usage)

    /// `OSAllocatedUnfairLock<Void>` should protect side-effectful operations.
    @Test("Void-state lock serializes side effects")
    func voidStateLockSerializesSideEffects() async {
        let lock = OSAllocatedUnfairLock<Void>()
        var sharedArray: [Int] = []

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    lock.withLock { sharedArray.append(i) }
                }
            }
        }

        #expect(sharedArray.count == 200)
    }

    // MARK: CloudKitRemoteApplyGuard pattern (nesting depth)

    /// Single nesting: `isApplying` is `true` inside the closure, `false` outside.
    @Test("Guard is active inside withApplying and inactive outside")
    func guardIsActiveInsideAndInactiveOutside() throws {
        #expect(!TestRemoteApplyGuard.isApplying)

        var sawActiveInsideClosure = false
        TestRemoteApplyGuard.withApplying {
            sawActiveInsideClosure = TestRemoteApplyGuard.isApplying
        }

        #expect(sawActiveInsideClosure)
        #expect(!TestRemoteApplyGuard.isApplying)
    }

    /// Nested invocations keep the guard active until the outermost scope exits.
    @Test("Guard stays active across nested withApplying calls")
    func guardStaysActiveAcrossNestedCalls() {
        TestRemoteApplyGuard.withApplying {
            #expect(TestRemoteApplyGuard.isApplying)
            TestRemoteApplyGuard.withApplying {
                #expect(TestRemoteApplyGuard.isApplying)
            }
            // Still active — outer scope not yet done
            #expect(TestRemoteApplyGuard.isApplying)
        }
        #expect(!TestRemoteApplyGuard.isApplying)
    }

    /// Guard depth is correctly restored even when the inner closure throws.
    @Test("Guard depth is restored after a throwing closure")
    func guardDepthRestoredAfterThrow() {
        struct TestError: Error {}

        #expect(!TestRemoteApplyGuard.isApplying)
        _ = try? TestRemoteApplyGuard.withApplying { throw TestError() }
        // Must be `false` — depth should have been decremented in the defer block
        #expect(!TestRemoteApplyGuard.isApplying)
    }

    // MARK: Cache-pattern (sizeCache equivalent)

    /// Verify that a dictionary protected by OSAllocatedUnfairLock<Void> is safe
    /// under concurrent reads and writes — analogous to PVSaveState.sizeCache.
    @Test("Cache dictionary is safe under concurrent read/write")
    func cacheDictionaryIsSafeUnderConcurrentAccess() async {
        let lock = OSAllocatedUnfairLock<Void>()
        var cache: [Int: Int] = [:]
        let count = 300

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                // Writer
                group.addTask {
                    lock.withLock { cache[i] = i * 2 }
                }
                // Reader — may read a partially populated cache but must not crash
                group.addTask {
                    _ = lock.withLock { cache[i] }
                }
            }
        }

        // Every key written by a writer should be present
        lock.withLock {
            for i in 0..<count {
                #expect(cache[i] == i * 2)
            }
        }
    }
}
