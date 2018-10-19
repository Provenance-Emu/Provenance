//
//  PeripheralSetup.swift
//  
//
//  Created by Rob Reuss on 11/28/15.
//
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

#if os(OSX)
    import AppKit
#endif

#if !os(watchOS)

open class VgcPeripheralSetup: NSObject, NSCoding {
    
    open var profileType: ProfileType!
    open var motionActive = false
    open var enableMotionUserAcceleration = true
    open var enableMotionRotationRate = true
    open var enableMotionAttitude = true
    open var enableMotionGravity = true
    
    /*
    public var motionActive: Bool! {
        didSet {
            if (VgcManager.appRole == .Peripheral || appRole == .MultiplayerPeer) {
                if self.motionActive == true {
                    VgcManager.peripheral.motion.start()
                } else {
                    VgcManager.peripheral.motion.stop()
                }
            }
        }
    }
    */
    
#if os(iOS) || os(tvOS)
    open var backgroundColor: UIColor!
    
    public override init() {
        self.profileType = .ExtendedGamepad
        self.backgroundColor = UIColor.darkGray
    }
    
    public init(profileType: ProfileType, backgroundColor: UIColor) {
        self.profileType = profileType
        self.backgroundColor = backgroundColor
        super.init()
    }

#endif
    
#if os(OSX)
    public var backgroundColor: NSColor!
    
    public override init() {
        self.profileType = .ExtendedGamepad
        self.backgroundColor = NSColor.darkGray
    }
    
    public init(profileType: ProfileType, backgroundColor: NSColor) {
        self.profileType = profileType
        self.backgroundColor = backgroundColor
        super.init()
    }
#endif
    

required convenience public init(coder decoder: NSCoder) {
    
    self.init()

    #if os(OSX)
    self.backgroundColor = decoder.decodeObject(forKey: "backgroundColor") as! NSColor
    #endif
    
    #if os(iOS) || os(tvOS)
    self.backgroundColor = decoder.decodeObject(forKey: "backgroundColor") as! UIColor
    #endif
    
    self.profileType = ProfileType(rawValue: decoder.decodeInteger(forKey: "profileType"))

    self.motionActive = decoder.decodeBool(forKey: "motionActive")
    self.enableMotionUserAcceleration = decoder.decodeBool(forKey: "enableMotionUserAcceleration")
    self.enableMotionAttitude = decoder.decodeBool(forKey: "enableMotionAttitude")
    self.enableMotionGravity = decoder.decodeBool(forKey: "enableMotionGravity")
    self.enableMotionRotationRate = decoder.decodeBool(forKey: "enableMotionRotationRate")

}

    
    open override var description: String {
        
        var result: String = "\n"
        result += "Peripheral Setup:\n\n"
        result += "Profile Type:             \(self.profileType)\n"
        result += "Background Color:         \(self.backgroundColor)\n"
        result += "Motion:\n"
        result += "  Active:                 \(self.motionActive)\n"
        result += "  User Acceleration:      \(self.enableMotionUserAcceleration)\n"
        result += "  Gravity:                \(self.enableMotionGravity)\n"
        result += "  Rotation Rate:          \(self.enableMotionRotationRate)\n"
        result += "  Attitude:               \(self.enableMotionAttitude)\n"
        return result
        
    }
    
    // Test

    open func encode(with coder: NSCoder) {
        
        coder.encode(self.profileType.rawValue, forKey: "profileType")
        coder.encode(self.backgroundColor, forKey: "backgroundColor")
        coder.encode(self.motionActive, forKey: "motionActive")
        coder.encode(self.enableMotionUserAcceleration, forKey: "enableMotionUserAcceleration")
        coder.encode(self.enableMotionAttitude, forKey: "enableMotionAttitude")
        coder.encode(self.enableMotionGravity, forKey: "enableMotionGravity")
        coder.encode(self.enableMotionRotationRate, forKey: "enableMotionRotationRate")
    }
    
    // A copy of the deviceInfo object is made when forwarding it through a Bridge.
    //func copy(with zone: NSZone? = nil) -> Any {
    func copyWithZone(_ zone: NSZone?) -> AnyObject {
        let copy = VgcPeripheralSetup(profileType: profileType, backgroundColor: backgroundColor)
        return copy
    }
    
    open func sendToController(_ controller: VgcController) {
        
        if controller.hardwareController != nil {
            vgcLogDebug("Refusing to send peripheral setup to hardware controller")
            return
        }
        
        vgcLogDebug("Sending Peripheral Setup to Peripheral:")
        print(self)
        
        NSKeyedArchiver.setClassName("VgcPeripheralSetup", for: VgcPeripheralSetup.self)
        let element = VgcManager.elements.peripheralSetup
        element.value = NSKeyedArchiver.archivedData(withRootObject: self) as AnyObject
        controller.sendElementStateToPeripheral(element)
    }
    
    
}

#endif

/*
required convenience public init(coder decoder: NSCoder) {

#if os(OSX)
let backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! NSColor
#endif

#if os(iOS) || os(tvOS)
let backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! UIColor
#endif

let profileType = ProfileType(rawValue: decoder.decodeIntegerForKey("profileType"))

self.init(profileType: profileType!, backgroundColor: backgroundColor)

}

*/
