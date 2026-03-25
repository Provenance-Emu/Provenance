//
//  PVGBEmulatorCore+RetroAchievements.swift
//  PVGambatte
//
//  Conformance of PVGBEmulatorCore (Gambatte GB/GBC core) to CoreRetroAchievements.
//
//  ## Integration status
//
//  The rc_client C API integration is compiled behind HAVE_RCHEEVOS in the ObjC
//  bridge (PVGambatteBridge.mm). This Swift layer:
//    - Calls through to the bridge for session lifecycle and per-frame ticking.
//    - Returns actual GB/GBC WRAM and VRAM memory regions from the live
//      Gambatte memory allocations (backed by wramBasePtr / vramBasePtr on the bridge).
//    - Forwards rc_client event callbacks (via the AchievementsEvents ObjC category
//      that routes back through achievementsEventOwner) to RetroAchievementsOSDDelegate.
//
//  ## Activating full rcheevos integration
//
//  1. Add a `librcheevos` SPM target (or depend on PVRcheevos package) in Package.swift.
//  2. In the PVGambatteBridge cSettings add `.define("HAVE_RCHEEVOS", to: "1")`.
//  3. Implement `pvgb_server_call` in PVGambatteBridge.mm to forward HTTP requests
//     to PVCheevos.RetroNetworkClient (see the stub in that file).
//  4. Log in before calling prepareAchievements: use PVCheevos.AchievementSessionManager
//     to obtain username/token, then call rc_client_begin_login_with_token via the bridge.
//
//  ## Memory layout (GB/GBC)
//
//  Region   | GB bus address | Size (DMG) | Size (GBC)
//  ---------|----------------|------------|----------
//  VRAM     | 0x8000–0x9FFF  | 8 KiB      | 16 KiB (bank-switched)
//  WRAM     | 0xC000–0xDFFF  | 8 KiB      | 32 KiB (banks 1–7 switchable)
//
//  achievementMemoryRegions() exposes these two regions using live pointers from
//  the vendored libgambatte wramData() / vramData() accessors.
//

import Foundation
import PVCoreBridge

extension PVGBEmulatorCore: CoreRetroAchievements {

    // MARK: - Delegate

    public var achievementsDelegate: (any RetroAchievementsOSDDelegate)? {
        get { _achievementsDelegate }
        set { _achievementsDelegate = newValue }
    }

    // MARK: - Session lifecycle

    public func prepareAchievements(gameHash: String) async {
        await withCheckedContinuation { continuation in
            _bridge.loadAchievementsForGameHash(gameHash) { _ in
                continuation.resume()
            }
        }
    }

    public func stopAchievements() {
        _bridge.unloadAchievements()
    }

    // MARK: - Per-frame tick

    // tickAchievements is implicitly called each frame: PVGambatteBridge's
    // executeFrameSkippingFrame: calls -[PVGBEmulatorCoreBridge tickAchievements],
    // which calls rc_client_do_frame() when HAVE_RCHEEVOS is set.
    // The default no-op from CoreRetroAchievements is therefore sufficient here.

    // MARK: - Memory regions

    public func achievementMemoryRegions() -> [AchievementMemoryRegion] {
        guard let wramPtr = _bridge.wramBasePtr else { return [] }
        let wramSize = Int(_bridge.wramSize)

        var regions: [AchievementMemoryRegion] = [
            AchievementMemoryRegion(
                base: wramPtr,
                size: wramSize,
                kind: .systemRAM
            )
        ]

        // vramBasePtr points to the start of the VRAM data allocation.
        // Gambatte's vramData() returns rambankdata_ - 0x4000, which is the
        // physical base of VRAM (index 0 = GB address 0x8000).
        // 8 KiB for DMG; 16 KiB for GBC (two 8-KiB banks).
        if let vramBase = _bridge.vramBasePtr {
            let vramSize = _bridge.isGameboyColor ? 0x4000 : 0x2000
            regions.append(
                AchievementMemoryRegion(
                    base: vramBase,
                    size: vramSize,
                    kind: .videoRAM
                )
            )
        }

        return regions
    }

    // MARK: - State

    public var achievementsActive: Bool {
        return _bridge.achievementsActive
    }

    public var hardcoreMode: Bool {
        get { _hardcoreMode }
        set { _hardcoreMode = newValue }
    }
}

// MARK: - AchievementsEvents Swift overrides

// The ObjC PVGambatteBridge (AchievementsEvents) category declares these
// selectors for pvgb_event_handler to call, but their implementations are
// provided here in Swift on PVGBEmulatorCoreBridge.
// When pvgb_event_handler calls the method on the bridge instance, we route
// the event through achievementsEventOwner → PVGBEmulatorCore → _achievementsDelegate.

extension PVGBEmulatorCoreBridge {

    private var _ownerCore: PVGBEmulatorCore? {
        return achievementsEventOwner as? PVGBEmulatorCore
    }

    @objc
    public func rcAchievementTriggeredWithID(
        _ achievementID: UInt32,
        title: String?,
        description: String?,
        points: UInt32,
        badgeURL: URL?,
        isHardcore: Bool
    ) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        let notification = AchievementUnlockNotification(
            id: achievementID,
            title: title ?? "",
            description: description ?? "",
            points: points,
            badgeURL: badgeURL,
            isHardcore: isHardcore
        )
        DispatchQueue.main.async { delegate.achievementUnlocked(notification) }
    }

    @objc
    public func rcAchievementProgressWithID(
        _ achievementID: UInt32,
        title: String?,
        progressText: String?
    ) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        let notification = AchievementProgressNotification(
            achievementID: achievementID,
            title: title ?? "",
            progressText: progressText ?? ""
        )
        DispatchQueue.main.async { delegate.achievementProgress(notification) }
    }

    @objc
    public func rcLeaderboardStartedWithID(
        _ leaderboardID: UInt32,
        title: String?,
        description: String?,
        scoreText: String?
    ) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        let notification = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title ?? "",
            description: description ?? "",
            scoreText: scoreText ?? ""
        )
        DispatchQueue.main.async { delegate.leaderboardStarted(notification) }
    }

    @objc
    public func rcLeaderboardFailedWithID(_ leaderboardID: UInt32) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        DispatchQueue.main.async { delegate.leaderboardFailed(leaderboardID: leaderboardID) }
    }

    @objc
    public func rcLeaderboardSubmittedWithID(
        _ leaderboardID: UInt32,
        title: String?,
        description: String?,
        scoreText: String?
    ) {
        guard let delegate = _ownerCore?._achievementsDelegate else { return }
        let notification = AchievementLeaderboardNotification(
            leaderboardID: leaderboardID,
            title: title ?? "",
            description: description ?? "",
            scoreText: scoreText ?? ""
        )
        DispatchQueue.main.async { delegate.leaderboardSubmitted(notification) }
    }
}
