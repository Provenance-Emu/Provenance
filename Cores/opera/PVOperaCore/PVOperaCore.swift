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
open class PVOperaCore: PVEmulatorCore {

    let _bridge: PVOperaCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVOperaCore: CoreOptional {
    public static var options: [CoreOption] {
        return OperaOptions.options
    }
}

extension PVOperaCore: PV3DOSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PV3DOButton, forPlayer player: Int) {
        (_bridge as! PV3DOSystemResponderClient).didRelease(button, forPlayer: player)
    }
}
