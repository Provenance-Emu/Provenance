//
//  MupenGameCore+RetroAchievements.swift
//  PVMupenGameCore
//
//  CoreRetroAchievements conformance for the native Mupen64Plus N64 core.
//
//  ## Architecture
//
//  Achievement evaluation is driven externally by PVLibrary / PVCheevos using
//  the rcheevos `rc_client` API. This layer exposes:
//    1. N64 RDRAM memory (via the bridge's AUDIO_INFO.RDRAM pointer).
//    2. Lifecycle hooks (prepareAchievements / stopAchievements).
//    3. A per-frame tick stub (evaluation is memory-region-driven, not tick-driven).
//
//  Memory region:
//    N64 RDRAM — 8 MiB at virtual address 0x00000000 (RC_MEMORY_TYPE_SYSTEM_RAM).
//    Mupen64Plus always allocates 8 MiB; games that use only the base 4 MiB
//    leave the upper half zeroed. rcheevos is tolerant of this.
//
//  Thread safety:
//    OSD delegate calls may arrive on the emulation thread.
//    Callers must dispatch to the main queue before touching UIKit.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVMupen64PlusBridge

extension MupenGameCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    /// Prepare the achievement runtime for the currently-loaded ROM.
    ///
    /// - Parameter gameHash: MD5 hex string of the ROM file (used by PVLibrary
    ///   to resolve the RetroAchievements game ID; not consumed here directly).
    public func prepareAchievements(gameHash: String) async {
        guard !gameHash.isEmpty else { return }

        // Sync hardcore flag to the bridge so save-state load guards fire.
        _bridge.hardcoreMode = _hardcoreMode

        // Mark achievements as active. The memory regions returned by
        // achievementMemoryRegions() will be used by the rcheevos client
        // once it is started by PVLibrary.
        _bridge.achievementsActive = true
        _achievementsActive = true

        DLOG("Mupen64Plus achievements prepared — hash: \(gameHash), hardcore: \(_hardcoreMode)")
    }

    /// Tear down the achievement runtime.
    public func stopAchievements() {
        _achievementsActive = false
        _bridge.achievementsActive = false
        DLOG("Mupen64Plus achievements stopped")
    }

    // MARK: - Per-frame tick

    /// Per-frame hook called by the emulation loop.
    ///
    /// Achievement condition evaluation is handled by the PVLibrary rcheevos
    /// client via direct memory reads against the regions returned by
    /// `achievementMemoryRegions()`. No explicit tick is required from this layer.
    public func tickAchievements() {
        // No-op: evaluation is memory-region-driven by the external rcheevos client.
    }

    // MARK: - Memory regions

    /// Returns the N64 RDRAM region for the rcheevos client to read.
    ///
    /// The pointer is valid once the Mupen64Plus audio plugin has initialised
    /// (i.e., after the ROM is loaded). Returns an empty array before that point.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        var rdramSize: UInt = 0
        guard let ptr = _bridge.rdramPointer(&rdramSize), rdramSize > 0 else {
            WLOG("Mupen64Plus RDRAM not yet available — achievements memory region empty")
            return []
        }
        return [
            AchievementMemoryRegion(
                base: ptr,
                size: Int(rdramSize),
                kind: .systemRAM)
        ]
    }

    // MARK: - State

    public var achievementsActive: Bool { _achievementsActive }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set {
            _hardcoreMode = newValue
            _bridge.hardcoreMode = newValue
        }
    }
}
