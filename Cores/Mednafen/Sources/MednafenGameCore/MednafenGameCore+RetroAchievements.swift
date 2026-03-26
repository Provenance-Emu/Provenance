//
//  MednafenGameCore+RetroAchievements.swift
//  PVMednafen
//
//  Conformance of MednafenGameCore to CoreRetroAchievements.
//
//  ## Integration status
//
//  Phase 1 (PR #3510) — memory region wiring:
//  - achievementMemoryRegions() returns correct RAM pointers for each system
//    via the `mdfn_*_ptr()` / `mdfn_*_size()` C accessors defined at the end
//    of each system's .cpp file.
//  - executeFrame is overridden to call tickAchievements() after each frame.
//
//  Phase 2 (this file) — rcheevos runtime:
//  - prepareAchievements: authenticates via stored RA credentials and calls
//    rc_client_begin_load_game() through MednafenRcheevosClient.
//  - tickAchievements: calls rc_client_do_frame() once a session is active.
//  - stopAchievements: calls rc_client_unload_game().
//  - MednafenGameCore conforms to MednafenRcheevosDelegate and forwards events
//    to achievementsDelegate (RetroAchievementsOSDDelegate).
//
//  ## Prerequisites
//
//  Run `git submodule update --init PVRcheevos/rcheevos` before building.
//  The PVRcheevos/rcheevos submodule provides the rcheevos C sources compiled
//  into the CRcheevos SPM target that MednafenRcheevosObjC links against.
//
//  ## System memory maps (rcheevos address space)
//
//  | System  | Region           | rcheevos addr | Size         |
//  |---------|------------------|---------------|--------------|
//  | PSX     | Main RAM         | 0x00000000    | 2 MB         |
//  | NES     | CPU RAM          | 0x0000        | 2 KB         |
//  | SNES    | Work RAM         | 0x7E0000      | 128 KB       |
//  | PCE     | Base RAM         | 0x1F0000      | 8 KB / 32 KB |
//  | Saturn  | (disabled)       | —             | byte-order fix needed |
//

import Foundation
import PVCoreBridge
import PVPrimitives
import PVLogging
import MednafenGameCoreC
import MednafenGameCoreOptions
import MednafenRcheevosObjC

// MARK: - CoreRetroAchievements conformance

