//
//  PVStellaGameCore+RetroAchievements.swift
//  PVStella
//
//  Conformance of PVStellaGameCore (Atari 2600) to CoreRetroAchievements.
//
//  rc_client runs in PVStellaBridge behind HAVE_RCHEEVOS, using libretro
//  RETRO_MEMORY_SYSTEM_RAM (128 bytes). rcheevos exposes this as bus addresses
//  0x0000…0x007F for RC_CONSOLE_ATARI_2600.
//

import Foundation
import PVCoreBridge
import PVStellaBridge

extension PVStellaGameCore: CoreRetroAchievements {

    // MARK: - Delegate

    /// OSD delegate for RetroAchievements toasts and overlays.
    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    /// Authenticates (if needed) and loads the game hash into `rc_client` on the bridge.
    public func prepareAchievements(gameHash: String) async {
        guard !gameHash.isEmpty else { return }
        await withCheckedContinuation { continuation in
            _bridge.loadAchievements(forGameHash: gameHash) { _ in
                continuation.resume()
            }
        }
    }

    /// Unloads the active game from `rc_client`.
    public func stopAchievements() {
        _bridge.unloadAchievements()
    }

    // MARK: - Per-frame tick

    // Bridge calls `tickAchievements` after each `retro_run` when HAVE_RCHEEVOS is set.

    // MARK: - Memory regions

    /// Live 6507 scratch RAM from Stella (`RETRO_MEMORY_SYSTEM_RAM`).
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        guard let ptr = _bridge.stellaSystemRAMPtr else { return [] }
        let byteCount = Int(_bridge.stellaSystemRAMSize)
        guard byteCount > 0 else { return [] }
        return [AchievementMemoryRegion(base: ptr, size: byteCount, kind: .systemRAM)]
    }

    // MARK: - State

    /// True after a successful `rc_client` game load for this session.
    public var achievementsActive: Bool {
        _bridge.achievementsActive
    }

    /// User hardcore preference; forwarded to the app’s achievement session guards.
    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}

// MARK: - AchievementsEvents (rc_client → OSD delegate)

extension PVStellaBridge {

    private var _ownerCore: PVStellaGameCore? {
        achievementsEventOwner as? PVStellaGameCore
    }

    /// Runs `work` on the main queue with a snapshot of the OSD delegate.
    private func withMainActorDelegate(_ work: @Sendable @escaping (RetroAchievementsOSDDelegate) -> Void) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        nonisolated(unsafe) let unsafeDelegate = delegate
        DispatchQueue.main.async { work(unsafeDelegate) }
    }

    /// Invoked from `pvstella_event_handler` when an achievement unlocks.
    @objc
    public func rcAchievementTriggeredWithID(
        _ achievementID: UInt32,
        title: String?,
        description: String?,
        points: UInt32,
        badgeURL: URL?,
        isHardcore: Bool
    ) {
        let notification = AchievementUnlockNotification(
            id: achievementID,
            title: title ?? "",
            description: description ?? "",
            points: points,
            badgeURL: badgeURL,
            isHardcore: isHardcore
        )
        withMainActorDelegate { $0.achievementUnlocked(notification) }
    }

    /// Invoked when rcheevos reports measurable progress for an achievement.
    @objc
    public func rcAchievementProgressWithID(
        _ achievementID: UInt32,
        title: String?,
        progressText: String?
    ) {
        let notification = AchievementProgressNotification(
            achievementID: achievementID,
            title: title ?? "",
            progressText: progressText ?? ""
        )
        withMainActorDelegate { $0.achievementProgress(notification) }
    }

    /// Invoked when a leaderboard attempt starts.
    @objc
    public func rcLeaderboardStartedWithID(
        _ leaderboardID: UInt32,
        title: String?,
        description: String?,
        scoreText: String?
    ) {
        let notification = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title ?? "",
            description: description ?? "",
            scoreText: scoreText ?? ""
        )
        withMainActorDelegate { $0.leaderboardStarted(notification) }
    }

    /// Invoked when a leaderboard submission fails.
    @objc
    public func rcLeaderboardFailedWithID(_ leaderboardID: UInt32) {
        withMainActorDelegate { $0.leaderboardFailed(leaderboardID: leaderboardID) }
    }

    /// Invoked when a leaderboard score is submitted successfully.
    @objc
    public func rcLeaderboardSubmittedWithID(
        _ leaderboardID: UInt32,
        title: String?,
        description: String?,
        scoreText: String?
    ) {
        let notification = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title ?? "",
            description: description ?? "",
            scoreText: scoreText ?? ""
        )
        withMainActorDelegate { $0.leaderboardSubmitted(notification) }
    }
}
