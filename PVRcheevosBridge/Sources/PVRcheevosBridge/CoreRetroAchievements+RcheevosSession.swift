//
//  CoreRetroAchievements+RcheevosSession.swift
//  PVRcheevosBridge
//
//  Default `CoreRetroAchievements` implementation that drives a single
//  `RcheevosSession` per core and adapts its closure events to the
//  `RetroAchievementsOSDDelegate` the rest of the app already speaks.
//
//  ## Cores that opt in only need this:
//
//      class FooCoreBridge: PVEmulatorCore, CoreRetroAchievements {
//          func rcheevosRegions() -> [RcheevosRegion] {
//              [RcheevosRegion(rcAddress: ..., base: ..., size: ..., byteSwapMode: .off)]
//          }
//      }
//
//  Everything else — login, load-game, per-frame tick, hardcore flag,
//  unload, and the delegate plumbing — comes from this extension. State
//  (the live `RcheevosSession`, the delegate, the hardcore flag) is held
//  in an Objective-C associated object keyed off the core instance, so
//  conforming types do not need to add any stored properties.
//
//  Cores with non-standard memory layouts that need to construct regions
//  *after* loading (e.g. once the core has mapped its WRAM block) should
//  return their list from `rcheevosRegions()` whenever called — the
//  default `prepareAchievements(gameHash:)` invokes it just before
//  `loginAndLoad`.
//

import Foundation
import ObjectiveC.runtime
import PVCoreBridge
import PVLogging
import PVRcheevos

// MARK: - Region requirement

public extension CoreRetroAchievements where Self: NSObject {
    /// Override this to expose your core's memory map to rcheevos. Default
    /// returns an empty list, which leaves achievements off for that core.
    func rcheevosRegions() -> [RcheevosRegion] { [] }
}

// MARK: - Adapter (private state)

/// Per-core state held via Objective-C associated object so the protocol
/// extension doesn't need stored properties. Threading invariants match
/// `MednafenRcheevosClient` (the pre-existing reference implementation):
/// - `session.doFrame()` runs on the emulator thread
/// - lifecycle / delegate access happens on main
/// - `RC_NO_THREADS=1` means rcheevos itself does not need locking
/// so a plain `@unchecked Sendable` class is sufficient.
private final class RcheevosBridgeAdapter: @unchecked Sendable {
    var session: RcheevosSession?
    weak var delegate: (any RetroAchievementsOSDDelegate)?
    var hardcoreMode: Bool = false
}

private nonisolated(unsafe) var adapterKey: UInt8 = 0

private extension NSObject {
    var rcheevosBridgeAdapter: RcheevosBridgeAdapter {
        if let existing = objc_getAssociatedObject(self, &adapterKey) as? RcheevosBridgeAdapter {
            return existing
        }
        let adapter = RcheevosBridgeAdapter()
        objc_setAssociatedObject(self, &adapterKey, adapter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return adapter
    }
}

// MARK: - Default CoreRetroAchievements implementation

public extension CoreRetroAchievements where Self: NSObject {

    // MARK: Delegate

    var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { rcheevosBridgeAdapter.delegate }
        set { rcheevosBridgeAdapter.delegate = newValue }
    }

    // MARK: Lifecycle

    func prepareAchievements(gameHash: String) async {
        let regions = rcheevosRegions()
        guard !regions.isEmpty else {
            ILOG("RetroAchievements: core returned no regions, achievements off.")
            return
        }

        let adapter = rcheevosBridgeAdapter
        adapter.session?.unload()
        guard let session = RcheevosSession() else {
            ELOG("RetroAchievements: failed to create RcheevosSession.")
            return
        }
        session.setRegions(regions)
        session.setHardcoreEnabled(adapter.hardcoreMode)
        wireEventClosures(session: session, adapter: adapter)
        adapter.session = session

        do {
            try await session.loginAndLoad(gameHash: gameHash)
            ILOG("RetroAchievements: rc_client loaded game \(gameHash).")
        } catch {
            WLOG("RetroAchievements: \(error.localizedDescription)")
        }
    }

    func stopAchievements() {
        let adapter = rcheevosBridgeAdapter
        adapter.session?.unload()
        adapter.session = nil
    }

    func tickAchievements() {
        // doFrame() runs on the emulator thread; rcheevos is built with
        // `RC_NO_THREADS=1`, so single-emulator-thread cores satisfy the
        // synchronisation invariant without further locking.
        rcheevosBridgeAdapter.session?.doFrame()
    }

    // MARK: State

    var achievementsActive: Bool {
        rcheevosBridgeAdapter.session?.isLoaded ?? false
    }

    var hardcoreMode: Bool {
        get { rcheevosBridgeAdapter.hardcoreMode }
        set {
            let adapter = rcheevosBridgeAdapter
            adapter.hardcoreMode = newValue
            adapter.session?.setHardcoreEnabled(newValue)
        }
    }
}

// MARK: - Closure → Delegate adapter

private func wireEventClosures(
    session: RcheevosSession,
    adapter: RcheevosBridgeAdapter
) {
    session.onAchievementUnlocked = { event in
        Task { @MainActor in
            adapter.delegate?.achievementUnlocked(
                AchievementUnlockNotification(
                    id: event.achievementID,
                    title: event.title,
                    description: event.description,
                    points: event.points,
                    badgeURL: badgeURL(badgeName: event.badgeName, locked: false),
                    isHardcore: event.isHardcore
                )
            )
        }
    }

    session.onAchievementProgress = { event in
        Task { @MainActor in
            adapter.delegate?.achievementProgress(
                AchievementProgressNotification(
                    achievementID: event.achievementID,
                    title: event.title,
                    progressText: event.progressText
                )
            )
        }
    }

    session.onChallengeShow = { event in
        Task { @MainActor in
            adapter.delegate?.showChallengeIndicator(
                AchievementChallengeNotification(
                    achievementID: event.achievementID,
                    badgeURL: badgeURL(badgeName: event.badgeName, locked: true)
                )
            )
        }
    }

    session.onChallengeHide = { id in
        Task { @MainActor in
            adapter.delegate?.hideChallengeIndicator(achievementID: id)
        }
    }

    session.onLeaderboardStarted = { event in
        Task { @MainActor in
            adapter.delegate?.leaderboardStarted(event.toNotification())
        }
    }

    session.onLeaderboardFailed = { id in
        Task { @MainActor in
            adapter.delegate?.leaderboardFailed(leaderboardID: id)
        }
    }

    session.onLeaderboardSubmitted = { event in
        Task { @MainActor in
            adapter.delegate?.leaderboardSubmitted(event.toNotification())
        }
    }
}

private func badgeURL(badgeName: String, locked: Bool) -> URL? {
    guard !badgeName.isEmpty else { return nil }
    let suffix = locked ? "_lock" : ""
    return URL(string: "https://media.retroachievements.org/Badge/\(badgeName)\(suffix).png")
}

private extension RcheevosLeaderboardEvent {
    func toNotification() -> AchievementLeaderboardNotification {
        AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title,
            description: description,
            scoreText: scoreText
        )
    }
}
