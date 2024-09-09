//
//  EmulatorCoreIOInterface.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public protocol EmulatorCoreIOInterface {
    @objc optional var romName: String? { get }
    @objc var BIOSPath: String? { get }
    @objc var systemIdentifier: String? { get }
    @objc var coreIdentifier: String? { get }
    @objc var romMD5: String? { get }
    @objc var romSerial: String? { get }

//    @objc var screenType: ScreenTypeObjC { get }
    
//    @objc func loadFile(atPath path: String) throws
}

public
extension EmulatorCoreIOInterface where Self: ObjCBridgedCore, Self.Core: EmulatorCoreIOInterface {
    var romSerial: String? { core.romSerial ?? (self as EmulatorCoreIOInterface).romSerial ?? nil }
    
    var romName: String? {  core.romName ?? (self as EmulatorCoreIOInterface).romName ?? nil }
    
    var BIOSPath: String? { core.BIOSPath ?? (self as EmulatorCoreIOInterface).BIOSPath ?? nil }
    
    var systemIdentifier: String? { core.systemIdentifier ?? (self as EmulatorCoreIOInterface).systemIdentifier ?? nil }
    
    var coreIdentifier: String? { core.coreIdentifier ?? (self as EmulatorCoreIOInterface).coreIdentifier ?? nil }
    
    var romMD5: String? { core.romMD5 ?? (self as EmulatorCoreIOInterface).romMD5 ?? nil }
    
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
}
