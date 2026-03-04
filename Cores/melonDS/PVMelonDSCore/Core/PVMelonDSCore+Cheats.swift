//
//  PVMelonDSCore+Cheats.swift
//  PVMelonDS
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVCoreBridgeRetro

extension PVMelonDSCore: GameWithCheat {

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        // codeType and cheatIndex are not used by the libretro bridge's cheat API.
        _bridge.setCheat(code, setType: type, setEnabled: enabled)
        return true
    }

    @objc public var supportsCheatCode: Bool {
        return true
    }

    public var cheatCodeTypes: [String] {
        // NDS uses "Action Replay" as the cheat device name (not "Pro Action Replay").
        // CheatCodeTypes.init(string:) maps "Action Replay" → .proActionReplay for processing.
        return ["Action Replay"]
    }
}
