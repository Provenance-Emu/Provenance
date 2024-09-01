//
//  EmulatorCoreIOInterface.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation

@objc public protocol EmulatorCoreIOInterface {
    @objc var romName: String? { get }
    @objc var BIOSPath: String? { get }
    @objc var systemIdentifier: String? { get }
    @objc var coreIdentifier: String? { get }
    @objc var romMD5: String? { get }
    @objc var romSerial: String? { get }

//    @objc var screenType: ScreenTypeObjC { get }
    
//    @objc func loadFile(atPath path: String) throws
}

public
extension EmulatorCoreIOInterface where Self: ObjCBridedCore {
    var romSerial: String? { (self as EmulatorCoreIOInterface).romSerial ?? core.romSerial }
    
    var romName: String? { (self as EmulatorCoreIOInterface).romName ?? core.romName }
    
    var BIOSPath: String? { (self as EmulatorCoreIOInterface).BIOSPath ?? core.BIOSPath }
    
    var systemIdentifier: String? { (self as EmulatorCoreIOInterface).systemIdentifier ?? core.systemIdentifier }
    
    var coreIdentifier: String? { (self as EmulatorCoreIOInterface).coreIdentifier ?? core.coreIdentifier }
    
    var romMD5: String? { (self as EmulatorCoreIOInterface).romMD5 ?? core.romMD5 }
    
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
