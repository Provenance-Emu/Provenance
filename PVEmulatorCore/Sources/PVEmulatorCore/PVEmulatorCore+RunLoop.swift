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

    @MainActor
    @objc open func setPauseEmulation(_ flag: Bool) {
        if flag {
            stopHaptic()
            skipEmulationLoop = true
            // Wait until any in-flight front-buffer access completes before marking
            // the core as paused.  The empty critical section is intentional.
            frontBufferLock.withLock { }
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
        startEmulationCompletion = nil
        shouldStop = true
        isRunning = false

        isFrontBufferReady = false
        frontBufferCondition.signal()

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
