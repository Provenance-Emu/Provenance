//
//  PVGBEmulatorCore+Cheats.swift
//  PVGambatte
//
//  Created by Joseph Mattiello on 3/3/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVGambatteBridge

extension PVGBEmulatorCore: GameWithCheat {

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        _bridge.setCheat(code, setType: type, setEnabled: enabled)
        return true
    }

    @objc public var supportsCheatCode: Bool {
        return true
    }

    public var cheatCodeTypes: [String] {
        return CheatCodeTypesMakeStringArray([.gameGenie, .gameShark])
    }
}
