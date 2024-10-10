//
//  File.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/13/24.
//

import Foundation

@objc public protocol PVEmulatorCoreT: EmulatorCoreRunLoop, EmulatorCoreIOInterface, EmulatorCoreVideoDelegate, EmulatorCoreSavesSerializer, EmulatorCoreAudioDataSource, EmulatorCoreRumbleDataSource, EmulatorCoreControllerDataSource, EmulatorCoreSavesDataSource {
}

@objc public protocol ObjCBridgedCoreBridge: NSObjectProtocol, PVEmulatorCoreT {
    init()
    func initialize()
}

// Protocol for Swift PVEmulatorCores to subscribe to if they marshall to an ObjC core of type <ObjCBridgedCoreBridge>
// which will also probalby be of class `PVCoreObjCBridge` but we don't inherit that for some reason I haven't decided yet.
public protocol ObjCBridgedCore {
    associatedtype Bridge = ObjCBridgedCoreBridge
//    typealias Core = any ObjCBridgedCoreBridge
    var bridge: Bridge! { get }
}

// This will probably never be used?
public extension ObjCBridgedCore where Self.Bridge: EmulatorCoreIOInterface {
    public var romName: String? { bridge.romName ?? nil }
    public var BIOSPath: String? { bridge.BIOSPath }
    public var systemIdentifier: String? { bridge.systemIdentifier }
    public var coreIdentifier: String? { bridge.coreIdentifier }
    public var romMD5: String? { bridge.romMD5 }
    public var romSerial: String? { bridge.romSerial }
    
    public func loadFile(atPath path: String) throws {
        do {
            try bridge.loadFile(atPath: path)
        } catch {
            do {
                try (self as? EmulatorCoreIOInterface)?.loadFile(atPath: path)
            } catch {
                throw error
            }
        }
    }
}
