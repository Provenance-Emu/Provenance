//
//  EmulatorCoreIOInterface.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public protocol EmulatorCoreIOInterface {
    @objc var romName: String? { get set }
    @objc var BIOSPath: String? { get set }
    @objc var systemIdentifier: String? { get set }
    @objc var coreIdentifier: String? { get set }
    @objc var romMD5: String? { get set }
    @objc var romSerial: String? { get set }
    @objc var extractArchive: Bool{ get set }

    @objc var discCount: UInt { get }

//    @objc var screenType: ScreenTypeObjC { get }
    
    @objc func loadFile(atPath path: String) throws
}

//public extension EmulatorCoreIOInterface where Self: ObjCBridgedCore, Bridge: EmulatorCoreIOInterface {
//    var romSerial: String? { bridge.romSerial ?? (self as EmulatorCoreIOInterface).romSerial ?? nil }
//    
//    var romName: String? {  bridge.romName ?? (self as EmulatorCoreIOInterface).romName ?? nil }
//    
//    var BIOSPath: String? { bridge.BIOSPath ?? (self as EmulatorCoreIOInterface).BIOSPath ?? nil }
//    
//    var systemIdentifier: String? { bridge.systemIdentifier ?? (self as EmulatorCoreIOInterface).systemIdentifier ?? nil }
//    
//    var coreIdentifier: String? { bridge.coreIdentifier ?? (self as EmulatorCoreIOInterface).coreIdentifier ?? nil }
//    
//    var romMD5: String? { bridge.romMD5 ?? (self as EmulatorCoreIOInterface).romMD5 ?? nil }
//    
//    var screenType: ScreenTypeObjC { (self as EmulatorCoreIOInterface).screenType }
    
//    func loadFile(atPath path: String) throws {
//        do {
//            try (self as EmulatorCoreIOInterface).loadFile(atPath: path)
//        } catch {
//            do {
//                try core.loadFile(atPath: path)
//            } catch {
//                throw error
//            }
//        }
//    }
//}
