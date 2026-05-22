//
//  RetroAchievementsOSDDelegate.swift
//  PVCoreBridge
//
//  Delegate protocol that a core calls when achievement runtime events
//  occur. The UI layer implements this to drive on-screen notifications.
//
//  Design notes:
//  - Calls may arrive on the emulation thread; implementors must
//    dispatch to the main queue before touching UIKit.
//  - RetroArch-based cores (PVCoreBridgeRetro) render their own OSD inside
//    the GL buffer; the RetroArch bridge therefore only calls this delegate
//    for events that should surface outside GL (e.g. native iOS sounds or
//    CloudKit progress tracking).
//

import Foundation

/// Receives achievement runtime events from a core.
///
/// Implement this in your game-view controller or a dedicated coordinator
/// to display achievement toasts, challenge indicators, and leaderboard results.
///
/// All methods have default no-op implementations — implement only what you need.
public protocol RetroAchievementsOSDDelegate: AnyObject {

    /// An achievement was unlocked.
    func achievementUnlocked(_ notification: AchievementUnlockNotification)

    /// Measurable progress on an achievement changed.
    func achievementProgress(_ notification: AchievementProgressNotification)

    /// Show a persistent challenge indicator for an in-progress achievement.
    func showChallengeIndicator(_ notification: AchievementChallengeNotification)

    /// Hide the challenge indicator for a previously shown achievement.
    func hideChallengeIndicator(achievementID: UInt32)

    /// A leaderboard attempt started.
    func leaderboardStarted(_ notification: AchievementLeaderboardNotification)

    /// A leaderboard attempt was cancelled or failed.
    func leaderboardFailed(leaderboardID: UInt32)

    /// A leaderboard score was submitted.
    func leaderboardSubmitted(_ notification: AchievementLeaderboardNotification)

    /// rcheevos failed to load the game's achievement set for this session.
    /// Common causes (use `rcResult` to discriminate — values from `rc_error.h`):
    ///   `RC_NO_GAME_LOADED` / similar → the title isn't in the RA database
    ///   `RC_NO_RESPONSE` / 5xx → server / network failure
    ///   `RC_INVALID_CREDENTIALS` → user's saved login is stale
    /// Implementors should surface a categorised toast (network vs unknown
    /// game vs auth) so the user can tell why achievements aren't tracking.
    /// Previously these failures were logged only; the cheevos audit
    /// (Section J.1) flagged this as a HIGH-severity silent-failure gap.
    func sessionLoadFailed(rcResult: Int32, message: String?)
}

// MARK: - Default no-op implementations

public extension RetroAchievementsOSDDelegate {
    func achievementUnlocked(_ notification: AchievementUnlockNotification) {}
    func achievementProgress(_ notification: AchievementProgressNotification) {}
    func showChallengeIndicator(_ notification: AchievementChallengeNotification) {}
    func hideChallengeIndicator(achievementID: UInt32) {}
    func leaderboardStarted(_ notification: AchievementLeaderboardNotification) {}
    func leaderboardFailed(leaderboardID: UInt32) {}
    func leaderboardSubmitted(_ notification: AchievementLeaderboardNotification) {}
    func sessionLoadFailed(rcResult: Int32, message: String?) {}
}
