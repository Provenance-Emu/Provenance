//
//  PVEmulatorCore+Accelerometer.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit

#if canImport(CoreMotion)
import CoreMotion

private let g_motion:CMMotionManager = CMMotionManager()
private var g_acceleration: CMAcceleration = .init(x: 0, y: 0, z: 0)
private var g_magnetometerData: CMMagnetometerData?
private var g_gyroData: CMGyroData?
private var g_deviceMotion: CMDeviceMotion?
#endif

private var g_timer: Timer?
private var sensorsEnabled: SensorsEnabled = .init(rawValue: 0) {
    didSet {
        if sensorsEnabled.isEmpty {
            g_timer?.invalidate()
            g_timer = nil
        }
    }
}

struct SensorsEnabled: OptionSet {
    let rawValue: UInt

    static let accelerometer = SensorsEnabled(rawValue: 1 << 0)
    static let gyro = SensorsEnabled(rawValue: 1 << 1)
    static let magnetometer = SensorsEnabled(rawValue: 1 << 2)
    static let deviceMotion = SensorsEnabled(rawValue: 1 << 3)

    static let all: SensorsEnabled = [.accelerometer, .gyro, .magnetometer, .deviceMotion]
}

@objc public extension PVEmulatorCore {
    var motion: CMMotionManager {
        return g_motion
    }

    var timer: Timer? {
        get {
            if g_timer == nil, !sensorsEnabled.isEmpty {
                let timer = Timer(fire: Date(),
                                interval: (1.0/60.0),
                                repeats: true,
                                block: { [weak self] timer in
                    self?.handleTimer()
                })
                g_timer = timer
            }
            return g_timer
        }
        set {
            g_timer?.invalidate()
            g_timer = newValue
        }
    }

    func handleTimer() {
        #if !os(tvOS)
        if sensorsEnabled.contains(.accelerometer) {
            if let data = self.motion.accelerometerData {
                g_acceleration = data.acceleration
            }
        }
        if sensorsEnabled.contains(.gyro) {
            if let data = self.motion.gyroData {
                g_gyroData = data
            }
        }
        if sensorsEnabled.contains(.magnetometer) {
            if let data = self.motion.magnetometerData {
                g_magnetometerData = data
            }
        }
        if sensorsEnabled.contains(.deviceMotion) {
            if let data = self.motion.deviceMotion {
                g_deviceMotion = data
            }
        }
        #endif
    }

    var accelerometerStateX: Float { Float(g_acceleration.x) }
    var accelerometerStateY: Float { Float(g_acceleration.y) }
    var accelerometerStateZ: Float { Float(g_acceleration.z) }
    var gyroscopeStateX: Float { Float(g_gyroData?.rotationRate.x ?? 0) }
    var gyroscopeStateY: Float { Float(g_gyroData?.rotationRate.y ?? 0) }
    var gyroscopeStateZ: Float { Float(g_gyroData?.rotationRate.z ?? 0) }

    func startAccelerometers() -> Bool {
        // Make sure the accelerometer hardware is available.
        guard self.motion.isAccelerometerAvailable else { return false }
        self.motion.accelerometerUpdateInterval = 1.0 / 60.0  // 60 Hz
        self.motion.startAccelerometerUpdates()

        // Configure a timer to fetch the data.
        self.timer = Timer(fire: Date(), interval: (1.0/60.0),
                           repeats: true, block: { (timer) in
            // Get the accelerometer data.
            if let data = self.motion.accelerometerData {
                g_acceleration = data.acceleration
            }
        })

        // Add the timer to the current run loop.
        RunLoop.current.add(self.timer!, forMode: .default)
        return true
    }

    func stopAccelerometers() {
        if motion.isAccelerometerActive {
            motion.stopAccelerometerUpdates()
        }
    }
}

@objc public extension PVEmulatorCore {
    func startGyro() -> Bool {
        // Make sure the accelerometer hardware is available.
        guard self.motion.isGyroAvailable else { return false }

        self.motion.gyroUpdateInterval = 1.0 / frameInterval  // 60 Hz
        self.motion.startGyroUpdates()
        //           let handler: CMGyroHandler = ^{ data, error in
        //
        //           }
        //           self.motion.startGyroUpdates(to: .main, withHandler: handler)
        // Configure a timer to fetch the data.
        self.timer = Timer(fire: Date(), interval: (1.0/frameInterval),
                           repeats: true, block: { (timer) in
            // Get the accelerometer data.
            if let data = self.motion.gyroData {
                g_gyroData = data
            }
        })

        // Add the timer to the current run loop.
        RunLoop.current.add(self.timer!, forMode: .default)
        return true

    }

    func stopGyro() {
        if motion.isGyroActive {
            motion.stopGyroUpdates()
        }
    }
}

@objc public extension PVEmulatorCore {
    func startMagnetometer() -> Bool {
        // Make sure the accelerometer hardware is available.
        guard self.motion.isMagnetometerAvailable else { return false }

            self.motion.magnetometerUpdateInterval = 1.0 / frameInterval  // 60 Hz
            self.motion.startMagnetometerUpdates()
            //          let handler: CMMagnetometerHandler = ^{ magnetometerData, error in
            //
            //          }
            //          self.motion.startMagnetometerUpdates(to: .main, withHandler: handler)

            // Configure a timer to fetch the data.
            self.timer = Timer(fire: Date(), interval: (1.0/frameInterval),
                               repeats: true, block: { (timer) in
                // Get the accelerometer data.
                if let data = self.motion.magnetometerData {
                    g_magnetometerData = data
                }
            })

            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        return true

    }

    func stopMagnetometer() {
        if motion.isMagnetometerActive {
            motion.stopMagnetometerUpdates()
        }
    }
}

@available(iOS 14.0, *)
@objc public extension PVEmulatorCore {
    func startDeviceMotion() -> Bool {
        // Make sure the accelerometer hardware is available.
        guard self.motion.isDeviceMotionAvailable else { return false }
        self.motion.deviceMotionUpdateInterval = 1.0 / frameInterval  // 60 Hz
        self.motion.startDeviceMotionUpdates()
        //          let handler: CMDeviceMotionHandler = ^{ motion, error in
        //
        //          }
        //          self.motion.startDeviceMotionUpdates(to: .main, withHandler: handler)

        // Configure a timer to fetch the data.
        self.timer = Timer(fire: Date(), interval: (1.0/frameInterval),
                           repeats: true, block: { (timer) in
            // Get the accelerometer data.
            if let data = self.motion.deviceMotion {
                g_deviceMotion = data
            }
        })

        // Add the timer to the current run loop.
        RunLoop.current.add(self.timer!, forMode: .default)
        return true
    }

    func stopDeviceMotion() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }
}

// MARK: - Illuminance

#if canImport(SensorKit)
import SensorKit
#endif

private var g_illuminance: Float = 0

@objc public extension PVEmulatorCore {

    var illuminance: Float { g_illuminance }

    func startIlluminance() -> Bool {
        return false
    }

    func stopIlluminance() {
    }
}
