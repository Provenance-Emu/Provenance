//
//  PVEmulatorCore+RunLoop.swift
//
//
//  Created by Joseph Mattiello on 5/22/24.
//

import Foundation
import PVCoreBridge
import PVLogging

@objc extension PVEmulatorCore: EmulatorCoreRunLoop {
    @objc open var framerateMultiplier: Float {
        switch gameSpeed {
        case .slow: return 0.2
        case .normal: return 1.0
        case .fast: return 5.0
        }
    }

    @objc open func setPauseEmulation(_ flag: Bool) {
        if flag {
            stopHaptic()
            isRunning = false
        } else {
            startHaptic()
            isRunning = true
        }
    }

    @objc open var isEmulationPaused: Bool { return !isRunning }

    @objc open var isSpeedModified: Bool { return gameSpeed != .normal }


    @objc open func stopEmulation() {
        if let objcBridge = self as? ObjCCoreBridge {
            objcBridge.stopEmulation()
        }
        self.stopEmulation(withMessage: nil)
    }

    @objc open func stopEmulation(withMessage message: String? = nil) {
        stopHaptic()
        shouldStop = true
        isRunning = false

        isFrontBufferReady = false
        frontBufferCondition.signal()

        if let message = message {
            // TODO: Show the message to the user
        }
        isOn = false
    }


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
        startHaptic()
        do {
            try setPreferredSampleRate(sampleRate)
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        #endif
        isRunning = true
        shouldStop = false
        isOn = true
        gameSpeed = .normal

        if !skipEmulationLoop {
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                if let self = self {
                    self.emulationLoopThread()
                }
            }
        } else {
            isFrontBufferReady = true
        }
    }

    @objc open func resetEmulation() {
        if let objcBridge = self as? ObjCCoreBridge {
            objcBridge.resetEmulation()
        } else {
            ELOG("resetEmulation Not implimented")
        }
    }

//    @MainActor
    @objc open func emulationLoopThread() {

    }
}
