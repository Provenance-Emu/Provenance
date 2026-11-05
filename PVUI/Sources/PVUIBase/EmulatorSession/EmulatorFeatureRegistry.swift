//
//  EmulatorFeatureRegistry.swift
//  PVUI
//
//  The host's ordered list of session features, and the one place that knows
//  the hook order: every hook fans out in registration order, `detach()` in
//  reverse. See the emulator host thinning design, section 4.2.
//

import Foundation

@MainActor
public final class EmulatorFeatureRegistry {
    /// Features in registration order.
    public private(set) var features: [any EmulatorSessionFeature]

    public init(features: [any EmulatorSessionFeature] = []) {
        self.features = features
    }

    /// Instantiates every type of `catalog` against `host`, in order, skipping the
    /// ones whose `init?(host:)` returns `nil`.
    public convenience init(host: any EmulatorSessionHost, catalog: [any EmulatorSessionFeature.Type]) {
        self.init()
        register(catalog, host: host)
    }

    /// Appends the features of `catalog` that apply to `host`. Call before `attach()`.
    public func register(_ catalog: [any EmulatorSessionFeature.Type], host: any EmulatorSessionHost) {
        for type in catalog {
            if let feature = type.init(host: host) {
                features.append(feature)
            }
        }
    }

    /// The registered feature of `type`, if it applied to this session.
    public func feature<T: EmulatorSessionFeature>(_ type: T.Type) -> T? {
        for feature in features {
            if let match = feature as? T {
                return match
            }
        }
        return nil
    }

    // MARK: - Lifecycle hooks (registration order)

    public func attach() {
        features.forEach { $0.attach() }
    }

    public func coreDidStart() {
        features.forEach { $0.coreDidStart() }
    }

    public func hostDidAppear() {
        features.forEach { $0.hostDidAppear() }
    }

    public func hostWillDisappear(leaving: Bool) {
        features.forEach { $0.hostWillDisappear(leaving: leaving) }
    }

    public func hostDidLayout() {
        features.forEach { $0.hostDidLayout() }
    }

    public func sessionDidPause(_ reason: EmulatorPauseReason) {
        features.forEach { $0.sessionDidPause(reason) }
    }

    public func sessionDidResume() {
        features.forEach { $0.sessionDidResume() }
    }

    /// Awaits each feature in turn, so a feature that must finish before the core
    /// stops (netplay disconnect) has done so when this returns.
    public func willStopCore() async {
        for feature in features {
            await feature.willStopCore()
        }
    }

    /// Reverse registration order: a feature is torn down before anything it was
    /// built on top of.
    public func detach() {
        features.reversed().forEach { $0.detach() }
    }

    // MARK: - Pause menu

    // Pause-menu vocabulary, see `PauseMenuTileContribution`.
    // swiftlint:disable tiles_deprecated
    /// Every feature's tiles for `route`, in registration order.
    public func pauseMenuTiles(for route: PauseTileMenuRoute) -> [PauseMenuTileContribution] {
        features.flatMap { $0.pauseMenuTiles(for: route) }
    }

    /// `true` when the first feature claiming `id` handled the tap.
    public func handlePauseMenuTile(id: String) -> Bool {
        features.contains { $0.handlePauseMenuTile(id: id) }
    }

    /// `true` when the first feature claiming `tileID` handled the long-press option.
    public func handlePauseMenuLongPress(tileID: String, option: PauseMenuTileLongPressOption) -> Bool {
        features.contains { $0.handlePauseMenuLongPress(tileID: tileID, option: option) }
    }
    // swiftlint:enable tiles_deprecated
}
