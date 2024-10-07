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
open class PVGMECore: PVEmulatorCore {

    let _bridge: PVGMECoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVGMECore: PVNESSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVNESButton, forPlayer player: Int) {
        (_bridge as! PVNESSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
