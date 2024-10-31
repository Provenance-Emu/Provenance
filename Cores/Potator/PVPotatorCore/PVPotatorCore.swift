//
//  PVEP128EmuCore.swift
//  PVEP128EmuCore
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
open class PVPotatorCore: PVEmulatorCore {

    lazy var _bridge: PVPotatorCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVPotatorCore: PVSupervisionSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVSupervisionButton, forPlayer player: Int) {
        (_bridge as! PVSupervisionSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
