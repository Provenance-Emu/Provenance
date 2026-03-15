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

@objc @objcMembers
public class PVThinLibretroCore: PVEmulatorCore {

    // MARK: Lifecycle

    public lazy var _bridge: PVThinLibretroFrontend = .init()

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}
