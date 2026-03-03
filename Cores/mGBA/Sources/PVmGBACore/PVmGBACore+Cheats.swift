//
//  PVmGBACore+Cheats.swift
//  PVmGBACore
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVmGBABridge

extension PVmGBACore: GameWithCheat {

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        return _bridge.setCheat(code, setType: type, setEnabled: enabled)
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }

    @objc public var supportsCheatCode: Bool {
        return true
    }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([
            .gameShark,
            .codeBreaker,
            .proActionReplay
        ])
    }
}
