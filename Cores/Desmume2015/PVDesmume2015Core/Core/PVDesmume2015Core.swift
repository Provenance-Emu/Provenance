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

    
    public required init() {
        super.init()
        self.bridge = (PVDesmume2015CoreBridge() as! any ObjCBridgedCoreBridge)
    }
//
//    @objc open var padData : [[UInt8]] = Array(repeating: Array(repeating: 0, count: PVDSButtonCount), count: 4)
//
//    @objc open var _callbackQueue: dispatch_queue_t?
}

extension PVDesmume2015Core: PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (bridge as! PVDSSystemResponderClient).didPush(button, forPlayer: player)
    }

    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (bridge as! PVDSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

