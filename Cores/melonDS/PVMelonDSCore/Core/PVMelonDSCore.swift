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
public final class PVMelonDSCore: PVEmulatorCore {
    /// Dual-screen skin layouts are not yet supported; disable until implemented.
    public override var supportsSkins: Bool { false }

    public override var supportsDualScreens: Bool { true }


    lazy var _bridge: PVMelonDSCoreBridge = .init()
    
    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }
}

extension PVMelonDSCore: PVDSSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVDSButton, forPlayer player: Int) {
        (_bridge as! PVDSSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVMelonDSCore: CoreOptional {
    public static var options: [CoreOption] {
        return MelonDSOptions.options
    }
}
