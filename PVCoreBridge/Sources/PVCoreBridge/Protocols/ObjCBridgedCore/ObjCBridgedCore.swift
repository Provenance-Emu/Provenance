//
//  File.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/13/24.
//

import Foundation

@objc public protocol ObjCBridgedCoreBridge: EmulatorCoreIOInterface, PVRenderDelegate {
 
}

@objc public protocol ObjCBridedCore {
    var core: ObjCBridgedCoreBridge { get }
}
