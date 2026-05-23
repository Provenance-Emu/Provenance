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
/// Swift 6 sendability shim: the Task spawned from `tickAchievements()`
/// runs on the cooperative pool; `Self: NSObject` is not Sendable, so we
/// wrap the core reference in this `@unchecked Sendable` box. The actual
/// thread-safety story is unchanged — `prepareAchievements` does its own
/// actor hops and the adapter we touch is itself `@unchecked Sendable`.
private struct _SendableCoreRef: @unchecked Sendable {
    let value: NSObject
}

private final class RcheevosBridgeAdapter: @unchecked Sendable {
    var session: RcheevosSession?
    weak var delegate: (any RetroAchievementsOSDDelegate)?
    var hardcoreMode: Bool = false
    // [CHEEVOS-DIAG] Per-frame tick counter for diagnostic logging only.
    // Intentionally not synchronised — racy reads here are fine for logging.
    var tickCount: UInt64 = 0
    var firstRegionsLogged: Bool = false

    // B.3 lazy region retry: cores that wire memory after the first frame
    // (e.g. FCEU exposing RAM[] only once FCEUI_LoadGame completes) would
    // previously lose achievements forever because rcheevosRegions() was
    // empty at prepareAchievements() time. We now remember the hash and
    // re-attempt from tickAchievements() once regions become available.
    var pendingGameHash: String?
    var retryInFlight: Bool = false
    var lastRegionRetryTick: UInt64 = 0
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
        // [CHEEVOS-DIAG] Log entry — proves prepareAchievements got called and with what hash.
        ILOG("[CHEEVOS-DIAG] prepareAchievements ENTER core=\(type(of: self)) gameHash=\(gameHash) hardcore=\(rcheevosBridgeAdapter.hardcoreMode)")

        let regions = rcheevosRegions()
        // [CHEEVOS-DIAG] Log region count immediately so we know if the core actually exposed memory.
        ILOG("[CHEEVOS-DIAG] prepareAchievements regions.count=\(regions.count) for core=\(type(of: self))")
        guard !regions.isEmpty else {
            // B.3: stash the hash so tickAchievements() can retry once regions appear.
            // Cores like FCEU expose RAM[] only after FCEUI_LoadGame finishes, which
            // can race with this call. Without the retry, achievements stay off forever.
            rcheevosBridgeAdapter.pendingGameHash = gameHash
            ILOG("RetroAchievements: core returned no regions yet — will retry per-frame until regions appear.")
            ILOG("[CHEEVOS-DIAG] prepareAchievements DEFERRED (no regions, retry armed) core=\(type(of: self)) hash=\(gameHash)")
            return
        }
        // Regions present — clear any pending retry from a prior call.
        rcheevosBridgeAdapter.pendingGameHash = nil

        let adapter = rcheevosBridgeAdapter
        adapter.session?.unload()
        guard let session = RcheevosSession() else {
            ELOG("RetroAchievements: failed to create RcheevosSession.")
            ILOG("[CHEEVOS-DIAG] prepareAchievements EXIT (session create failed) core=\(type(of: self))")
            return
        }
        session.setRegions(regions)
        session.setHardcoreEnabled(adapter.hardcoreMode)
        wireEventClosures(session: session, adapter: adapter)
        // [CHEEVOS-DIAG] Confirm closures installed and which delegate is currently routed.
        ILOG("[CHEEVOS-DIAG] event closures installed, delegate=\(adapter.delegate.map { String(describing: $0) } ?? "nil")")
        adapter.session = session
        // Reset diagnostic counters for the new session.
        adapter.tickCount = 0
        adapter.firstRegionsLogged = false

