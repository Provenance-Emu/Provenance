//
//  PVEmulatorViewController+Achievements.swift
//  PVUIBase
//
//  Wires the RetroAchievements session lifecycle into PVEmulatorViewController:
//
//    • startAchievementsIfNeeded()  — called right after core.startEmulation()
//    • stopAchievements()           — called before core.stopEmulation()
//    • loadSaveState guard          — blocks load in hardcore mode
//
//  The extension also makes PVEmulatorViewController conform to
//  RetroAchievementsOSDDelegate so it can forward events to the overlay.
//

import PVCoreBridge
import PVCheevos
import PVLogging
import PVSettings
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Stored properties via associated objects

private enum AssociatedKeys {
    static var sessionManager = "achievementSessionManager"
    static var overlayVC = "achievementOverlayVC"
    static var startToken = "achievementStartToken"
}

/// Cancellation token that lets `stopAchievements()` invalidate an in-flight
/// `startAchievementsIfNeeded` Task before it publishes `achievementSessionManager`.
/// Without this guard, a Task that completes after `stopAchievements()` clears
/// the manager would re-assign it, leaving an active session that is never stopped.
private final class StartToken: NSObject {
    var isCancelled = false
}

/// Shared user-facing message shown when fast-forward is blocked by
/// RetroAchievements Hardcore Mode.  Centralised here so all fast-forward
/// guard sites stay in sync with a single string change or future localisation update.
internal let hardcoreFastForwardBlockedMessage =
    "Fast-forward is disabled in RetroAchievements Hardcore Mode."

public extension PVEmulatorViewController {

    // MARK: - Associated-object accessors

