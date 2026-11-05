//
//  EmulatorSessionFeature.swift
//  PVUI
//
//  One optional capability of a running emulator session, attached to the host
//  through `EmulatorFeatureRegistry`. See
//  docs/superpowers/specs/2026-11-03-emulator-host-thinning-design.md, section 4.2.
//

import Foundation

/// Stable identifier of a session feature; also the prefix of every `PauseMenuTile`
/// the feature contributes.
public struct EmulatorFeatureID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

/// Why the host paused the core. Features only observe pauses; the host is the
/// single authority that calls `core.setPauseEmulation`.
public enum EmulatorPauseReason: Sendable, Hashable {
    /// The pause menu is up.
    case menu
    /// The app went to the background.
    case background
    /// The app resigned active (incoming call, Control Center, app switcher).
    case resignActive
    /// A user-initiated pause that is not the pause menu (quick action, keyboard).
    case user
}

// The pause menu's vocabulary is `PauseMenuTile`, not a layout frame.
// swiftlint:disable tiles_deprecated
/// Pause-menu tiles a feature adds to one of the view model's named sections.
public struct PauseMenuTileContribution: Equatable, Sendable {
    /// One of the section ids `PauseTileMenuViewModel` lays out
    /// ("game", "statesData", "settingsData", "controlsData", "quickSettingsData", "menu", "displayData", "core").
    public let sectionID: String
    public let tiles: [PauseMenuTile]

    public init(sectionID: String, tiles: [PauseMenuTile]) {
        self.sectionID = sectionID
        self.tiles = tiles
    }
}
// swiftlint:enable tiles_deprecated

/// One optional capability of a running emulator session (achievements, cheats, saves, …).
///
/// Created by `EmulatorFeatureRegistry` from the host's `init`; torn down in `detach()`.
/// All members are main-actor. A feature keeps its own state as stored properties, never in
/// associated objects, never keeps a strong reference to the host, and never cleans up in
/// `deinit`: every teardown runs from `detach()` or `hostWillDisappear(leaving: true)`,
/// which the host calls from main-actor code.
@MainActor
public protocol EmulatorSessionFeature: AnyObject {
    /// Stable id, also the prefix of every `PauseMenuTile` the feature contributes.
    static var id: EmulatorFeatureID { get }

    /// `nil` when the feature does not apply to this core / platform / settings.
    /// The registry skips it.
    init?(host: any EmulatorSessionHost)

    /// After `viewDidLoad`. Install views and observers.
    func attach()
    /// From `finishEmulatorStart`: the core has loaded the ROM and reports real geometry / sample rate.
    func coreDidStart()
    /// `viewDidAppear`.
    func hostDidAppear()
    /// `viewWillDisappear`. `leaving` is `isMovingFromParent || isBeingDismissed`.
    func hostWillDisappear(leaving: Bool)
    /// `viewDidLayoutSubviews`, after the host has restacked its surfaces.
    func hostDidLayout()
    /// The host paused the core, with the reason.
    func sessionDidPause(_ reason: EmulatorPauseReason)
    /// The host resumed the core.
    func sessionDidResume()
    /// From `quit()`, before `core.stopEmulationAfterLoopExits()`. May await (netplay disconnect).
    func willStopCore() async
    /// From `quit()`, after the emulation loop has exited. Symmetric with `attach()`.
    func detach()

    // Pause-menu vocabulary, see `PauseMenuTileContribution`.
    // swiftlint:disable tiles_deprecated
    /// Pause-menu contribution for one route of the tile menu.
    func pauseMenuTiles(for route: PauseTileMenuRoute) -> [PauseMenuTileContribution]
    /// `true` when the feature handled the tap on one of its tiles.
    func handlePauseMenuTile(id: String) -> Bool
    /// `true` when the feature handled a long-press option on one of its tiles.
    func handlePauseMenuLongPress(tileID: String, option: PauseMenuTileLongPressOption) -> Bool
    // swiftlint:enable tiles_deprecated
}

// Every hook defaults to a no-op so a feature implements only what it needs.
public extension EmulatorSessionFeature {
    func attach() {}
    func coreDidStart() {}
    func hostDidAppear() {}
    func hostWillDisappear(leaving _: Bool) {}
    func hostDidLayout() {}
    func sessionDidPause(_: EmulatorPauseReason) {}
    func sessionDidResume() {}
    func willStopCore() async {}
    func detach() {}

    func pauseMenuTiles(for _: PauseTileMenuRoute) -> [PauseMenuTileContribution] { [] }
    func handlePauseMenuTile(id _: String) -> Bool { false }
    func handlePauseMenuLongPress(tileID _: String, option _: PauseMenuTileLongPressOption) -> Bool { false }
}
