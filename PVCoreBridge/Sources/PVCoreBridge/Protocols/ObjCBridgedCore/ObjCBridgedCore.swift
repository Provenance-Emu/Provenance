//
//  File.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/13/24.
//

import Foundation

@objc public protocol ObjCBridgedCoreBridge: NSObjectProtocol, EmulatorCoreIOInterface, EmulatorCoreRunLoop, PVRenderDelegate {
 
}

// Protocol for Swift PVEmulatorCores to subscribe to if they marshall to an ObjC core of type <ObjCBridgedCoreBridge>
// which will also probalby be of class `PVCoreObjCBridge` but we don't inherit that for some reason I haven't decided yet.
public protocol ObjCBridgedCore<Bridge> {
    associatedtype Bridge = ObjCBridgedCoreBridge
//    typealias Core = any ObjCBridgedCoreBridge
    var bridge: Bridge { get }
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

//public extension ObjCBridgedCore where Self.Bridge: EmulatorCoreRunLoop {
//    dynamic var shouldStop: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.shouldStop)) {
//            return bridge.shouldStop!
//        } else {
//            return (self as? EmulatorCoreRunLoop)?.shouldStop ?? false
//        }
//    }
//    
//    dynamic var isRunning: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.isRunning)) {
//            return bridge.isRunning ?? (self as PVEmulatorCore).isRunning
//        } else {
//            return (self as PVEmulatorCore).isRunning
//        }
//    }
//    
//    dynamic var shouldResyncTime: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.shouldResyncTime)) {
//            return bridge.shouldResyncTime ?? (self as PVEmulatorCore).shouldResyncTime
//        } else {
//            return (self as PVEmulatorCore).shouldResyncTime
//        }
//    }
//    
//    dynamic var skipEmulationLoop: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.skipEmulationLoop)) {
//            return bridge.skipEmulationLoop ?? (self as PVEmulatorCore).skipEmulationLoop
//        } else {
//            return (self as PVEmulatorCore).skipEmulationLoop
//        }
//    }
//    
//    dynamic var skipLayout: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.skipLayout)) {
//            return bridge.skipLayout ?? (self as PVEmulatorCore).skipLayout
//        } else {
//            return (self as PVEmulatorCore).skipLayout
//        }
//    }
//    
//    dynamic var gameSpeed: GameSpeed {
//        get {
//            if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.gameSpeed)) {
//                return bridge.gameSpeed ?? (self as PVEmulatorCore).gameSpeed
//            } else {
//                return (self as PVEmulatorCore).gameSpeed
//            }
//        }
////        set {
////            if bridge.responds(to: #selector(setter: EmulatorCoreRunLoop.gameSpeed)) {
////                bridge.gameSpeed = newValue
////            } else {
////                (self as PVEmulatorCore).gameSpeed = newValue
////            }
////        }
//    }
//    
//    dynamic var emulationLoopThreadLock: NSLock {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.emulationLoopThreadLock)) {
//            return bridge.emulationLoopThreadLock ?? (self as PVEmulatorCore).emulationLoopThreadLock
//        } else {
//            return (self as PVEmulatorCore).emulationLoopThreadLock
//        }
//    }
//    
//    dynamic var frontBufferCondition: NSCondition {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.frontBufferCondition)) {
//            return bridge.frontBufferCondition ?? (self as PVEmulatorCore).frontBufferCondition
//        } else {
//            return (self as PVEmulatorCore).frontBufferCondition
//        }
//    }
//    
//    dynamic var frontBufferLock: NSLock {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.frontBufferLock)) {
//            return bridge.frontBufferLock ?? (self as PVEmulatorCore).frontBufferLock
//        } else {
//            return (self as PVEmulatorCore).frontBufferLock
//        }
//    }
//    
//    dynamic var isFrontBufferReady: Bool {
//        if bridge.responds(to: #selector(getter: EmulatorCoreRunLoop.isFrontBufferReady)) {
//            return bridge.isFrontBufferReady ?? (self as PVEmulatorCore).isFrontBufferReady
//        } else {
//            return (self as PVEmulatorCore).isFrontBufferReady
//        }
//    }
//        //    func startEmulation() {
////        if bridge.responds(to: #selector(EmulatorCoreRunLoop.startEmulation)) {
////            bridge.startEmulation()
////        } else {
////            self.startEmulation()
////        }
////    }
////
////    func resetEmulation() {
////        if bridge.responds(to: #selector(EmulatorCoreRunLoop.resetEmulation)) {
////            bridge.resetEmulation()
////        } else {
////            self.resetEmulation()
////        }
////    }
////
////    func stopEmulation() {
////        if bridge.responds(to: #selector(EmulatorCoreRunLoop.stopEmulation)) {
////            bridge.stopEmulation()
////        } else {
////            self.stopEmulation()
////        }
////    }
////
////    func runFrame() {
////        if bridge.responds(to: #selector(EmulatorCoreRunLoop.runFrame)) {
////            bridge.runFrame()
////        } else {
////            self.runFrame()
////        }
////    }
//
//    // Add more methods as needed, following the same pattern
//}
//
//