    /// The active `AchievementSessionManager` for the current game, or `nil`.
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    internal var achievementSessionManager: AchievementSessionManager? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.sessionManager) as? AchievementSessionManager }
        set { objc_setAssociatedObject(self, &AssociatedKeys.sessionManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Token for the most recent `startAchievementsIfNeeded` Task.
    /// `stopAchievements()` cancels this so a slow network response can never
    /// publish `achievementSessionManager` after emulation has already stopped.
    private var achievementStartToken: StartToken? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.startToken) as? StartToken }
        set { objc_setAssociatedObject(self, &AssociatedKeys.startToken, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The overlay view controller that renders achievement toasts.
    internal var achievementOverlayViewController: AchievementOverlayViewController? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.overlayVC) as? AchievementOverlayViewController }
        set { objc_setAssociatedObject(self, &AssociatedKeys.overlayVC, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Lifecycle

    /// Call this after `core.startEmulation()` to initialize the achievement session.
    ///
    /// Does nothing if:
    /// - The user is not logged in to RetroAchievements.
    /// - The core does not conform to `CoreRetroAchievements`.
    /// - The game has no MD5 hash.
    func startAchievementsIfNeeded() {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return }
        guard Defaults[.retroAchievementsEnabled] else {
            DLOG("RetroAchievements: disabled in settings, skipping achievements.")
            return
        }
        guard PVCheevos.hasValidSession else {
            DLOG("RetroAchievements: no valid session, skipping achievements.")
            return
        }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else {
            DLOG("RetroAchievements: core \(core.description) does not conform to CoreRetroAchievements.")
            return
        }
        guard let gameHash = game?.md5Hash, !gameHash.isEmpty else {
            WLOG("RetroAchievements: game has no MD5 hash, skipping achievements.")
            return
        }

        // Attach the OSD overlay if not already present.
        setupAchievementOverlayIfNeeded()

        // Set the OSD delegate so the core can fire callbacks.
        achievementsCore.achievementsDelegate = self

        // Apply hardcore mode from settings.
        let hardcore = Defaults[.retroAchievementsHardcoreEnabled]
        achievementsCore.hardcoreMode = hardcore

        // Create the session manager but do NOT assign it yet.
        // The guard helpers (achievementsBlocksFastForward, achievementsBlocksSaveStateLoad)
        // use achievementSessionManager != nil as a proxy for "active session", so we only
        // assign it after startSession() succeeds.  This avoids a window where the manager
        // exists but the session has not yet been confirmed by the server.
        let manager = PVCheevos.sessionManager()

        // Create a cancellation token for this start attempt.  If stopAchievements() is
        // called while the Task is still awaiting the network, it will mark the token
        // cancelled so the Task does not publish achievementSessionManager after the
        // emulator has already stopped — preventing a session that can never be torn down.
        let token = StartToken()
        achievementStartToken = token

        Task { [weak self, weak achievementsCore] in
            guard let self, let achievementsCore else { return }
            do {
                let response = try await manager.startSession(gameHash: gameHash)
                ILOG("RetroAchievements: session started for game \(manager.currentGameId ?? -1), \(response.unlocks?.count ?? 0) existing unlocks.")
                // Session confirmed active — verify stopAchievements() hasn't run since
                // we kicked off this Task. If it has, tear down the session we just
                // started so the manager's ping loop does not keep running.
                if token.isCancelled {
                    await manager.stopSession()
                    return
                }

                // Expose the manager and prepare the core.
                await MainActor.run {
                    self.achievementSessionManager = manager
                }
                // Prepare the core's achievement runtime (rcheevos or equivalent).
                await achievementsCore.prepareAchievements(gameHash: gameHash)
                // If hardcore is enabled, enforce the speed restriction now that the
                // session has successfully started. We use hardcoreMode alone here
                // (not achievementsActive) because we are already in the success path
                // of startSession+prepareAchievements, and some cores (e.g. RetroArch)
                // always report achievementsActive == false even when a session is live.
                if achievementsCore.hardcoreMode {
                    await MainActor.run {
                        guard !token.isCancelled else { return }
                        self.core.gameSpeed = .normal
                        // Sync the OSD fast-forward button so it doesn't remain highlighted.
                        (self.controllerViewController as? OSDFastForwardObserver)?.syncFastForwardDisplay()
                    }
                }
            } catch AchievementSessionError.unknownGame(let hash) {
                ILOG("RetroAchievements: game hash \(hash) not in database, achievements unavailable.")
                // achievementSessionManager was never set, so no cleanup needed.
            } catch {
                ELOG("RetroAchievements: session start failed: \(error.localizedDescription)")
                // achievementSessionManager was never set, so no cleanup needed.
            }
        }
    }

    /// Call this before `core.stopEmulation()` to tear down the achievement session.
    func stopAchievements() {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return }

        (core as? (any CoreRetroAchievements))?.stopAchievements()

        // Cancel any in-flight start Task so it cannot publish achievementSessionManager
        // after we've already cleared it below.
        achievementStartToken?.isCancelled = true
        achievementStartToken = nil

        let manager = achievementSessionManager
        achievementSessionManager = nil
        Task { await manager?.stopSession() }

        removeAchievementOverlay()
    }

    // MARK: - Save state guard

    /// Returns `true` when the current session is in hardcore mode and
    /// a save-state load should be blocked.
    func achievementsBlocksSaveStateLoad() -> Bool {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return false }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else { return false }
        guard achievementsCore.hardcoreMode else { return false }
        // achievementsActive is authoritative when true; fall back to checking whether
        // a session manager exists for cores (e.g. RetroArch) that always report false.
        return achievementsCore.achievementsActive || achievementSessionManager != nil
    }

    // MARK: - Fast-forward guard

    /// Returns `true` when the current session is in hardcore mode and
    /// fast-forward should be blocked.
    func achievementsBlocksFastForward() -> Bool {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return false }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else { return false }
        guard achievementsCore.hardcoreMode else { return false }
        // achievementsActive is authoritative when true; fall back to checking whether
        // a session manager exists for cores (e.g. RetroArch) that always report false.
        return achievementsCore.achievementsActive || achievementSessionManager != nil
    }

    /// Sets the core's game speed while respecting RetroAchievements hardcore mode.
    ///
    /// When `achievementsBlocksFastForward()` is `true`, requests to set `.fast` or
    /// `.veryFast` are rejected and a user-facing error alert is presented, consistent
    /// with the OSD button and Delta skin button guards.
    @MainActor func setGameSpeedRespectingAchievements(_ speed: GameSpeed) {
        if achievementsBlocksFastForward(), speed == .fast || speed == .veryFast {
            ILOG("Ignoring request to set fast game speed while RetroAchievements hardcore mode is active.")
            #if canImport(UIKit)
            presentError(hardcoreFastForwardBlockedMessage, source: view)
            #endif
            return
        }
        core.gameSpeed = speed
        (controllerViewController as? OSDFastForwardObserver)?.syncFastForwardDisplay()
    }

    // MARK: - Rewind guard

    /// Returns `true` when the current session is in hardcore mode and
    /// rewind should be blocked.
    ///
    /// **Why is this not yet wired?**
    /// Rewind in the current codebase is a RetroArch/core-level setting
    /// (`rewind_enable`) rather than an interactive Swift UI toggle.  There is
    /// no single PVUI call-site to guard at this time.  This method is
    /// intentionally provided as a ready-to-use guard so that future rewind UI
    /// (Delta-skin button, OSD button, or settings toggle) can call it directly
    /// without duplicating the hardcore-check logic.
    ///
    /// When wiring, also apply the same `achievementsActive || achievementSessionManager != nil`
    /// pattern used by `achievementsBlocksFastForward()` so RetroArch cores are covered.
    func achievementsBlocksRewind() -> Bool {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return false }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else { return false }
        guard achievementsCore.hardcoreMode else { return false }
        return achievementsCore.achievementsActive || achievementSessionManager != nil
    }

    // MARK: - Overlay management

    private func setupAchievementOverlayIfNeeded() {
        guard achievementOverlayViewController == nil else { return }
        let overlay = AchievementOverlayViewController()
        achievementOverlayViewController = overlay
        addChild(overlay)
        view.addSubview(overlay.view)
        overlay.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.view.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        overlay.didMove(toParent: self)
    }

    private func removeAchievementOverlay() {
        guard let overlay = achievementOverlayViewController else { return }
        overlay.willMove(toParent: nil)
        overlay.view.removeFromSuperview()
        overlay.removeFromParent()
        achievementOverlayViewController = nil
    }
}

