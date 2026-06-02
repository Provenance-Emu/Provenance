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
import PVRcheevos
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
    static var sessionPoints = "achievementSessionPoints"
}

/// Cancellation token that lets `stopAchievements()` invalidate an in-flight
/// `startAchievementsIfNeeded` Task before it publishes `achievementSessionManager`.
/// Without this guard, a Task that completes after `stopAchievements()` clears
/// the manager would re-assign it, leaving an active session that is never stopped.
private final class StartToken: NSObject, @unchecked Sendable {
    var isCancelled = false
}

/// Shared user-facing message shown when fast-forward is blocked by
/// RetroAchievements Hardcore Mode.  Centralised here so all fast-forward
/// guard sites stay in sync with a single string change or future localisation update.
internal let hardcoreFastForwardBlockedMessage =
    "Fast-forward is disabled in RetroAchievements Hardcore Mode."

/// User-facing message shown when a slow-motion request is rejected because of
/// RetroAchievements Hardcore Mode (slow-motion is an unfair advantage, blocked
/// symmetrically with fast-forward — matching RetroArch hardcore behaviour).
internal let hardcoreSlowMotionBlockedMessage =
    "Slow-motion is disabled in RetroAchievements Hardcore Mode."

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
        // [CHEEVOS-DIAG] Entry — proves we got past startEmulation and into the cheevos start path.
        ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded ENTER core=\(type(of: core)) systemID=\(core.systemIdentifier ?? "nil")")
        guard #available(iOS 15.0, tvOS 15.0, macOS 12.0, *) else { return }
        guard Defaults[.retroAchievementsEnabled] else {
            DLOG("RetroAchievements: disabled in settings, skipping achievements.")
            ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded EXIT: retroAchievementsEnabled=false")
            return
        }
        guard PVCheevos.hasValidSession else {
            DLOG("RetroAchievements: no valid session, skipping achievements.")
            ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded EXIT: hasValidSession=false")
            return
        }
        guard let achievementsCore = core as? (any CoreRetroAchievements) else {
            DLOG("RetroAchievements: core \(core.description) does not conform to CoreRetroAchievements.")
            ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded EXIT: core does not conform to CoreRetroAchievements (\(type(of: core)))")
            return
        }
        guard let fileMD5 = game?.md5Hash, !fileMD5.isEmpty else {
            WLOG("RetroAchievements: game has no MD5 hash, skipping achievements.")
            ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded EXIT: game has no MD5 hash (game=\(game?.title ?? "nil"))")
            return
        }
        // [CHEEVOS-DIAG] Dump everything we feed into the start path so the tester
        // log shows exactly what hash + path + system the cheevos pipeline saw.
        let diagSystemID = core.systemIdentifier ?? "nil"
        let diagTitle = game?.title ?? "nil"
        let diagRomPath = game?.file?.url?.path ?? "nil"
        let diagHardcoreSetting = Defaults[.retroAchievementsHardcoreEnabled]
        ILOG("[CHEEVOS-DIAG] startAchievementsIfNeeded inputs systemID=\(diagSystemID) title=\(diagTitle) fileMD5=\(fileMD5) romPath=\(diagRomPath) hardcoreSetting=\(diagHardcoreSetting)")
        // RA expects a console-aware hash. Our import pipeline already applies
        // SystemIdentifier.offset to strip headers for iNES NES, A7800, Lynx,
        // SNES copier, and normalises byte-swapped N64 to z64 — so the stored
        // file MD5 already matches RA's expected hash for those systems.
        // Try it first (fast path, avoids re-reading the ROM); fall back to
        // rcheevos auto-detect only when the server doesn't recognise it.
        // The fallback is required for CD systems (which hash system-area +
        // boot exe rather than the disc image) and any cart format we don't
        // header-strip during import.
        let romPath = game?.file?.url?.path ?? ""

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
        guard let manager = PVCheevos.sessionManager() else {
            ELOG("RetroAchievements: sessionManager() returned nil, cannot start session")
            return
        }

        // Create a cancellation token for this start attempt.  If stopAchievements() is
        // called while the Task is still awaiting the network, it will mark the token
        // cancelled so the Task does not publish achievementSessionManager after the
        // emulator has already stopped — preventing a session that can never be torn down.
        let token = StartToken()
        achievementStartToken = token

        Task { [weak self, weak achievementsCore] in
            guard let self, let achievementsCore else { return }

            // Try the candidate hashes in order: file MD5 first (fast path —
            // already matches RA for headerless and header-stripped carts);
            // then the rcheevos auto-detect hash (CD systems and any format
            // we don't strip during import). Computing the native hash is
            // deferred until the MD5 attempt fails so we don't pay the cost
            // for the common case.
            let winningHash: String
            let response: StartSessionResponse
            // Captured for toast posting on the main actor below.
            let gameTitle = await MainActor.run { self.game?.title ?? "this game" }
            do {
                response = try await manager.startSession(gameHash: fileMD5)
                winningHash = fileMD5
            } catch AchievementSessionError.unknownGame {
                ILOG("RetroAchievements: file MD5 \(fileMD5) not in database, trying rcheevos native hash…")
                guard !romPath.isEmpty,
                      let nativeHash = RcheevosHash.compute(filePath: romPath),
                      nativeHash != fileMD5 else {
                    ILOG("RetroAchievements: no distinct rcheevos hash available, achievements unavailable.")
                    await MainActor.run {
                        PVToastManager.shared.show(
                            "RetroAchievements: no match found for \(gameTitle)",
                            type: .info,
                            duration: 4.0,
                            icon: "trophy"
                        )
                    }
                    return
                }
                do {
                    response = try await manager.startSession(gameHash: nativeHash)
                    winningHash = nativeHash
                    ILOG("RetroAchievements: matched rcheevos native hash \(nativeHash)")
                } catch AchievementSessionError.unknownGame {
                    ILOG("RetroAchievements: native hash \(nativeHash) also not in database, achievements unavailable.")
                    await MainActor.run {
                        PVToastManager.shared.show(
                            "RetroAchievements: no match found for \(gameTitle)",
                            type: .info,
                            duration: 4.0,
                            icon: "trophy"
                        )
                    }
                    return
                } catch {
                    ELOG("RetroAchievements: session start failed (native hash): \(error.localizedDescription)")
                    await MainActor.run {
                        PVToastManager.shared.show(
                            "RetroAchievements unavailable: \(error.localizedDescription)",
                            type: .error,
                            duration: 4.0,
                            icon: "exclamationmark.triangle"
                        )
                    }
                    return
                }
            } catch {
                ELOG("RetroAchievements: session start failed: \(error.localizedDescription)")
                await MainActor.run {
                    PVToastManager.shared.show(
                        "RetroAchievements unavailable: \(error.localizedDescription)",
                        type: .error,
                        duration: 4.0,
                        icon: "exclamationmark.triangle"
                    )
                }
                return
            }

            ILOG("RetroAchievements: session started for game \(manager.currentGameId ?? -1) using hash \(winningHash), \(response.unlocks?.count ?? 0) existing unlocks.")
            // [CHEEVOS-DIAG] Mirror the success line under our diagnostic prefix so the tester
            // can grep [CHEEVOS-DIAG] alone and still see the winning hash + game id + unlocks.
            ILOG("[CHEEVOS-DIAG] startSession SUCCESS gameId=\(manager.currentGameId ?? -1) winningHash=\(winningHash) existingUnlocks=\(response.unlocks?.count ?? 0)")

            // Post a status toast so the user sees the same "found match" feedback
            // the RA full-wrapper publishes via its native message system.
            //
            // response.unlocks is the user's prior unlocks for this game on this
            // account (per the RA dorequest StartSession API). Surface the count
            // but phrase it as "already earned" so users don't read it as
            // "achievements available". When the count is 0, omit it entirely —
            // an unadorned "tracking" message is cleaner.
            //
            // NOTE: if you see a non-zero count on a game you've never played,
            // the RA server may be returning a softcore / leaderboard placeholder
            // that's tied to your account but not a real achievement unlock.
            let priorUnlocks = response.unlocks?.count ?? 0
            await MainActor.run {
                let message: String
                if priorUnlocks > 0 {
                    message = "RetroAchievements: tracking \(gameTitle) (\(priorUnlocks) already earned)"
                } else {
                    message = "RetroAchievements: tracking \(gameTitle)"
                }
                PVToastManager.shared.show(
                    message,
                    type: .success,
                    duration: 4.0,
                    icon: "trophy.fill"
                )
            }

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
            await achievementsCore.prepareAchievements(gameHash: winningHash)
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

        // Reset session points counter.
        achievementSessionPoints = 0

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
        // Hardcore mode blocks BOTH fast-forward and slow-motion (any non-normal
        // speed is an unfair advantage). The predicate is "hardcore + active".
        if achievementsBlocksFastForward() {
            if speed == .fast || speed == .veryFast {
                ILOG("Ignoring request to set fast game speed while RetroAchievements hardcore mode is active.")
                #if canImport(UIKit)
                presentError(hardcoreFastForwardBlockedMessage, source: view)
                #endif
                return
            }
            if speed == .slow {
                ILOG("Ignoring request to set slow game speed while RetroAchievements hardcore mode is active.")
                #if canImport(UIKit)
                presentError(hardcoreSlowMotionBlockedMessage, source: view)
                #endif
                return
            }
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

    /// Running total of achievement points unlocked in this session.
    /// Reset to 0 in `stopAchievements()`.
    internal var achievementSessionPoints: Int {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.sessionPoints) as? NSNumber)?.intValue ?? 0 }
        set { objc_setAssociatedObject(self, &AssociatedKeys.sessionPoints, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    public func achievementUnlocked(_ notification: AchievementUnlockNotification) {
        // [CHEEVOS-DIAG] OSD-delegate side received an unlock. If you see the
        // RcheevosBridge "onAchievementUnlocked" line but never this one, the
        // adapter.delegate is nil at delivery time.
        ILOG("[CHEEVOS-DIAG] PVEmulatorVC achievementUnlocked id=\(notification.id) title=\(notification.title) points=\(notification.points) hardcore=\(notification.isHardcore)")
        // Snapshot settings once — checked on the calling thread (may be emu).
        let showToast = Defaults[.retroAchievementsToastsEnabled]
        let playSound = Defaults[.retroAchievementsSoundEnabled]

        if showToast {
            Task { @MainActor [weak self] in
                self?.achievementOverlayViewController?.showUnlock(notification)
            }
        }
        if playSound {
            AchievementSoundPlayer.playUnlock()
        }

        // Accumulate session points and forward to Live Activity.
        achievementSessionPoints += Int(notification.points)
        let cumulativePoints = achievementSessionPoints
        Task { @MainActor [weak self] in
            // total = 0 means "unknown" — the progress bar is hidden in that case.
            self?.updateLiveActivityAchievements(points: cumulativePoints, total: 0)
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
        guard Defaults[.retroAchievementsToastsEnabled] else { return }
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
