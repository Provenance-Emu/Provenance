//
//  PVEmulatorViewController+LiveActivities.swift
//  PVUIBase
//
//  Wires the ActivityKit Live Activity lifecycle into PVEmulatorViewController.
//
//  Call sites (all in PVEmulatorViewController.swift / *+Saves.swift / *+Achievements.swift):
//
//    • `startLiveActivityIfNeeded()`  — called after core.startEmulation()
//    • `endLiveActivity()`            — called before core.stopEmulation() teardown
//    • `setLiveActivityPaused(_:)`    — called by pause-menu toggle
//    • `recordLiveActivityAutosave()` — called after a successful autosave
//    • `updateLiveActivityAchievements(points:total:)` — forwarded from RA delegate
//
//  All entry points are no-ops on tvOS/macOS because `PVLiveActivities` compiles
//  its public API as stubs on non-iOS platforms.
//

#if canImport(PVLiveActivities)
import PVLiveActivities
#endif
import PVLibrary

public extension PVEmulatorViewController {

    // MARK: - Lifecycle

    /// Start a Live Activity for the current game session.
    ///
    /// Resolves the box-art path relative to the App Group container so the
    /// widget extension can render it without a network fetch.
    func startLiveActivityIfNeeded() {
#if os(iOS) && canImport(PVLiveActivities)
        let gameTitle = game?.title ?? ""
        let systemName = game?.systemShortName ?? game?.systemIdentifier ?? ""
        let md5 = game?.md5Hash ?? ""
        let artworkPath = resolvedArtworkPath()

        Task { @MainActor in
            await LiveActivityManager.shared.startActivity(
                gameTitle: gameTitle,
                systemName: systemName,
                gameMD5: md5,
                artworkPath: artworkPath
            )
        }
#endif
    }

    /// End the Live Activity, removing it from the Dynamic Island and lock screen.
    func endLiveActivity() {
#if os(iOS) && canImport(PVLiveActivities)
        Task { @MainActor in
            await LiveActivityManager.shared.endActivity()
        }
#endif
    }

    // MARK: - State updates

    /// Reflect pause/resume state in the Live Activity.
    func setLiveActivityPaused(_ paused: Bool) {
#if os(iOS) && canImport(PVLiveActivities)
        Task { @MainActor in
            await LiveActivityManager.shared.setPaused(paused)
        }
#endif
    }

    /// Record that an autosave completed so the lock-screen widget can show
    /// "saved Xm ago".
    func recordLiveActivityAutosave() {
#if os(iOS) && canImport(PVLiveActivities)
        Task { @MainActor in
            await LiveActivityManager.shared.recordAutosave()
        }
#endif
    }

    /// Forward RetroAchievements progress to the Live Activity.
    ///
    /// - Parameters:
    ///   - points: Unlocked points for the current game (cumulative session total).
    ///   - total: Maximum points available for this game.
    func updateLiveActivityAchievements(points: Int, total: Int) {
#if os(iOS) && canImport(PVLiveActivities)
        Task { @MainActor in
            await LiveActivityManager.shared.updateAchievements(points: points, total: total)
        }
#endif
    }

    // MARK: - Private helpers

    /// Returns the relative path (within the App Group container) for the current
    /// game's box art, or `nil` when artwork is unavailable.
    private func resolvedArtworkPath() -> String? {
        guard let game else { return nil }
        let artworkURLString = game.customArtworkURL.isEmpty ? game.artworkURL : game.customArtworkURL
        guard !artworkURLString.isEmpty else { return nil }
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: pvUIAppGroupID
        ) else { return nil }

        // If the URL is already a file URL inside the App Group container, compute relative path.
        let containerPath = containerURL.path
        if artworkURLString.hasPrefix(containerPath) {
            return String(artworkURLString.dropFirst(containerPath.count + 1))
        }
        // If it's a bare filename or relative path, return as-is and let the widget resolve it.
        return artworkURLString
    }
}

// MARK: - App Group ID (PVUI-local)

/// Resolves the App Group identifier from the build setting embedded in Info.plist.
/// Must stay in sync with `PVAppIntents/AppGroupID.swift`.
private var pvUIAppGroupID: String {
    let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
    guard let raw, !raw.isEmpty, !raw.contains("$(") else {
        return "group.org.provenance-emu.provenance"
    }
    return raw
}