// MARK: - RetroAchievementsOSDDelegate

extension PVEmulatorViewController: RetroAchievementsOSDDelegate {

    public func achievementUnlocked(_ notification: AchievementUnlockNotification) {
        Task { @MainActor [weak self] in
            self?.achievementOverlayViewController?.showUnlock(notification)
        }
        // Also post the award to the RA server.
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return }
        let manager = achievementSessionManager
        let hardcore = notification.isHardcore
        let id = notification.id
        Task { await manager?.awardAchievement(id: id, hardcore: hardcore) }
    }

    public func achievementProgress(_ notification: AchievementProgressNotification) {
        // Progress is shown by rcheevos natively; no additional OSD needed here.
    }

    public func showChallengeIndicator(_ notification: AchievementChallengeNotification) {
        Task { @MainActor [weak self] in
            self?.achievementOverlayViewController?.showChallengeIndicator(notification)
        }
    }

    public func hideChallengeIndicator(achievementID: UInt32) {
        Task { @MainActor [weak self] in
            self?.achievementOverlayViewController?.hideChallengeIndicator(achievementID: achievementID)
        }
    }

    public func leaderboardStarted(_ notification: AchievementLeaderboardNotification) {}
    public func leaderboardFailed(leaderboardID: UInt32) {}
    public func leaderboardSubmitted(_ notification: AchievementLeaderboardNotification) {}
}
