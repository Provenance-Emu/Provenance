//
//  PVThinLibretroCore.swift
//  PVCoreBridgeRetro
//
//  Created by Joe Mattiello on 2026-03-15.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Swift `PVEmulatorCore` subclass that wraps `PVThinLibretroFrontend`.
//  This class is the `principleClass` registered in dynamically-scanned
//  libretro core plists, giving `PVCoreFactory.createInstance(forSystem:)`
//  a proper `PVEmulatorCore` subclass to instantiate.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge

/// Internal to keep `PVEmulatorCore` out of the generated
/// `PVCoreBridgeRetro-Swift.h` header (which would break every
/// downstream ObjC core target). `@objc` ensures the class is
/// registered with the ObjC runtime so `NSClassFromString` /
/// `principleClass` lookups still work.
@objc @objcMembers
class PVThinLibretroCore: PVEmulatorCore {

    // MARK: Lifecycle

    lazy var _bridge: PVThinLibretroFrontend = .init()

    required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}
