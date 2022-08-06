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

fileprivate let g_motion:CMMotionManager = CMMotionManager()
fileprivate var g_acceleration: CMAcceleration = .init(x: 0, y: 0, z: 0)
fileprivate var g_magnetometerData: CMMagnetometerData? = nil
fileprivate var g_gyroData: CMGyroData? = nil
fileprivate var g_deviceMotion: CMDeviceMotion? = nil
#endif

fileprivate var g_timer: Timer? = nil
fileprivate var sensorsEnabled: SensorsEnabled = .init(rawValue: 0) {
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
                g_timer = timer;
            }
            return g_timer
        }
        set {
            g_timer?.invalidate()
            g_timer = newValue
        }
    }
    
    func handleTimer() {
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
    }
    
    @objc var accelerometerStateX: Float { Float(g_acceleration.x) }
    @objc var accelerometerStateY: Float { Float(g_acceleration.y) }
    @objc var accelerometerStateZ: Float { Float(g_acceleration.z) }
    @objc var gyroscopeStateX: Float { Float(g_gyroData?.rotationRate.x ?? 0) }
    @objc var gyroscopeStateY: Float { Float(g_gyroData?.rotationRate.y ?? 0) }
    @objc var gyroscopeStateZ: Float { Float(g_gyroData?.rotationRate.z ?? 0) }

    @objc
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
    
    @objc
    func stopAccelerometers() {
        if motion.isAccelerometerActive {
            motion.stopAccelerometerUpdates()
        }
    }
}

@objc public extension PVEmulatorCore {
    @objc
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
    
    @objc
    func stopGyro() {
        if motion.isGyroActive {
            motion.stopGyroUpdates()
        }
    }
}

@objc public extension PVEmulatorCore {
    @objc
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
    
    @objc
    func stopMagnetometer() {
        if motion.isMagnetometerActive {
            motion.stopMagnetometerUpdates()
        }
    }
}

@objc public extension PVEmulatorCore {
    @objc
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
    
    @objc
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

fileprivate var g_illuminance: Float = 0

@objc public extension PVEmulatorCore {

    @objc var illuminance: Float { g_illuminance }

    @objc
    func startIlluminance() -> Bool {
        return false
    }
    
    @objc
    func stopIlluminance() {
    }
}
