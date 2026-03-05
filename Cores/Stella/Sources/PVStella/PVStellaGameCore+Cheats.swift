//
//  PVStellaGameCore+Cheats.swift
//  PVStella
//
//  Created by Provenance EMU on 3/4/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVStellaBridge

extension PVStellaGameCore: GameWithCheat {

    public func setCheat(code: String, type: String, codeType _: String, cheatIndex _: UInt8, enabled: Bool) -> Bool {
        do {
            try _bridge.setCheat(code, setType: type, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Stella setCheat error: \(error)")
            return false
        }
    }

    @objc public var supportsCheatCode: Bool {
        return true
    }

    public var cheatCodeTypes: [String] {
        // Stella (Atari 2600) cheat codes via CheatCodeDialog:
        // "Cheetah" (RAM-based direct memory writes) and "BankROM" (bank-ROM patches).
        // The libretro front-end exposes these as raw libretro cheat codes.
        return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}
