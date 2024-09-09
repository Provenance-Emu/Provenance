//
//  File.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/13/24.
//

import Foundation

@objc public protocol ObjCBridgedCoreBridge: EmulatorCoreIOInterface, EmulatorCoreRunLoop, PVRenderDelegate {
 
}

// Protocol for Swift PVEmulatorCores to subscribe to if they marshall to an ObjC core of type <ObjCBridgedCoreBridge>
// which will also probalby be of class `PVCoreObjCBridge` but we don't inherit that for some reason I haven't decided yet.
public protocol ObjCBridgedCore<Core> {
    associatedtype Core = ObjCBridgedCoreBridge
//    typealias Core = any ObjCBridgedCoreBridge
    var core: Core { get }
}