extension MednafenGameCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        // Build memory-region descriptors with their rcheevos base addresses.
        let regions = _rcheevosRegions()
        guard !regions.isEmpty else {
            DLOG("MednafenRcheevos: no memory regions for \(systemIdentifier ?? "unknown"); skipping.")
            return
        }

        // Tear down any existing session before creating a new one.
        // Without this, an in-flight URLSession callback on the old rc_client_t
        // could fire after _rcheevosClient is overwritten, calling back into a
        // deallocated MednafenRcheevosClient via the userdata pointer.
        _rcheevosClient?.unloadGame()
        _rcheevosClient = nil

        let client = MednafenRcheevosClient()
        client.delegate = self

        regions.withUnsafeBufferPointer { buf in
            client.setRegions(buf.baseAddress, count: UInt(buf.count))
        }

        _rcheevosClient = client

        // Authenticate + load game asynchronously; completion fires on main queue.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.loginAndLoadGame(gameHash) { [weak self] success, errorMessage in
                guard let self else {
                    continuation.resume()
                    return
                }
                if success {
                    self._achievementsSessionActive = true
                    ILOG("MednafenRcheevos: session active for \(gameHash).")
                } else {
                    WLOG("MednafenRcheevos: could not start session — \(errorMessage ?? "unknown error").")
                    self._rcheevosClient = nil
                }
                continuation.resume()
            }
        }
    }

    public func stopAchievements() {
        _rcheevosClient?.unloadGame()
        _rcheevosClient = nil
        _achievementsSessionActive = false
    }

    // MARK: - Per-frame tick

    /// Advance the achievement runtime by one emulated frame.
    ///
    /// Called from `executeFrame` (in MednafenGameCore.swift) after the Mednafen
    /// core has updated all memory.
    public func tickAchievements() {
        _rcheevosClient?.doFrame()
    }

    // MARK: - Memory regions

    /// Return the RAM regions rcheevos should read for the currently loaded system.
    ///
    /// Pointers come from the `mdfn_*_ptr()` C accessors appended to each system's
    /// mednafen .cpp file.  They are valid for the lifetime of the loaded game.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        _rcheevosRegions().compactMap { r in
            guard let ptr = r.ptr else { return nil }
            return AchievementMemoryRegion(base: UnsafeMutableRawPointer(ptr),
                                           size: Int(r.size),
                                           kind: .systemRAM)
        }
    }

    // MARK: - State

    public var achievementsActive: Bool {
        guard isRunning, _achievementsSessionActive else { return false }
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return false }
        switch sysID {
        case .PSX, .NES, .FDS, .PCE, .PCECD, .SGFX:
            return true
        case .Saturn:
            // Saturn RAM wiring requires byte-order correction; disabled until a future PR.
            return false
        case .SNES:
            return MednafenGameCoreOptions.mednafen_snesFast
        default:
            return false
        }
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }

    // MARK: - Private helpers

    /// Build an array of MednafenRcheevosRegion for the active system.
    ///
    /// Each entry pairs a raw RAM pointer with its base address in the rcheevos
    /// address space.  The read-memory callback in MednafenRcheevosClient uses
    /// these to satisfy rc_client address requests.
    private func _rcheevosRegions() -> [MednafenRcheevosRegion] {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return [] }
        switch sysID {

        case .PSX:
            // 2 MB main RAM (rcheevos 0x00000000–0x001FFFFF)
            guard let ptr = mdfn_psx_mainram_ptr() else { return [] }
            return [MednafenRcheevosRegion(rcAddress: 0x00000000,
                                           ptr: ptr,
                                           size: UInt32(mdfn_psx_mainram_size()))]

        case .NES, .FDS:
            // 2 KB CPU RAM (rcheevos 0x0000–0x07FF, mirrored to 0x1FFF)
            guard let ptr = mdfn_nes_ram_ptr() else { return [] }
            return [MednafenRcheevosRegion(rcAddress: 0x0000,
                                           ptr: ptr,
                                           size: UInt32(mdfn_nes_ram_size()))]

        case .SNES:
            // 128 KB Work RAM (rcheevos 0x7E0000–0x7FFFFF) — snes_faust only
            guard MednafenGameCoreOptions.mednafen_snesFast else { return [] }
            guard let ptr = mdfn_snes_faust_wram_ptr() else { return [] }
            return [MednafenRcheevosRegion(rcAddress: 0x7E0000,
                                           ptr: ptr,
                                           size: UInt32(mdfn_snes_faust_wram_size()))]

        case .Saturn:
            // Saturn Work RAM uses uint16 storage in Mednafen and requires
            // ne16_rbo_be address translation for correct 8-bit reads.
            // Exposing a raw uint8* pointer gives rcheevos scrambled bytes on
            // little-endian hosts.  Disabled until a shadow buffer / read-callback
            // implementation is added.
            return []

        case .PCE, .PCECD, .SGFX:
            // 8 KB base RAM for PCE/PCECD, 32 KB for SuperGrafx (rcheevos 0x1F0000)
            if MednafenGameCoreOptions.mednafen_pceFast {
                guard let ptr = mdfn_pce_fast_baseram_ptr() else { return [] }
                return [MednafenRcheevosRegion(rcAddress: 0x1F0000,
                                               ptr: ptr,
                                               size: UInt32(mdfn_pce_fast_baseram_size()))]
            } else {
                guard let ptr = mdfn_pce_baseram_ptr() else { return [] }
                return [MednafenRcheevosRegion(rcAddress: 0x1F0000,
                                               ptr: ptr,
                                               size: UInt32(mdfn_pce_baseram_size()))]
            }

        default:
            return []
        }
    }
}

// MARK: - MednafenRcheevosDelegate

/// Forward rcheevos events to the achievement OSD delegate.
extension MednafenGameCore: MednafenRcheevosDelegate {

    public func rcheevosDidUnlockAchievementID(_ achievementID: UInt32,
                                               title: String,
                                               description: String,
                                               points: UInt32,
                                               isHardcore: Bool) {
        let note = AchievementUnlockNotification(
            id: achievementID,
            title: title,
            description: description,
            points: points,
            badgeURL: nil,
            isHardcore: isHardcore)
        achievementsDelegate?.achievementUnlocked(note)
    }

    public func rcheevosShowProgress(forAchievementID achievementID: UInt32,
                                     title: String,
                                     progressText: String) {
        let note = AchievementProgressNotification(
            achievementID: achievementID,
            title: title,
            progressText: progressText)
        achievementsDelegate?.achievementProgress(note)
    }

    public func rcheevosShowChallenge(forAchievementID achievementID: UInt32) {
        let note = AchievementChallengeNotification(achievementID: achievementID, badgeURL: nil)
        achievementsDelegate?.showChallengeIndicator(note)
    }

    public func rcheevosHideChallenge(forAchievementID achievementID: UInt32) {
        achievementsDelegate?.hideChallengeIndicator(achievementID: achievementID)
    }

    public func rcheevosLeaderboardStarted(withID leaderboardID: UInt32,
                                           title: String,
                                           description: String,
                                           scoreText: String) {
        let note = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title,
            description: description,
            scoreText: scoreText)
        achievementsDelegate?.leaderboardStarted(note)
    }

    public func rcheevosLeaderboardFailed(withID leaderboardID: UInt32) {
        achievementsDelegate?.leaderboardFailed(leaderboardID: leaderboardID)
    }

    public func rcheevosLeaderboardSubmitted(withID leaderboardID: UInt32,
                                             title: String,
                                             description: String,
                                             scoreText: String) {
        let note = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title,
            description: description,
            scoreText: scoreText)
        achievementsDelegate?.leaderboardSubmitted(note)
    }
}
