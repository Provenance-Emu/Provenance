//
//  PVEmulatorBridge.swift
//  PVEmulatorCore
//
//  Created by Joseph Mattiello on 9/2/24.
//

import Foundation

// Deprecated
//@available(*, deprecated, renamed: "ObjCBridgedCore")
//public protocol PVEmulatorCoreBridged<Bridge> : AnyObject {
//    associatedtype Bridge: ObjCBridgedCoreBridge
//    
//    var bridge: Bridge { get }
//}
//
//// This will probably never be used?
//public extension PVEmulatorCoreBridged where Self.Bridge: EmulatorCoreIOInterface {
//    public var romName: String? { bridge.romName ?? nil }
//    public var BIOSPath: String? { bridge.BIOSPath }
//    public var systemIdentifier: String? { bridge.systemIdentifier }
//    public var coreIdentifier: String? { bridge.coreIdentifier }
//    public var romMD5: String? { bridge.romMD5 }
//    public var romSerial: String? { bridge.romSerial }
//}
