//
//  PVMupen64Plus-NXCore+Cheats.swift
//  PVMupen64Plus-NX
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVCoreBridgeRetro

extension PVMupen64PlusNXCore: GameWithCheat {

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        // Calls inherited PVLibRetroCoreBridge.setCheat(_:setType:setEnabled:) — not self-recursive.
        // cheatIndex and codeType are not used by this libretro core's cheat API.
        (self as PVLibRetroGLESCoreBridge).setCheat(code, setType: type, setEnabled: enabled)
        return true
    }

    @objc public var supportsCheatCode: Bool {
        return true
    }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([.gameShark])
    }
}
