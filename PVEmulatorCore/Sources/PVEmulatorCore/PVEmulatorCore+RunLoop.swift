//
//  PVEmulatorCore+RunLoop.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging


@objc extension PVEmulatorCore {// : EmulatorCoreRunLoop {
    @objc open var framerateMultiplier: Float { gameSpeed.multiplier }

    /// Longest `setPauseEmulation(true)` waits, on the main thread, for an
    /// in-flight front-buffer swap (a swap is microseconds; this is ~3 frames).
    private static var pauseFrontBufferWait: TimeInterval { 0.05 }

    @MainActor
    @objc open func setPauseEmulation(_ flag: Bool) {
        /// A bridge that boots asynchronously has not spawned its emulation-loop
        /// thread yet, and `-[PVCoreObjCBridge startEmulation]` will only ever
        /// spawn it if `isRunning` and `skipEmulationLoop` are both false when it
        /// runs. Writing either of them here — both are pass-throughs to the
        /// bridge — would silently cancel that one-shot spawn and leave a core
        /// that renders whatever `retro_load_game` produced and then never
        /// advances again. Record the request and replay it once the core is
        /// running. No-op for synchronous bridges: `isBootPending` is never true
        /// for them.
        /// Every pause transition is logged. A core that has visibly stopped
        /// advancing is either paused or has no emulation-loop thread, and those
        /// two look identical on screen; a `pause → true` with no matching
        /// `pause → false` distinguishes a stranded pause (a resume that was
        /// dropped by whoever asked for the pause) from a swallowed spawn. Once
        /// per menu/skin transition, so nowhere near the frame path.
        ILOG("Core pause → \(flag) (isBootPending: \(isBootPending), isRunning: \(isRunning))")
        guard !isBootPending else {
            pendingPauseWhileBooting = flag
            return
        }
        if flag {
            stopHaptic()
            skipEmulationLoop = true
            // Let any in-flight front-buffer swap/draw finish before marking the
            // core paused, so a pause never freezes the presenter on a
            // half-swapped buffer (da47669485, "fix pause/resume freezing
            // video"). The empty critical section is intentional.
            //
            // BOUNDED: this runs on the main thread, and the emulation thread
            // (swap) or a draw can hold the lock across work that itself waits
            // on main. An unbounded wait there is a 0x8BADF00D watchdog kill, so
            // give up after `Self.pauseFrontBufferWait` and carry on -- the swap
            // is short, so in practice we always acquire it.
            if frontBufferLock.lock(before: Date(timeIntervalSinceNow: Self.pauseFrontBufferWait)) {
                frontBufferLock.unlock()
            } else {
                WLOG("setPauseEmulation: frontBufferLock still held after \(Int(Self.pauseFrontBufferWait * 1000)) ms; pausing without waiting for the swap")
            }
            isRunning = false
        } else {
            startHaptic()
            skipEmulationLoop = false
            shouldResyncTime = true
            isRunning = true
        }
        bridge.setPauseEmulation(flag)
    }


    @objc open var isEmulationPaused: Bool { return !isRunning }

    @objc open var isSpeedModified: Bool { return gameSpeed != .normal }

    /// Performs a best-effort synchronous shutdown for fatal exception handling.
    ///
    /// This intentionally avoids `@MainActor` state such as `isOn` because the
    /// uncaught exception handler cannot safely hop actors before the process exits.
    @objc open func emergencyStopEmulation() {
        stopHaptic()
        shouldStop = true
        isRunning = false

        isFrontBufferReady = false
        frontBufferCondition.signal()

        /// Bypass Swift actor isolation for the fatal-exception path and send the
        /// Objective-C selector synchronously, matching the pre-concurrency behavior.
        let stopSelector = NSSelectorFromString("stopEmulation")
        _ = (bridge as AnyObject).perform(stopSelector)
    }

