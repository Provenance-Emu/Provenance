//
//  VgcMotionManager.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//


import Foundation
#if !(os(tvOS)) && !(os(OSX))
import CoreMotion

open class VgcMotionManager: NSObject {

    #if os(iOS)
    fileprivate let elements = VgcManager.elements
    var controller: VgcController!
    #endif
    
    #if os(watchOS)
    @objc public var watchConnectivity: VgcWatchConnectivity!
    @objc public var elements: Elements!
    #endif
    
    @objc open var deviceSupportsMotion: Bool = false
    
    @objc open let manager = CMMotionManager()
    
    @objc open var active: Bool = false
    
    @objc var motionPollingTimer: Timer!
    
    ///
    /// Don't enable these unless they are really needed because they produce
    /// tons of data to be transmitted and clog the channels.
    ///
    @objc open var enableUserAcceleration = false
    @objc open var enableRotationRate = false
    @objc open var enableAttitude = false
    @objc open var enableGravity = false
    
    @objc open var enableLowPassFilter = true
    @objc open var enableAdaptiveFilter = true
    @objc open var cutOffFrequency: Double = 5.0
    var filterConstant: Double!
    
    @objc static var lastAttitudeX = 0.0, lastAttitudeY = 0.0, lastAttitudeZ = 0.0, lastAttitudeW = 0.0
    
    ///
    /// System can handle 60 updates/sec but only if a subset of motion factors are enabled,
    /// not all four.  If all four inputs are needed, update frequency should be reduced.
    ///
    @objc open var updateInterval = 1.0 / 60 {
        didSet {
            setupFilterConstant()
        }
    }
    
