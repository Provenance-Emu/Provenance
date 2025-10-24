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
            frontBufferLock.lock()
            frontBufferLock.unlock()
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

    @MainActor
    @objc open func stopEmulation() {
        stopHaptic()
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

        guard !isRunning else {
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

        isRunning = true
        shouldStop = false
        isOn = true
        // Update the singleton state
        Task {
            await EmulationState.shared.update { state in
                state.coreClassName = self.coreIdentifier ?? ""
                state.systemName = self.systemIdentifier ?? ""
                state.isOn = true
            }
        }
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
