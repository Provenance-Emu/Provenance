//
//  PVDesmume2015Core.swift
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 8/15/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVDesmume2015Core: PVEmulatorCore {

    lazy var _bridge: PVDesmume2015CoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVDesmume2015Core: PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

