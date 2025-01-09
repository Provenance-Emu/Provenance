//
//  PVGearcolecoCore.swift
//  PVGearcolecoCore
//
//  Created by Joseph Mattiello on 10/06/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVEmulatorCore
import PVCoreBridge
import PVCoreObjCBridge
import PVCoreBridgeRetro

@objc
@objcMembers
open class PVGearcolecoCore: PVEmulatorCore {

    let _bridge: PVGearcolecoCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVGearcolecoCore: PVColecoVisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVColecoVisionButton, forPlayer player: Int) {
        (_bridge as! PVColecoVisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
