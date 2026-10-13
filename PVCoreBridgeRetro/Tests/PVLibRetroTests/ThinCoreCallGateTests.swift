//
//  ThinCoreCallGateTests.swift
//  PVLibRetroTests
//
//  Covers PVThinCoreCallGate, the lock that keeps the thin wrapper from
//  calling into a libretro core from two threads at once (a save state on a
//  GCD worker racing the quit teardown deadlocked flycast) and from calling it
//  at all once teardown has begun.
//

import Foundation
import Testing
@testable import PVCoreBridgeRetro

/// Runs `body` on a fresh thread. The gate is a recursive lock: each thread
/// must leave what it entered, so the holder in these tests is always a real
/// thread, never a task that could hop.
private func onThread(_ body: @escaping @Sendable () -> Void) {
    Thread.detachNewThread(body)
}

/// Thread-safe flag for the cross-thread assertions.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}

private let shortWait: TimeInterval = 0.15
private let generousWait: TimeInterval = 5

@Suite("PVThinCoreCallGate")
struct ThinCoreCallGateTests {

    @Test("A call enters and leaves while no teardown is pending")
    func enterBeforeTeardown() {
        let gate = PVThinCoreCallGate()
        #expect(gate.enter(withTimeout: shortWait))
        gate.leave()
        #expect(!gate.isTearingDown)
    }

    @Test("Every call is refused once teardown has begun, until reopen")
    func refusedAfterTeardownBegins() {
        let gate = PVThinCoreCallGate()
        gate.beginTeardown()
        #expect(gate.isTearingDown)
        #expect(!gate.enter(withTimeout: shortWait))

        var ran = false
        #expect(!gate.perform(withTimeout: shortWait) { ran = true })
        #expect(!ran)

        gate.reopen()
        #expect(gate.enter(withTimeout: shortWait))
        gate.leave()
    }

    @Test("Teardown waits for the call in flight (a save state) to finish")
    func teardownWaitsForInFlightCall() {
        let gate = PVThinCoreCallGate()
        let entered = DispatchSemaphore(value: 0)
        let finished = Flag()

        onThread {
            guard gate.enter(withTimeout: PVThinCoreCallGateWaitForever) else { return }
            entered.signal()
            Thread.sleep(forTimeInterval: 0.3)  // retro_serialize in progress
            finished.set()
            gate.leave()
        }
        entered.wait()

        #expect(gate.enterForTeardown(withTimeout: generousWait))
        #expect(finished.isSet, "teardown acquired the gate while the save was still running")
        gate.leaveTeardown()
    }

    @Test("A call queued behind the teardown is refused once it gets the lock")
    func callWaitingDuringTeardownIsRefused() {
        let gate = PVThinCoreCallGate()
        #expect(gate.enterForTeardown(withTimeout: shortWait))

        let done = DispatchSemaphore(value: 0)
        let admitted = Flag()
        onThread {
            if gate.enter(withTimeout: generousWait) {
                admitted.set()
                gate.leave()
            }
            done.signal()
        }
        Thread.sleep(forTimeInterval: 0.1)
        gate.leaveTeardown()
        done.wait()
        #expect(!admitted.isSet)
    }

    @Test("The teardown owner can make nested core calls; other threads cannot")
    func teardownOwnerMayReenter() {
        let gate = PVThinCoreCallGate()
        #expect(gate.enterForTeardown(withTimeout: shortWait))

        // e.g. the SRAM flush run from inside the teardown
        #expect(gate.enter(withTimeout: 0))
        gate.leave()

        let done = DispatchSemaphore(value: 0)
        let admitted = Flag()
        onThread {
            if gate.enter(withTimeout: shortWait) {
                admitted.set()
                gate.leave()
            }
            done.signal()
        }
        done.wait()
        #expect(!admitted.isSet)

        gate.leaveTeardown()
        #expect(!gate.enter(withTimeout: shortWait), "teardown stays latched after the owner leaves")
    }

    @Test("Bounded waits return on timeout instead of parking the caller")
    func boundedWaitTimesOut() {
        let gate = PVThinCoreCallGate()
        let held = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let released = DispatchSemaphore(value: 0)

        onThread {
            guard gate.enter(withTimeout: PVThinCoreCallGateWaitForever) else { return }
            held.signal()
            release.wait()  // a core call that never returns, as far as the waiter knows
            gate.leave()
            released.signal()
        }
        held.wait()

        let start = Date()
        #expect(!gate.enter(withTimeout: shortWait))
        #expect(!gate.enterForTeardown(withTimeout: shortWait))
        #expect(Date().timeIntervalSince(start) < 2, "the bounded waits did not honour their timeout")

        release.signal()
        released.wait()
        #expect(!gate.enter(withTimeout: shortWait), "a timed-out teardown still latches the gate")
    }

    @Test("The same thread can re-enter (frame -> pending reset -> retro_reset)")
    func reentrantOnSameThread() {
        let gate = PVThinCoreCallGate()
        #expect(gate.enter(withTimeout: 0))
        #expect(gate.enter(withTimeout: 0))
        gate.leave()
        gate.leave()

        let done = DispatchSemaphore(value: 0)
        let admitted = Flag()
        onThread {
            if gate.enter(withTimeout: shortWait) {
                admitted.set()
                gate.leave()
            }
            done.signal()
        }
        done.wait()
        #expect(admitted.isSet, "the gate was left held after balanced re-entry")
    }
}
