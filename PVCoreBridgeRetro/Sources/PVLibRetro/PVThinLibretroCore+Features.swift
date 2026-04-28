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
//  - TransferPakSupport  (N64 Transfer Pak – Mupen64Plus-Next libretro core only)
//  - PaletteProviding    (see PVThinLibretroCore+Palette.swift — GB/GBC cores only)
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
// Unlike PVRetroArchCore — which bundles libretroarch.a (the full RetroArch
// frontend) and gets rcheevos for free via HAVE_CHEEVOS — the thin wrapper
// loads only a libretro core `.framework` that has no cheevos infrastructure.
// The *frontend* (us) drives rcheevos externally via PVCheevos / `rc_client`,
// reading memory directly through the libretro `retro_get_memory_data` /
// `retro_get_memory_size` API.
//
// This mirrors the pattern used by native PV cores (e.g. MupenGameCore,
// PVPicoDrive): we expose memory regions, and the external rcheevos client
// evaluates achievement conditions against them.

extension PVThinLibretroCore: CoreRetroAchievements {

    // RETRO_MEMORY_* ids — see libretro.h.
    private enum RetroMemoryID {
        static let saveRAM: UInt32   = 0
        static let rtc: UInt32       = 1
        static let systemRAM: UInt32 = 2
        static let videoRAM: UInt32  = 3
    }

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set {
            _achievementsDelegate = newValue
            wireFrontendAchievementBlocks()
        }
    }

    public func prepareAchievements(gameHash: String) async {
        guard !gameHash.isEmpty else { return }
        // Make sure the frontend's event blocks are pointing at the latest delegate.
        // achievementsDelegate is normally set by PVEmulatorVC before this runs, but
        // wiring here too guarantees the blocks are in place even if the order changes.
        wireFrontendAchievementBlocks()

        let hardcore = _hardcoreMode
        // Bridge the ObjC completion callback into the awaiting Task. The frontend
        // calls completion(success) on the URL session's delegate queue once the
        // load-game roundtrip returns — `withCheckedContinuation` keeps this
        // awaitable so PVEmulatorVC.startAchievementsIfNeeded() blocks until the
        // session is confirmed before reporting `achievementSessionManager`.
        let success: Bool = await withCheckedContinuation { continuation in
            _bridge
                .loadAchievements(
                    forGameHash: gameHash,
                    hardcore: hardcore
                ) { ok in
                continuation.resume(returning: ok)
            }
        }
        _achievementsActive = success
        if success {
            ILOG("ThinLibretro achievements active — hash: \(gameHash), hardcore: \(hardcore)")
        } else {
            WLOG("ThinLibretro achievements unavailable for hash: \(gameHash)")
        }
    }

    public func stopAchievements() {
        _achievementsActive = false
        _bridge.unloadAchievements()
        DLOG("ThinLibretro achievements stopped")
    }

    public func tickAchievements() {
        // No-op: PVThinLibretroFrontend.executeFrame already calls tickAchievements
        // on every emu-thread frame, so calling it again here would double-tick the
        // rcheevos runtime.
    }

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        var regions: [AchievementMemoryRegion] = []

        if let region = memoryRegion(forID: RetroMemoryID.systemRAM, kind: .systemRAM) {
            regions.append(region)
        }
        if let region = memoryRegion(forID: RetroMemoryID.saveRAM, kind: .savedRAM) {
            regions.append(region)
        }
        if let region = memoryRegion(forID: RetroMemoryID.videoRAM, kind: .videoRAM) {
            regions.append(region)
        }
        if let region = memoryRegion(forID: RetroMemoryID.rtc, kind: .hardwareController) {
            regions.append(region)
        }

        if regions.isEmpty {
            WLOG("ThinLibretro achievementMemoryRegions: core exposes no readable memory")
        }
        return regions
    }

    public var achievementsActive: Bool { _achievementsActive }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }

    // MARK: - Frontend block wiring

    /// Point the frontend's rcheevos event blocks at our delegate. Each block fires
    /// on the emulation thread; the delegate methods themselves are responsible for
    /// hopping to the main queue before touching UI state (matches the contract used
    /// by every other CoreRetroAchievements implementor).
    func wireFrontendAchievementBlocks() {
        _bridge.achievementTriggeredBlock = { [weak self] id, title, desc, points, badgeURL, hardcore in
            guard let delegate = self?._achievementsDelegate else { return }
            let notif = AchievementUnlockNotification(
                id: id, title: title, description: desc, points: points,
                badgeURL: badgeURL, isHardcore: hardcore
            )
            delegate.achievementUnlocked(notif)
        }
        _bridge.achievementProgressBlock = { [weak self] id, title, progressText in
            guard let delegate = self?._achievementsDelegate else { return }
            let notif = AchievementProgressNotification(
                achievementID: id, title: title, progressText: progressText
            )
            delegate.achievementProgress(notif)
        }
        _bridge.leaderboardStartedBlock = { [weak self] id, title, desc, score in
            guard let delegate = self?._achievementsDelegate else { return }
            let notif = AchievementLeaderboardNotification(
                leaderboardID: id, title: title, description: desc, scoreText: score
            )
            delegate.leaderboardStarted(notif)
        }
        _bridge.leaderboardFailedBlock = { [weak self] id in
            self?._achievementsDelegate?.leaderboardFailed(leaderboardID: id)
        }
        _bridge.leaderboardSubmittedBlock = { [weak self] id, title, desc, score in
            guard let delegate = self?._achievementsDelegate else { return }
            let notif = AchievementLeaderboardNotification(
                leaderboardID: id, title: title, description: desc, scoreText: score
            )
            delegate.leaderboardSubmitted(notif)
        }
    }

    // MARK: - Private

    private func memoryRegion(forID memoryID: UInt32,
                              kind: AchievementMemoryRegion.Kind) -> AchievementMemoryRegion? {
        var size: Int = 0
        guard let ptr = _bridge.memoryData(forID: memoryID, size: &size),
              size > 0 else {
            return nil
        }
        return AchievementMemoryRegion(base: ptr, size: size, kind: kind)
    }
}

