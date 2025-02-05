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

    @objc open func setPauseEmulation(_ flag: Bool) {
        if flag {
            stopHaptic()
            // Pause emulation loop
            skipEmulationLoop = true
            // Wait for current frame to complete
            frontBufferLock.lock()
            frontBufferLock.unlock()

            isRunning = false
        } else {
            startHaptic()
            // Resume emulation loop
            skipEmulationLoop = false
            shouldResyncTime = true
//                // Signal render delegate to resume
//                renderDelegate?.isPaused = false

            isRunning = true
        }
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
                // TODO: Default case (not used?) should be in a detached thread
//                Task.detached(priority: .high) {
                    self.emulationLoopThread()
//                }
            } else {
                isFrontBufferReady = true
            }
        }
        isRunning = true
        shouldStop = false
        isOn = true
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
