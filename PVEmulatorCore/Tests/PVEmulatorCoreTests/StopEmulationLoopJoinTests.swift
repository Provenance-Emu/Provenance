//
//  StopEmulationLoopJoinTests.swift
//  PVEmulatorCoreTests
//

@testable import PVEmulatorCore
import XCTest

/// `PVEmulatorCore.waitForUnlock(_:timeout:)` is the off-main join behind
/// `stopEmulationAfterLoopExits()`. The emulation loop holds
/// `emulationLoopThreadLock` for its whole life, so these stand a thread in for
/// the loop.
final class StopEmulationLoopJoinTests: XCTestCase {
    /// The case that used to deadlock: the loop's last frame waits on main
    /// while main waits for the loop. Awaited on main, the join must leave main
    /// free to serve that frame.
    @MainActor
    func testJoinCompletesWhenLastFrameWaitsOnMain() async {
        let loopLock = NSLock()
        Self.startLoop(holding: loopLock) {
            DispatchQueue.main.sync {}
        }

        let exited = await PVEmulatorCore.waitForUnlock(loopLock, timeout: 5)

        XCTAssertTrue(exited)
    }

    func testJoinReportsTimeoutWhileLoopKeepsRunning() async {
        let loopLock = NSLock()
        let release = DispatchSemaphore(value: 0)
        Self.startLoop(holding: loopLock) {
            release.wait()
        }

        let exited = await PVEmulatorCore.waitForUnlock(loopLock, timeout: 0.1)
        release.signal()

        XCTAssertFalse(exited)
    }

    func testJoinReturnsImmediatelyWhenNoLoopIsRunning() async {
        let exited = await PVEmulatorCore.waitForUnlock(NSLock(), timeout: 0.1)

        XCTAssertTrue(exited)
    }

    /// Starts a thread that takes `lock`, runs `frame`, then releases it, and
    /// returns once the lock is held.
    private static func startLoop(holding lock: NSLock, frame: @escaping @Sendable () -> Void) {
        let locked = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            lock.lock()
            locked.signal()
            frame()
            lock.unlock()
        }
        locked.wait()
    }
}
