//
//  EmulatorCoreRunLoop.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

// MARK: - Lock Design (Option A)
//
// `emulationLoopThreadLock` and `frontBufferLock` are kept as `NSLock` on the
// `@objc` protocol boundary so that ObjC bridge code (_PVCoreObjCBridge.m,
// emulator core .mm files) can continue calling `[lock lock]`/`[lock unlock]`.
//
// Swift call-sites should use the `NSLocking.withLock { }` extension instead of
// calling `lock()`/`unlock()` directly.  This guarantees balanced locking via
// `defer` even when early returns or guard exits occur inside the critical section.
//
// `frontBufferCondition` is an `NSCondition` (which also conforms to NSLocking).
// Swift call-sites should use `condition.withLock { ... condition.wait() ... }`
// for the outer lock/unlock pair; `condition.wait()` temporarily releases the
// lock internally so the emulation thread can signal.
//
// ObjC consumers: no changes required — `NSLock` and `NSCondition` remain the
// concrete types exposed through the protocol.

@objc public protocol EmulatorCoreRunLoop {
    @objc dynamic var shouldStop: Bool { get set }
    @objc dynamic var isRunning: Bool { get set }
    @objc dynamic var shouldResyncTime: Bool { get set }
    @objc dynamic var skipEmulationLoop: Bool { get set }
    @objc dynamic var skipLayout: Bool { get set }

    @objc dynamic var gameSpeed: GameSpeed { get set }
    /// Surrounds the entire emulation loop thread body. Held from loop start to
    /// loop exit; `stopEmulation` acquires then releases to wait for the thread.
    /// Swift: use `.withLock { }`. ObjC: use `[lock lock]`/`[lock unlock]`.
    @objc dynamic var emulationLoopThreadLock: NSLock { get set }
    /// Condition variable used to signal that the front buffer has been filled
    /// and is ready for presentation. Swift: use `.withLock { ... .wait() ... }`.
    @objc dynamic var frontBufferCondition: NSCondition { get set }
    /// Guards the front render buffer during the copy-to-front-texture step.
    /// Swift: use `.withLock { }`. ObjC: use `[lock lock]`/`[lock unlock]`.
    @objc dynamic var frontBufferLock: NSLock { get set }
    @objc dynamic var isFrontBufferReady: Bool { get set }

    @MainActor
    @objc func stopEmulation()
    @MainActor
    @objc func startEmulation()
    @MainActor
    @objc optional func resetEmulation()
    @MainActor
    @objc func setPauseEmulation(_ flag: Bool)

    @objc optional func emulationLoopThread()
}
