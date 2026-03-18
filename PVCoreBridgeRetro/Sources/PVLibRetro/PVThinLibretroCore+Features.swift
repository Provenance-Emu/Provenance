//
//  PVThinLibretroCore+Features.swift
//  PVCoreBridgeRetro
//
//  Adds feature protocol conformances to PVThinLibretroCore that mirror
//  what PVRetroArchCoreCore provides, so the rest of the app detects the
//  same capabilities regardless of which libretro backend is active.
//
//  Protocols added:
//  - DiscSwappable       (multi-disc game support via retro_disk_control_callback)
//  - GameWithCheat       (cheat code support via retro_cheat_set / retro_cheat_reset)
//  - CoreRetroAchievements (RetroAchievements – rcheevos runs inside the core itself)
//  - SubCoreOptional     (per-subcore option overrides, extends existing CoreOptional)
//

import Foundation
import PVCoreBridge
import PVLogging

// MARK: - DiscSwappable

extension PVThinLibretroCore: DiscSwappable {
    @MainActor
    public var currentGameSupportsMultipleDiscs: Bool {
        _bridge.currentGameSupportsMultipleDiscs
    }

    @MainActor
    public var numberOfDiscs: UInt {
        UInt(_bridge.numberOfDiscs)
    }

    @MainActor
    public func swapDisc(number: UInt) {
        _bridge.swapDisc(withNumber: number)
    }
}

// MARK: - GameWithCheat

extension PVThinLibretroCore: GameWithCheat {

    public var supportsCheatCode: Bool { true }

    public var cheatCodeTypes: [String] {
        let coreID = (coreIdentifier ?? "").lowercased()
        let sysID  = (systemIdentifier ?? "").lowercased()

        // SNES – must precede NES ("snes" contains "nes")
        if coreID.contains("snes9x") || coreID.contains("bsnes") || sysID.contains("snes") {
            return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
        }
        // Genesis / Mega Drive / SMS / Game Gear – must precede NES ("genesis" contains "nes")
        if coreID.contains("genesis_plus") || coreID.contains("picodrive") ||
           sysID.contains("genesis") || sysID.contains("megadrive") ||
           sysID.contains("gamegear") || sysID.contains("mastersystem") {
            return CheatCodeTypesMakeStringArray([.gameGenie, .proActionReplay])
        }
        // NES – fceumm / nestopia
        if coreID.contains("fceumm") || coreID.contains("nestopia") || sysID.contains(".nes") {
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

    public func setCheat(code: String, type: String, codeType: String, cheatIndex: UInt8, enabled: Bool) -> Bool {
        ILOG("ThinLibretro setCheat code=\(code) type=\(type) codeType=\(codeType) index=\(cheatIndex) enabled=\(enabled)")
        _bridge.setCheatCode(code, enabled: enabled, index: UInt32(cheatIndex))
        return true
    }

    public func resetCheatCodes() {
        _bridge.resetCheats()
    }
}

// MARK: - CoreRetroAchievements
//
// The libretro core itself drives rcheevos internally (via HAVE_CHEEVOS in its
// build flags).  We conform to CoreRetroAchievements so the app's achievements
// UI is offered, but the session lifecycle is a no-op — the core manages it.

extension PVThinLibretroCore: CoreRetroAchievements {

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    public func prepareAchievements(gameHash: String) async {
        // rcheevos is managed internally by the libretro core.
    }

    public func stopAchievements() {}

    public func tickAchievements() {}

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] { [] }

    public var achievementsActive: Bool { false }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}

// MARK: - SubCoreOptional
//
// Thin wrapper already conforms to CoreOptional (dynamic options from the core).
// Adding SubCoreOptional lets the options UI request per-subcore overrides.

extension PVThinLibretroCore: @preconcurrency SubCoreOptional {
    public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [CoreOption]? {
        // Thin wrapper surfaces the core's own options via CoreOptional.
        // Return nil so callers fall through to the dynamic CoreOptional options.
        return nil
    }
}
