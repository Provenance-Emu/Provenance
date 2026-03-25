//
//  PVmGBACore+RetroAchievements.swift
//  PVmGBACore
//
//  Full CoreRetroAchievements conformance for the mGBA emulator core.
//
//  ## Architecture
//
//  mGBA ships `src/core/achievements.c` which wraps the rcheevos `rc_client`
//  internally. When `USE_ACHIEVEMENTS=1` is defined (Package.swift), that
//  file is compiled into libmGBA and driven via the core/bridge callbacks.
//  This Swift extension coordinates Provenance-side state and memory regions.
//
//  Memory regions:
//   - GBA : EWRAM (256 KiB), IWRAM (32 KiB), optional cart SRAM
//   - GB/GBC : WRAM (8–32 KiB), VRAM (8–16 KiB)
//
//  The ObjC bridge category (mGBAGameCoreBridge+Achievements) provides the
//  raw pointer accessors; this file assembles them into [AchievementMemoryRegion].
//
//  Thread safety: OSD delegate calls may arrive on the emulation thread.
//  Before touching UIKit, callers must dispatch to the main queue.
//

import Foundation
import PVCoreBridge
import PVmGBABridge
import PVLogging

extension PVmGBACore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    /// Prepare the achievement runtime for the currently-loaded ROM.
    ///
    /// - Parameter gameHash: MD5 hex string of the ROM file.
    public func prepareAchievements(gameHash: String) async {
        guard !gameHash.isEmpty else { return }

        // Sync hardcore mode to the bridge before activating.
        _bridge.hardcoreMode = _hardcoreMode

        // Do not unconditionally enable achievements here. The bridge is
        // responsible for starting the underlying achievements runtime for
        // `gameHash` and updating its own `achievementsActive` flag. Mirror
        // that state into the core so the UI enforces hardcore restrictions
        // only when the runtime is actually active.
        _achievementsActive = _bridge.achievementsActive

        if _achievementsActive {
            DLOG("mGBA achievements prepared for hash: \(gameHash), hardcore: \(_hardcoreMode)")
        } else {
            WLOG("mGBA achievements runtime not active for hash: \(gameHash); hardcore: \(_hardcoreMode)")
        }
    }

    /// Tear down the achievement runtime.
    public func stopAchievements() {
        _achievementsActive = false
        _bridge.achievementsActive = false
        DLOG("mGBA achievements stopped")
    }

    // MARK: - Per-frame tick

    /// Per-frame hook called by the emulation loop.
    ///
    /// mGBA evaluates achievement conditions internally via the `mCoreCallbacks`
    /// mechanism registered during core initialisation; no explicit tick call is
    /// required from this layer. This method is a no-op placeholder for future
    /// standalone `rc_client` bridging if needed.
    public func tickAchievements() {
        // No-op: mGBA drives its own achievement tick via mCoreCallbacks.
    }

    // MARK: - Memory regions

    /// Returns the GBA or GB/GBC memory regions to expose to the achievement runtime.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        if _bridge.isGBGame {
            return gbMemoryRegions()
        } else {
            return gbaMemoryRegions()
        }
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return _achievementsActive
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set {
            _hardcoreMode = newValue
            _bridge.hardcoreMode = newValue
        }
    }

    // MARK: - Private helpers

    private func gbaMemoryRegions() -> [AchievementMemoryRegion] {
        var regions: [AchievementMemoryRegion] = []
        regions.reserveCapacity(3)

        // EWRAM — External Working RAM (256 KiB, 0x02000000)
        var ewramSize: UInt = 0
        if let ptr = _bridge.ewramPointer(&ewramSize), ewramSize > 0 {
            regions.append(AchievementMemoryRegion(
                base: ptr,
                size: Int(ewramSize),
                kind: .systemRAM))
        }

        // IWRAM — Internal Working RAM (32 KiB, 0x03000000)
        var iwramSize: UInt = 0
        if let ptr = _bridge.iwramPointer(&iwramSize), iwramSize > 0 {
            regions.append(AchievementMemoryRegion(
                base: ptr,
                size: Int(iwramSize),
                kind: .systemRAM))
        }

        // Cart SRAM (optional, 0x0E000000)
        var sramSize: UInt = 0
        if let ptr = _bridge.sramPointer(&sramSize), sramSize > 0 {
            regions.append(AchievementMemoryRegion(
                base: ptr,
                size: Int(sramSize),
                kind: .savedRAM))
        }

        return regions
    }

    private func gbMemoryRegions() -> [AchievementMemoryRegion] {
        var regions: [AchievementMemoryRegion] = []
        regions.reserveCapacity(2)

        // WRAM — Working RAM (8 KiB DMG, 32 KiB GBC, starting at 0xC000)
        var wramSize: UInt = 0
        if let ptr = _bridge.gbWramPointer(&wramSize), wramSize > 0 {
            regions.append(AchievementMemoryRegion(
                base: ptr,
                size: Int(wramSize),
                kind: .systemRAM))
        }

        // VRAM — Video RAM (8 KiB DMG, 16 KiB GBC, at 0x8000)
        var vramSize: UInt = 0
        if let ptr = _bridge.gbVramPointer(&vramSize), vramSize > 0 {
            regions.append(AchievementMemoryRegion(
                base: ptr,
                size: Int(vramSize),
                kind: .videoRAM))
        }

        return regions
    }
}
