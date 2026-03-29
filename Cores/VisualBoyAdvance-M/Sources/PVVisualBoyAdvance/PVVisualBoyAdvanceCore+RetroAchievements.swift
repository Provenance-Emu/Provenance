//
//  PVVisualBoyAdvanceCore+RetroAchievements.swift
//  PVVisualBoyAdvance
//
//  Conformance of PVVisualBoyAdvanceCore to CoreRetroAchievements.
//
//  rc_client runs in PVVisualBoyAdvanceBridge (HAVE_RCHEEVOS), matching the
//  Gambatte integration: login/load via NSUserDefaults credentials, per-frame
//  tick from executeFrame, memory from live EWRAM/IWRAM/VRAM.
//

import Foundation
import PVCoreBridge
import PVVisualBoyAdvanceBridge

extension PVVisualBoyAdvanceCore: CoreRetroAchievements {

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

    // Bridge calls tickAchievements from executeFrameSkippingFrame: when HAVE_RCHEEVOS is set.

    // MARK: - Memory regions

    /// Live GBA regions for rcheevos: EWRAM 256 KiB, IWRAM 32 KiB, VRAM 96 KiB.
    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        enum Sizes {
            static let ewramBytes = 256 * 1024
            static let iwramBytes = 32 * 1024
            static let vramBytes = 96 * 1024
        }
        var regions: [AchievementMemoryRegion] = []
        regions.reserveCapacity(3)

        if let ptr = _bridge.ewramBasePtr {
            regions.append(AchievementMemoryRegion(base: ptr, size: Sizes.ewramBytes, kind: .systemRAM))
        }
        if let ptr = _bridge.iwramBasePtr {
            regions.append(AchievementMemoryRegion(base: ptr, size: Sizes.iwramBytes, kind: .systemRAM))
        }
        if let ptr = _bridge.vbaVramBasePtr {
            regions.append(AchievementMemoryRegion(base: ptr, size: Sizes.vramBytes, kind: .videoRAM))
        }
        return regions
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

extension PVVisualBoyAdvanceBridge {

    private var _ownerCore: PVVisualBoyAdvanceCore? {
        achievementsEventOwner as? PVVisualBoyAdvanceCore
    }

    /// Runs `work` on the main queue with a snapshot of the OSD delegate.
    private func withMainActorDelegate(_ work: @Sendable @escaping (RetroAchievementsOSDDelegate) -> Void) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        nonisolated(unsafe) let unsafeDelegate = delegate
        DispatchQueue.main.async { work(unsafeDelegate) }
    }

    /// Invoked from `pvvba_event_handler` when an achievement unlocks.
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