    @MainActor
    @objc open func stopEmulation() {
        stopHaptic()
        // Abandon any in-flight asynchronous boot: the bridge defers its own
        // teardown until the core is quiescent, and whoever installed the
        // completion (the emulator view controller) is going away.
        isBootPending = false
        pendingPauseWhileBooting = nil
        startEmulationCompletion = nil
        signalEmulationLoopToStop()

        bridge.stopEmulation()
        isOn = false
        // Update the singleton state
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = ""
                state.systemName = ""
                state.isOn = false
            }
        }
    }

    /// Tells the emulation loop to exit after its current frame and wakes a
    /// presenter waiting for a front buffer. Does not wait for the exit.
    @MainActor
    private func signalEmulationLoopToStop() {
        shouldStop = true
        isRunning = false
        isFrontBufferReady = false
        frontBufferCondition.signal()
    }

    /// Longest `stopEmulationAfterLoopExits()` waits for the emulation loop to
    /// exit before falling back to `stopEmulation()`'s unbounded main-thread join.
    private static var loopExitWait: TimeInterval { 5 }

    /// `stopEmulation()`, with the emulation-loop join moved OFF the main thread.
    ///
    /// `stopEmulation()` ends in `-[PVCoreObjCBridge stopEmulationWithMessage:]`,
    /// which waits on `emulationLoopThreadLock` until the loop exits. That wait
    /// is on main and unbounded, so a final frame that itself waits on main
    /// (`dispatch_sync` to the main queue from a core) deadlocks and the
    /// watchdog kills the app (0x8BADF00D). It cannot simply be given a timeout:
    /// returning early would let the core be torn down under a frame still
    /// running.
    ///
    /// Here the loop is told to stop exactly as `stopEmulation()` does, and the
    /// join happens on a background queue while main stays free to serve that
    /// last frame. `stopEmulation()` then runs unchanged and finds the loop
    /// already gone. If the loop has not exited within `loopExitWait` this
    /// falls through to the old blocking join, so it is never worse than before.
    ///
    /// Main must not take the bridge's `@synchronized` monitor while this is
    /// suspended: the loop holds it around every frame, so that would reopen
    /// the same deadlock.
    @MainActor
    @nonobjc public func stopEmulationAfterLoopExits() async {
        // An asynchronous boot has no loop to join yet, and `stopEmulation()`
        // must run now to drop the boot completion before it can fire into a
        // caller that is going away.
        guard !isBootPending else {
            stopEmulation()
            return
        }
        signalEmulationLoopToStop()

        if await !Self.waitForUnlock(emulationLoopThreadLock, timeout: Self.loopExitWait) {
            WLOG("stopEmulationAfterLoopExits: emulation loop still running after \(Int(Self.loopExitWait)) s; joining on the main thread")
        }
        stopEmulation()
    }

    /// Waits on a GCD queue until `lock` can be acquired, then releases it.
    /// Returns `false` if `timeout` elapsed first. A GCD queue rather than a
    /// task, because blocking a Swift-concurrency thread for seconds starves the
    /// cooperative pool.
    @nonobjc nonisolated static func waitForUnlock(_ lock: NSLock, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Lock and unlock on this one thread: NSLock must be unlocked by
                // the thread that locked it.
                let acquired = lock.lock(before: Date(timeIntervalSinceNow: timeout))
                if acquired {
                    lock.unlock()
                }
                continuation.resume(returning: acquired)
            }
        }
    }

    @MainActor
    @objc open func stopEmulation(withMessage message: String? = nil) {
        stopEmulation()

        if let message = message {
            // TODO: Show the message to the user
        }
    }

    @MainActor
    @objc open func startEmulation() {
//        screenRect
        guard type(of: self) != PVEmulatorCore.self else {
            ELOG("startEmulation Not implimented")
            return
        }

        guard !isRunning, !isBootPending else {
            WLOG("Already running")
            return
        }

        #if !os(tvOS) && !os(macOS) && !os(watchOS)
//        startHaptic()
        do {
            try setPreferredSampleRate(audioSampleRate)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        #endif

        gameSpeed = .normal

#warning("TODO: Should remove the else clause?")
        if let objcBridge = self as? (any ObjCBridgedCore), let bridge = objcBridge.bridge as? EmulatorCoreRunLoop {
            if bridge.startsEmulationAsynchronously == true {
                /// The bridge boots the core on its own thread and calls
                /// `emulationDidStart()` / `emulationDidFailToStart()` back on main.
                /// Deliberately do NOT fall through to `markEmulationRunning()`: a
                /// core that failed to boot must not report `isRunning`/`isOn`, or
                /// the `guard !isRunning` above would turn a retry into a silent
                /// no-op and the boot HUD (driven by `isRunning`) would hide over a
                /// black screen.
                isBootPending = true
                bridge.startEmulation()
                return
            }
            bridge.startEmulation()
        } else {
            if !skipEmulationLoop {
                let emulatorThread = Thread {
                    /// Set thread name for debugging
                    Thread.current.name = "EmulatorThread"

                    /// Set QoS if possible
                    Thread.current.qualityOfService = .userInteractive

                    /// Run the emulation loop
                    self.emulationLoopThread()
                }

                /// Set thread priority (0.0-1.0)
                emulatorThread.threadPriority = 1.0

                /// Start the thread
                emulatorThread.start()

            } else {
                isFrontBufferReady = true
            }
        }

        markEmulationRunning()
    }

    /// Flip the core into the running state and notify `startEmulationCompletion`.
    ///
    /// Extracted from `startEmulation()` so the asynchronous-boot path can reach
    /// the exact same state transition from its completion instead of running it
    /// speculatively before the core has loaded.
    @MainActor
    open func markEmulationRunning() {
        isRunning = true
        shouldStop = false
        isOn = true
        // Update the singleton state
        let coreId = self.coreIdentifier ?? ""
        let sysId = self.systemIdentifier ?? ""
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = coreId
                state.systemName = sysId
                state.isOn = true
            }
        }
        let completion = startEmulationCompletion
        startEmulationCompletion = nil
        completion?(true)
    }

    /// Called by an asynchronously-booting bridge, on the main thread, once the
    /// core has finished `retro_init` + `retro_load_game` successfully and its
    /// emulation loop thread is running.
    @MainActor
    open func emulationDidStart() {
        isBootPending = false
        markEmulationRunning()
        /// Replay a pause/resume that arrived while the core was still booting.
        /// Applied AFTER `markEmulationRunning()` so the emulation-loop thread
        /// already exists — the ordering the synchronous path got for free.
        if let deferredPause = pendingPauseWhileBooting {
            pendingPauseWhileBooting = nil
            setPauseEmulation(deferredPause)
        }
    }

    /// Called by an asynchronously-booting bridge, on the main thread, when the
    /// boot failed. The core has already torn itself down, and the bridge has
    /// already posted `PVEmulatorCoreDidFailToStart` with the underlying error.
    ///
    /// `isRunning` is left `false` on purpose so a retry is not swallowed by the
    /// `guard !isRunning` in `startEmulation()`.
    @MainActor
    open func emulationDidFailToStart() {
        isBootPending = false
        pendingPauseWhileBooting = nil
        let completion = startEmulationCompletion
        startEmulationCompletion = nil
        completion?(false)
    }

    @MainActor
    @objc open func resetEmulation() {
        bridge.resetEmulation?()
    }

//    @MainActor
    @objc open func emulationLoopThread() {
        bridge.emulationLoopThread?()
    }
}