    func startPolling() {
        if active {
            active = false
            if let timer = motionPollingTimer { timer.invalidate() }
            motionPollingTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(pollMotionData), userInfo: nil, repeats: true)
            active = true
        }
    }
    
    @objc func setupFilterConstant()
    {
        
        let dt = updateInterval
        let RC = 1.0 / cutOffFrequency
        filterConstant = dt / (dt + RC)
        
    }
    
    @objc func pollMotionData() {

        guard let deviceMotionData = manager.deviceMotion else { return }

        var x, y, z, w: Double
    
        // Send data on the custom accelerometer channels
        if self.enableAttitude {
            
            (x, y, z, w) = self.filterX(((deviceMotionData.attitude.quaternion.x)), y: ((deviceMotionData.attitude.quaternion.y)), z: ((deviceMotionData.attitude.quaternion.z)), w: ((deviceMotionData.attitude.quaternion.w)))
            
            //vgcLogDebug("Old double: \(deviceMotionData?.attitude.quaternion.x), new float: \(x)")
            
            self.elements.motionAttitudeX.value = Float(x) as AnyObject
            self.elements.motionAttitudeY.value = Float(y) as AnyObject
            self.elements.motionAttitudeZ.value = Float(z) as AnyObject
            self.elements.motionAttitudeW.value = Float(w) as AnyObject
            
            self.sendElementState(self.elements.motionAttitudeY)
            self.sendElementState(self.elements.motionAttitudeX)
            self.sendElementState(self.elements.motionAttitudeZ)
            self.sendElementState(self.elements.motionAttitudeW)
        }
    
    
        // Send data on the custom accelerometer channels
        if self.enableUserAcceleration {
            
            (x, y, z, w) = self.filterX(((deviceMotionData.userAcceleration.x)), y: ((deviceMotionData.userAcceleration.y)), z: ((deviceMotionData.userAcceleration.z)), w: 0)
            
            self.elements.motionUserAccelerationX.value = Float(x) as AnyObject
            self.elements.motionUserAccelerationY.value = Float(y) as AnyObject
            self.elements.motionUserAccelerationZ.value = Float(z) as AnyObject
            
            self.sendElementState(self.elements.motionUserAccelerationX)
            self.sendElementState(self.elements.motionUserAccelerationY)
            self.sendElementState(self.elements.motionUserAccelerationZ)
        }
    
        // Gravity
    
        if self.enableGravity {
            
            (x, y, z, w) = self.filterX(((deviceMotionData.gravity.x)), y: ((deviceMotionData.gravity.y)), z: ((deviceMotionData.gravity.z)), w: 0)
            
            self.elements.motionGravityX.value = Float(x) as AnyObject
            self.elements.motionGravityY.value = Float(y) as AnyObject
            self.elements.motionGravityZ.value = Float(z) as AnyObject
            
            self.sendElementState(self.elements.motionGravityX)
            self.sendElementState(self.elements.motionGravityY)
            self.sendElementState(self.elements.motionGravityZ)
        }
    
        // Rotation Rate
    
        if self.enableRotationRate {
            
            (x, y, z, w) = self.filterX(((deviceMotionData.rotationRate.x)), y: ((deviceMotionData.rotationRate.y)), z: ((deviceMotionData.rotationRate.z)), w: 0)
            
            self.elements.motionRotationRateX.value = Float(x) as AnyObject
            self.elements.motionRotationRateY.value = Float(y) as AnyObject
            self.elements.motionRotationRateZ.value = Float(z) as AnyObject
            
            self.sendElementState(self.elements.motionRotationRateX)
            self.sendElementState(self.elements.motionRotationRateY)
            self.sendElementState(self.elements.motionRotationRateZ)
        }
    }
    
    @objc open func start() {
  
        #if os(iOS) || os(watchOS)
            
            vgcLogDebug("Attempting to start motion detection")
            
            #if os(iOS)
                if VgcManager.appRole == .EnhancementBridge {
                    if VgcController.enhancedController.peripheral.haveConnectionToCentral == false {
                        vgcLogDebug("Not starting motion because no connection")
                        return
                    }
                }
            #endif
            
            // No need to start if already active
            if active {
                vgcLogDebug("Not starting motion because already active")
                return
            }
            
            vgcLogDebug("Device supports: \(self.deviceSupportsMotion), motion available: \(self.manager.isDeviceMotionAvailable), accelerometer available: \(self.manager.isAccelerometerAvailable)")
            
            if deviceIsTypeOfBridge() || self.deviceSupportsMotion == true {
                
                active = true
                
                // iOS supports device motion, but the watch only supports direct accelerometer data
                if self.manager.isDeviceMotionAvailable {
                    
                    setupFilterConstant()
                    
                    vgcLogDebug("Starting device motion updating")
                    //manager.deviceMotionUpdateInterval = TimeInterval(updateInterval)
                    
                    manager.startDeviceMotionUpdates()
                    
                    startPolling()
                }
                
            } else if self.manager.isAccelerometerAvailable {
                    
                    vgcLogDebug("Starting accelerometer detection (for the Watch)")
                    self.manager.accelerometerUpdateInterval = TimeInterval(self.updateInterval)
                    self.manager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: { (accelerometerData, error) -> Void in
                        
                        /*
                        //vgcLogDebug("Device Motion: \(deviceMotionData!)")
                        
                        motionAttitudeY.value = Float((deviceMotionData?.attitude.quaternion.y)!)
                        motionAttitudeX.value = Float((deviceMotionData?.attitude.quaternion.x)!)
                        motionAttitudeZ.value = Float((deviceMotionData?.attitude.quaternion.z)!)
                        motionAttitudeW.value = Float((deviceMotionData?.attitude.quaternion.w)!)
                        
                        // Send data on the custom accelerometer channels
                        if enableAttitude {
                        self.sendElementValueToBridge(motionAttitudeY)
                        self.sendElementValueToBridge(motionAttitudeX)
                        self.sendElementValueToBridge(motionAttitudeZ)
                        self.sendElementValueToBridge(motionAttitudeW)
                        }
                        */
                        self.elements.motionUserAccelerationX.value = Float((accelerometerData?.acceleration.x)!) as AnyObject
                        self.elements.motionUserAccelerationY.value = Float((accelerometerData?.acceleration.y)!) as AnyObject
                        self.elements.motionUserAccelerationZ.value = Float((accelerometerData?.acceleration.z)!) as AnyObject
                        
                        vgcLogDebug("Sending accelerometer: \(String(describing: accelerometerData?.acceleration.x)) \(String(describing: accelerometerData?.acceleration.y)) \(String(describing: accelerometerData?.acceleration.z))")
                        
                        // Send data on the custom accelerometer channels
                        //if VgcManager.peripheral.motion.enableUserAcceleration {
                            self.sendElementState(self.elements.motionUserAccelerationX)
                            self.sendElementState(self.elements.motionUserAccelerationY)
                            self.sendElementState(self.elements.motionUserAccelerationZ)
                        //}
                        
                        /*
                        // Rotation Rate
                        
                        motionRotationRateX.value = Float((deviceMotionData?.rotationRate.x)!)
                        motionRotationRateY.value = Float((deviceMotionData?.rotationRate.y)!)
                        motionRotationRateZ.value = Float((deviceMotionData?.rotationRate.z)!)
                        
                        vgcLogDebug("Rotation: X \( Float((deviceMotionData?.rotationRate.x)!)), Y: \(Float((deviceMotionData?.rotationRate.y)!)), Z: \(Float((deviceMotionData?.rotationRate.z)!))")
                        
                        if enableRotationRate {
                        self.sendElementValueToBridge(motionRotationRateX)
                        self.sendElementValueToBridge(motionRotationRateY)
                        self.sendElementValueToBridge(motionRotationRateZ)
                        }
                        
                        // Gravity
                        
                        motionGravityX.value = Float((deviceMotionData?.gravity.x)!)
                        motionGravityY.value = Float((deviceMotionData?.gravity.y)!)
                        motionGravityZ.value = Float((deviceMotionData?.gravity.z)!)
                        
                        if enableGravity {
                        self.sendElementValueToBridge(motionGravityX)
                        self.sendElementValueToBridge(motionGravityY)
                        self.sendElementValueToBridge(motionGravityZ)
                        }
                        */
                    })
                    
                }
        #endif // End of block out of motion for tvOS and OSX

    }

    @objc open func stop() {
        #if os(iOS) || os(watchOS)
            vgcLogDebug("Stopping motion detection")
            if active == true {
                motionPollingTimer.invalidate()
                active = false
            }
        #endif
    }
    
    @objc func sendElementState(_ element: Element) {
        
        #if os(iOS)
            if deviceIsTypeOfBridge() {
                controller.peripheral.sendElementState(element)
            } else {
                VgcManager.peripheral.sendElementState(element)
            }

        #endif
        
        #if os(watchOS)
            watchConnectivity.sendElementState(element: element)
        #endif
        
    }
    
    // Filter functions
    @objc func Norm(_ x: Double, y: Double, z: Double) -> Double
    {
        return sqrt(x * x + y * y + z * z);
    }
    
    @objc func Clamp(_ v: Double, min: Double, max: Double) -> Double
    {
        if(v > max) { return max } else if (v < min) { return min } else { return v }
    }
    
    @objc let kAccelerometerMinStep =	0.02
    @objc let kAccelerometerNoiseAttenuation = 3.0
    
    func filterX(_ x: Double, y: Double, z: Double, w: Double) -> (Double, Double, Double, Double) {

        if enableLowPassFilter {
            
            var alpha = filterConstant;
            
            if enableAdaptiveFilter {
                let d = Clamp(fabs(Norm(x, y: y, z: z) - Norm(x, y: y, z: z)) / kAccelerometerMinStep - 1.0, min: 0.0, max: 1.0)
                alpha = (1.0 - d) * filterConstant / kAccelerometerNoiseAttenuation + d * filterConstant
            }
            return (x * alpha! + x * (1.0 - alpha!), y * alpha! + y * (1.0 - alpha!), z * alpha! + z * (1.0 - alpha!), w)
        } else {
            return (x, y, z, w)
        }
    }

 }
#endif
