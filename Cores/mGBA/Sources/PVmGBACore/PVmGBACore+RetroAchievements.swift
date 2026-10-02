//
//  PVmGBACore+RetroAchievements.swift
//  PVmGBACore
//
//  Full CoreRetroAchievements conformance for the mGBA emulator core.
//
//  ## Architecture
//
//  mGBA (upstream master) has no built-in RetroAchievements support, and no rcheevos
//  runtime evaluates achievements for this core yet. This Swift extension
//  handles Provenance-side state (active flag, hardcore mode) and
//  memory-region exposure.
//  TODO: Conform to `RcheevosRegionProviding` (PVRcheevosBridge) so the shared
//  rc_client session drives achievements, as the VBA-M core does.
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

    // TODO: Nothing reports achievement events (unlock, progress, challenge) to
    // this delegate yet; see the `RcheevosRegionProviding` TODO above.
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

        // Mark achievements as active so the hardcore save-state guard in
        // mGBAGameCoreBridge.m fires correctly.
        // NOTE: No rcheevos runtime evaluates achievements for this core yet.
        // Until that wiring exists, we set the active flag eagerly here so
        // hardcore restrictions are enforced.
        _bridge.achievementsActive = true
        _achievementsActive = true

        DLOG("mGBA achievements prepared for hash: \(gameHash), hardcore: \(_hardcoreMode)")
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
    /// No-op: there is no achievement runtime to tick for this core yet.
    public func tickAchievements() {
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