// MARK: - SubCoreOptional
//
// Thin wrapper already conforms to CoreOptional (dynamic options from the core).
// Adding SubCoreOptional lets the options UI request per-subcore overrides.

extension PVThinLibretroCore: SubCoreOptional {
    public static func options(forSubcoreIdentifier identifier: String, systemName: String) -> [CoreOption]? {
        // Thin wrapper surfaces the core's own options via CoreOptional.
        // Return nil so callers fall through to the dynamic CoreOptional options.
        return nil
    }
}

// MARK: - TransferPakSupport
//
// Mupen64Plus-Next (the libretro port) exposes pak configuration via core options:
//   mupen64plus-pak1 … mupen64plus-pak4  — values: "none" | "memory" | "rumble" | "transfer"
//
// When a GB/GBC ROM is assigned, the pak type is set to "transfer" and the ROM
// path is written to the `mupen64plus-transfer-pak-path` core option. If that
// option is not present in a given core build, the assignment will still enable
// the Transfer Pak device type so that the core's internal config file or BIOS
// directory lookup will handle the ROM.
//
// NOTE: option key names verified against mupen64plus-next libretro source
// (libretro/mupen64plus-next, `libretro-options.h`). If a core build uses
// different keys, update the constants below and re-test with Pokémon Stadium 2.

extension PVThinLibretroCore: TransferPakSupport {

    // MARK: - Constants

    /// Libretro option key suffix for pak type (append "1"–"4").
    private static let pakTypeKeyBase = "mupen64plus-pak"

    /// Pak type value strings understood by mupen64plus-next libretro.
    private enum PakType: String {
        case none     = "none"
        case memory   = "memory"
        case rumble   = "rumble"
        case transfer = "transfer"
    }

    // MARK: - TransferPakSupport

    /// Returns 4 (one per N64 controller port) for Mupen64Plus-based libretro cores,
    /// 0 for all other cores so the Transfer Pak UI is hidden.
    public var transferPakSlotCount: Int {
        let coreId = (coreIdentifier ?? "").lowercased()
        return (coreId.contains("mupen64plus") || coreId.contains("mupen_64")) ? 4 : 0
    }

    public func setTransferPakROM(_ rom: TransferPakROM?, forPort port: Int) {
        guard transferPakSlotCount > 0 else { return }
        guard port >= 0 && port < 4 else { return }

        // Port options are 1-based ("mupen64plus-pak1" … "mupen64plus-pak4").
        let optionPort = port + 1
        let pakTypeKey = "\(Self.pakTypeKeyBase)\(optionPort)"

        if let rom = rom {
            _transferPakSlots[port] = rom
            _bridge.setCoreOption(pakTypeKey, value: PakType.transfer.rawValue)
            ILOG("ThinLibretroCore: Transfer Pak port \(port) → \(rom.romPath.lastPathComponent)")
        } else {
            _transferPakSlots.removeValue(forKey: port)
            _bridge.setCoreOption(pakTypeKey, value: PakType.memory.rawValue)
            ILOG("ThinLibretroCore: Transfer Pak port \(port) cleared → memory pak")
        }

        // mupen64plus-transfer-pak-path / -save-path are global (not per-port) options.
        // Always recompute from the lowest configured port so one call can never clobber
        // another port's previously-written global path.
        applyGlobalTransferPakPath()
    }

    public func transferPakROM(forPort port: Int) -> TransferPakROM? {
        return _transferPakSlots[port]
    }

    // MARK: - Internal helpers

    /// Re-apply all persisted Transfer Pak slots without overwriting the global
    /// mupen64plus-transfer-pak-path on each iteration.
    ///
    /// Used during `applyPlatformDefaults` — calling `setTransferPakROM` in a loop
    /// would overwrite the global path O(n) times; this method writes it exactly once.
    func reapplyTransferPakSlots() {
        for port in 0..<4 {
            let pakTypeKey = "\(Self.pakTypeKeyBase)\(port + 1)"
            if _transferPakSlots[port] != nil {
                _bridge.setCoreOption(pakTypeKey, value: PakType.transfer.rawValue)
            }
        }
        applyGlobalTransferPakPath()
    }

    // MARK: - Private helpers

    /// Write the global mupen64plus-transfer-pak-path / -save-path options exactly
    /// once, using the lowest configured port as the canonical primary slot.
    ///
    /// The core option is global (not per-port) so only one ROM can be active at a
    /// time. Deterministically choosing the lowest port avoids ordering surprises when
    /// multiple ports are configured.
    private func applyGlobalTransferPakPath() {
        if let primaryPort = _transferPakSlots.keys.sorted().first,
           let rom = _transferPakSlots[primaryPort] {
            _bridge.setCoreOption("mupen64plus-transfer-pak-path", value: rom.romPath.path)
            _bridge.setCoreOption("mupen64plus-transfer-pak-save-path",
                                  value: rom.savePath?.path ?? "")
            ILOG("ThinLibretroCore: global Transfer Pak path → port \(primaryPort) (\(rom.romPath.lastPathComponent))")
        } else {
            _bridge.setCoreOption("mupen64plus-transfer-pak-path", value: "")
            _bridge.setCoreOption("mupen64plus-transfer-pak-save-path", value: "")
            ILOG("ThinLibretroCore: global Transfer Pak path cleared (no active slots)")
        }
    }
}
