//
//  PVEmulatorCore+Accelerometer.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import CoreMotion
import UIKit

fileprivate let g_motion:CMMotionManager = CMMotionManager()
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
               let x = data.acceleration.x
               let y = data.acceleration.y
               let z = data.acceleration.z

               // Use the accelerometer data in your app.
            }
        }
        if sensorsEnabled.contains(.gyro) {
            if let data = self.motion.gyroData {
               let x = data.rotationRate.x
               let y = data.rotationRate.y
               let z = data.rotationRate.z

               // Use the accelerometer data in your app.
            }
        }
        if sensorsEnabled.contains(.magnetometer) {
            if let data = self.motion.magnetometerData {
               let x = data.magneticField.x
               let y = data.magneticField.y
               let z = data.magneticField.z

               // Use the accelerometer data in your app.
            }
        }
        if sensorsEnabled.contains(.deviceMotion) {
            if let data = self.motion.deviceMotion {
                let x = data.userAcceleration.x
               let y = data.userAcceleration.y
               let z = data.userAcceleration.z

               // Use the accelerometer data in your app.
            }
        }
    }
    
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
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z

            // Use the accelerometer data in your app.
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
                    let x = data.rotationRate.x
                    let y = data.rotationRate.y
                    let z = data.rotationRate.z
                    
                    // Use the accelerometer data in your app.
                    // TODO: This
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
                if let data = self.motion.gyroData {
                    let x = data.rotationRate.x
                    let y = data.rotationRate.y
                    let z = data.rotationRate.z
                    
                    // Use the accelerometer data in your app.
                    // TODO: This
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
             if let data = self.motion.gyroData {
                 let x = data.rotationRate.x
                let y = data.rotationRate.y
                let z = data.rotationRate.z

                // Use the accelerometer data in your app.
                 // TODO: This
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