        do {
            // [CHEEVOS-DIAG] About to start loginAndLoad — the slow async step.
            ILOG("[CHEEVOS-DIAG] loginAndLoad START gameHash=\(gameHash)")
            try await session.loginAndLoad(gameHash: gameHash)
            // [CHEEVOS-DIAG] loginAndLoad returned without throwing.
            ILOG("[CHEEVOS-DIAG] loginAndLoad SUCCESS gameHash=\(gameHash) session.isLoaded=\(session.isLoaded)")
            ILOG("RetroAchievements: rc_client loaded game \(gameHash).")
        } catch {
            // [CHEEVOS-DIAG] loginAndLoad threw — log the type so we can see no-creds vs unknown-game vs network.
            ILOG("[CHEEVOS-DIAG] loginAndLoad FAIL gameHash=\(gameHash) error=\(error) localized=\(error.localizedDescription)")
            WLOG("RetroAchievements: \(error.localizedDescription)")
        }

        // [CHEEVOS-DIAG] One-shot post-load summary.
        ILOG("[CHEEVOS-DIAG] prepareAchievements EXIT core=\(type(of: self)) achievementsActive=\(achievementsActive) hardcore=\(adapter.hardcoreMode)")
    }

    func stopAchievements() {
        let adapter = rcheevosBridgeAdapter
        adapter.session?.unload()
        adapter.session = nil
        // B.3: clear any pending retry so a stopped game doesn't auto-resume.
        adapter.pendingGameHash = nil
        adapter.retryInFlight = false
    }

    func tickAchievements() {
        // doFrame() runs on the emulator thread; rcheevos is built with
        // `RC_NO_THREADS=1`, so single-emulator-thread cores satisfy the
        // synchronisation invariant without further locking.
        let adapter = rcheevosBridgeAdapter
        adapter.session?.doFrame()
        // [CHEEVOS-DIAG] Heartbeat: log every 600 frames (~10 s at 60 fps) so the
        // tester can see the per-frame tick is alive and rc_client is being driven.
        adapter.tickCount &+= 1
        if adapter.tickCount % 600 == 0 {
            let isLoaded = adapter.session?.isLoaded ?? false
            ILOG("[CHEEVOS-DIAG] tickAchievements heartbeat core=\(type(of: self)) ticks=\(adapter.tickCount) achievementsActive=\(achievementsActive) session.isLoaded=\(isLoaded) hardcore=\(adapter.hardcoreMode) delegate=\(adapter.delegate != nil ? "set" : "nil")")
        }

        // B.3: lazy-retry prepareAchievements when regions weren't ready yet.
        // Only enter the slow path when (a) a hash is pending, (b) no session
        // is live, (c) we aren't already retrying, and (d) at least 60 frames
        // have passed since the last poll (≈1 s at 60 fps — bounded cost even
        // when the core never exposes memory).
        if adapter.pendingGameHash != nil,
           adapter.session == nil,
           !adapter.retryInFlight,
           adapter.tickCount &- adapter.lastRegionRetryTick >= 60 {
            adapter.lastRegionRetryTick = adapter.tickCount
            let regions = rcheevosRegions()
            if !regions.isEmpty {
                guard let hash = adapter.pendingGameHash else { return }
                adapter.retryInFlight = true
                ILOG("[CHEEVOS-DIAG] tickAchievements regions now available — retrying prepareAchievements core=\(type(of: self)) hash=\(hash) regions=\(regions.count)")
                let coreRef = _SendableCoreRef(value: self)
                Task {
                    if let core = coreRef.value as? (any CoreRetroAchievements) {
                        await core.prepareAchievements(gameHash: hash)
                    }
                    coreRef.value.rcheevosBridgeAdapter.retryInFlight = false
                }
            }
        }
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
        // [CHEEVOS-DIAG] rc_client fired an unlock — log BEFORE we hop to MainActor
        // so we can confirm the C side actually evaluated the trigger even if the
        // delegate has already been torn down by the time we reach main.
        ILOG("[CHEEVOS-DIAG] onAchievementUnlocked id=\(event.achievementID) title=\(event.title) points=\(event.points) hardcore=\(event.isHardcore)")
        Task { @MainActor in
            // [CHEEVOS-DIAG] Capture delegate state at delivery time.
            let hasDelegate = adapter.delegate != nil
            ILOG("[CHEEVOS-DIAG] onAchievementUnlocked dispatch -> delegate=\(hasDelegate ? "set" : "nil") id=\(event.achievementID)")
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
