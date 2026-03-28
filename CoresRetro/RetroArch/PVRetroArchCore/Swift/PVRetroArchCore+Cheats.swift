//
//  PVRetroArchCore+Cheats.swift
//  PVRetroArchCore
//
//  Created by Joseph Mattiello on 3/4/26.
//  Copyright © 2026 Provenance EMU. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVEmulatorCore
import PVLogging
import PVPrimitives

// MARK: - GameWithCheat
extension PVRetroArchCoreCore: GameWithCheat {

    @objc public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        do {
            ILOG("Calling setCheat \(code) \(type) \(codeType)")
            try self._bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            ILOG("Error setCheat \(error)")
            return false
        }
    }

    @objc public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }

    @objc
    public var supportsCheatCode: Bool { return true }

    @objc
    public var cheatCodeTypes: [String] {
        let coreID = (coreIdentifier ?? "").lowercased()
        let sysID  = (systemIdentifier ?? "").lowercased()

        // SNES – snes9x / bsnes  (must precede NES: "snes" contains "nes")
        if coreID.contains("snes9x") || coreID.contains("bsnes") || sysID.contains("snes") {
            return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
        }
        // Genesis / Mega Drive / SMS / Game Gear  (must precede NES: "genesis" contains "nes")
        if coreID.contains("genesis_plus") || coreID.contains("picodrive") ||
           sysID.contains("genesis") || sysID.contains("megadrive") ||
           sysID.contains("gamegear") || sysID.contains("mastersystem") {
            return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
        }
        // NES – fceumm / nestopia
        if coreID.contains("fceumm") || coreID.contains("nestopia") || sysID.contains("nes") {
            return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
        }
        // Game Boy / Game Boy Color – gambatte / sameboy
        if coreID.contains("gambatte") || coreID.contains("sameboy") ||
           (sysID.contains("gb") && !sysID.contains("gba")) {
            return CheatCodeTypesMakeStringArray([.gameGenie, .gameShark])
        }
        // Game Boy Advance – mgba / vba_next
        if coreID.contains("mgba") || coreID.contains("vba") || sysID.contains("gba") {
            return CheatCodeTypesMakeStringArray([.gameShark, .codeBreaker, .proActionReplay])
        }
        // Nintendo 64 – mupen64plus
        if coreID.contains("mupen") || sysID.contains("n64") || sysID.contains("nintendo64") {
            return CheatCodeTypesMakeStringArray([.gameSharkV2, .gameSharkV3])
        }
        // PlayStation – beetle_psx / mednafen_psx / pcsx_rearmed
        if coreID.contains("beetle_psx") || coreID.contains("mednafen_psx") ||
           coreID.contains("pcsx") || sysID.contains("psx") || sysID.contains("ps1") {
            return CheatCodeTypesMakeStringArray([.gameShark, .codeBreaker, .proActionReplay])
        }
        // MAME / arcade – raw codes only
        if coreID.contains("mame") || sysID.contains("mame") || sysID.contains("arcade") {
            return CheatCodeTypesMakeStringArray([.rawCode])
        }
        // Fallback: raw code works for any core that implements retro_cheat_set
        return CheatCodeTypesMakeStringArray([.rawCode])
    }
}
