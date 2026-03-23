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
}

public extension PVEmulatorViewController {

    // MARK: - Associated-object accessors

    /// The active `AchievementSessionManager` for the current game, or `nil`.
    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
    internal var achievementSessionManager: AchievementSessionManager? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.sessionManager) as? AchievementSessionManager }
        set { objc_setAssociatedObject(self, &AssociatedKeys.sessionManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

        // Hardcore mode forbids speed hacks — reset to normal immediately.
        if hardcore {
            core.gameSpeed = .normal
            (controllerViewController as? OSDFastForwardObserver)?.syncFastForwardDisplay()
        }

        // Create and start session manager.
        let manager = PVCheevos.sessionManager()
        achievementSessionManager = manager

        Task { [weak self, weak achievementsCore] in
            guard let self, let achievementsCore else { return }
            do {
                guard let manager = self.achievementSessionManager else { return }
                let response = try await manager.startSession(gameHash: gameHash)
                ILOG("RetroAchievements: session started for game \(manager.currentGameId ?? -1), \(response.unlocks?.count ?? 0) existing unlocks.")
                // Prepare the core's achievement runtime (rcheevos or equivalent).
                await achievementsCore.prepareAchievements(gameHash: gameHash)
                // achievementsActive is now true; enforce the speed restriction in
                // case the user enabled fast-forward in the window between this
                // function returning and the async session becoming active.
                if achievementsCore.hardcoreMode && achievementsCore.achievementsActive {
                    await MainActor.run {
                        self.core.gameSpeed = .normal
                        // Sync the OSD fast-forward button so it doesn't remain highlighted.
                        (self.controllerViewController as? OSDFastForwardObserver)?.syncFastForwardDisplay()
                    }
                }
            } catch AchievementSessionError.unknownGame(let hash) {
                ILOG("RetroAchievements: game hash \(hash) not in database, achievements unavailable.")
            } catch {
                ELOG("RetroAchievements: session start failed: \(error.localizedDescription)")
            }
        }
    }

    /// Call this before `core.stopEmulation()` to tear down the achievement session.
    func stopAchievements() {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return }

        (core as? (any CoreRetroAchievements))?.stopAchievements()

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
        return achievementsCore.hardcoreMode && achievementsCore.achievementsActive
    }

    // MARK: - Fast-forward guard

    /// Returns `true` when the current session is in hardcore mode and
    /// fast-forward should be blocked.
    func achievementsBlocksFastForward() -> Bool {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return false }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else { return false }
        return achievementsCore.hardcoreMode && achievementsCore.achievementsActive
    }

    /// Sets the core's game speed while respecting RetroAchievements hardcore mode.
    ///
    /// When `achievementsBlocksFastForward()` is `true`, requests to set `.fast` or
    /// `.veryFast` are silently ignored so alternative speed-changing UI (e.g. the
    /// Game Speed action sheet) cannot bypass the hardcore restriction.
    @MainActor func setGameSpeedRespectingAchievements(_ speed: GameSpeed) {
        if achievementsBlocksFastForward(), speed == .fast || speed == .veryFast {
            ILOG("Ignoring request to set fast game speed while RetroAchievements hardcore mode is active.")
            return
        }
        core.gameSpeed = speed
        (controllerViewController as? OSDFastForwardObserver)?.syncFastForwardDisplay()
    }

    // MARK: - Rewind guard

    /// Returns `true` when the current session is in hardcore mode and
    /// rewind should be blocked.
    func achievementsBlocksRewind() -> Bool {
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return false }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else { return false }
        return achievementsCore.hardcoreMode && achievementsCore.achievementsActive
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
