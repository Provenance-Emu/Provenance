//
//  DrawableStarvationBackoffTests.swift
//  PVUIBaseTests
//

import Testing
@testable import PVUIBase

@Suite("DrawableStarvationBackoff")
struct DrawableStarvationBackoffTests {
    @Test func drawsWhileDrawablesArrive() {
        let backoff = DrawableStarvationBackoff()
        #expect(!backoff.shouldSkipDraw(at: 0))
        #expect(!backoff.shouldSkipDraw(at: 100))
    }

    @Test func skipsFramesRightAfterAMiss() {
        var backoff = DrawableStarvationBackoff()
        backoff.recordMiss(at: 10)
        #expect(backoff.shouldSkipDraw(at: 10))
        #expect(backoff.shouldSkipDraw(at: 10 + DrawableStarvationBackoff.initialDelay / 2))
        #expect(!backoff.shouldSkipDraw(at: 10 + DrawableStarvationBackoff.initialDelay))
    }

    @Test func waitsLongerAfterEachMiss() {
        #expect(DrawableStarvationBackoff.delay(afterMisses: 0) == 0)
        #expect(DrawableStarvationBackoff.delay(afterMisses: 1) == DrawableStarvationBackoff.initialDelay)
        #expect(DrawableStarvationBackoff.delay(afterMisses: 2) == DrawableStarvationBackoff.initialDelay * 2)
        #expect(DrawableStarvationBackoff.delay(afterMisses: 3) == DrawableStarvationBackoff.initialDelay * 4)
    }

    @Test func waitIsCapped() {
        #expect(DrawableStarvationBackoff.delay(afterMisses: 10) == DrawableStarvationBackoff.maximumDelay)
        #expect(DrawableStarvationBackoff.delay(afterMisses: 10_000) == DrawableStarvationBackoff.maximumDelay)
    }

    /// A drained pool must leave the main thread free most of the time: with a
    /// one-second timeout per request, the wait before the next one is at least
    /// as long once the pool has been empty for a few frames.
    @Test func aDrainedPoolLeavesTheMainThreadFree() {
        var backoff = DrawableStarvationBackoff()
        var now = 0.0
        let timeout = 1.0
        var blocked = 0.0
        while now < 60 {
            if backoff.shouldSkipDraw(at: now) {
                now += 1.0 / 60
                continue
            }
            now += timeout
            blocked += timeout
            backoff.recordMiss(at: now)
        }
        #expect(blocked / now < 0.4)
    }

    @Test func aDrawableClearsTheWait() {
        var backoff = DrawableStarvationBackoff()
        backoff.recordMiss(at: 5)
        backoff.recordMiss(at: 6)
        #expect(backoff.consecutiveMisses == 2)
        backoff.reset()
        #expect(backoff.consecutiveMisses == 0)
        #expect(!backoff.shouldSkipDraw(at: 6))
    }
}
