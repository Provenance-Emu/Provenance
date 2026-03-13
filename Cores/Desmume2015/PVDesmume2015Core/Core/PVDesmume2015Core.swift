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
    /// Dual-screen skin layouts are not yet supported; disable until implemented.
    public override var supportsSkins: Bool { false }

    public override var supportsDualScreens: Bool { true }

    /// DeSmuME 2015 can use JIT for better DS performance; falls back to interpreter.
    public override var jitRequirement: PVJITRequirement { .optional(fallback: "Interpreter") }

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

extension PVDesmume2015Core: CoreOptional {
    public static var options: [CoreOption] {
        return Desmume2015Options.options
    }
}
