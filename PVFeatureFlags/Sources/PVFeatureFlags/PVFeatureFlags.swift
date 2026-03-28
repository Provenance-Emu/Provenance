//
//  PVFeatureFlags.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/6/25.
//  Copyright 2025 Joseph Mattiello. All rights reserved.
//

import Foundation
#if canImport(os)
import os
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Combine)
import Combine
#endif

/// Enum representing all available feature flags
public enum PVFeature: String, CaseIterable, Sendable {
    case inAppFreeROMs = "inAppFreeROMs"
    case romPathMigrator = "romPathMigrator"
    case cheatsUseSwiftUI = "cheatsUseSwiftUI"
    case cheatsOnlineLookup = "cheatsOnlineLookup"
    case retroarchBuiltinEditor = "retroarchBuiltinEditor"
    case advancedSkinFeatures = "advancedSkinFeatures"
    case contentlessCores = "contentlessCores"
    /// Enables runtime scanning of Frameworks/ for bare libretro dylibs/frameworks
    /// and registers them through the thin PVThinLibretroFrontend. Disabled by default;
    /// enable via the PVFeatureFlags debug-override UI (accessible on all build types;
    /// hidden behind a cheat code on App Store builds).
    case dynamicLibretroScanner = "dynamicLibretroScanner"
    /// Enables the experimental tile/grid based pause menu overlay that floats over the
    /// game screen instead of the classic full-panel tab/list menu. Disabled by default.
    case pauseTileMenu = "pauseTileMenu"
    /// Enables tap-to-remap UX in the button remapping settings: instead of selecting a
    /// destination button from a list, the user presses a physical button on their controller.
    /// Disabled by default while the feature is being developed.
    case tapToRemapUI = "tapToRemapUI"
    /// Enables the Transfer Pak configuration UI for Mupen64Plus cores.
    /// The Transfer Pak lets a GB/GBC cartridge be mounted in an N64 controller port
    /// so N64 games (e.g. Pokémon Stadium) can read and write the GB save data.
    /// Disabled by default; enable in Settings > Advanced > Feature Flags.
    case mupenTransferPak = "mupenTransferPak"
    /// Enables native SwiftUI netplay lobby, room browser, and in-game HUD for
    /// RetroArch-backed cores and (in future phases) native cores like Dolphin and PPSSPP.
    /// RetroArch is compiled with HAVE_NETPLAY so sessions are technically possible
    /// via the RA menu; this flag gates the native Provenance UI on top.
    /// Disabled by default while Phase 1-3 UI stabilises.
    case netplayEnabled = "netplayEnabled"
    /// Enables the new Swift-native Hummingbird-based HTTP/WebDAV web file server
    /// in place of the vendored 2015 Objective-C GCDWebServer. When enabled, traffic
    /// is handled by `PVWebServerManager` → `PVModernWebServer`; when disabled the
    /// legacy `PVWebServer` ObjC singleton is used. Both implementations fire the same
    /// `PVWebServer*Notification` constants so the rest of the app is unaffected.
    /// Disabled by default while the new server stabilises (Epic #2758, Task A #2760).
    case modernWebServer = "modernWebServer"
    /// Always-on ReplayKit clip buffering: keeps a rolling recording buffer so users
    /// can save recent gameplay clips at any time. Disabled until the feature is stable.
    case clipBuffering = "clipBuffering"
    /// ReplayKit live broadcast (Go Live) button in the pause menu. Disabled until stable.
    case liveBroadcast = "liveBroadcast"
    /// Companion Controller overlay — lets the device act as a secondary controller
    /// for systems that have non-standard input peripherals (trackball, numpad, Atari 5200 stick).
    /// Disabled by default while the DSU integration is still in progress.
    case companionController = "companionController"
    /// Enables the enriched "smart" core selection UI that shows capability badges,
    /// quality rankings, and per-game recommendations when launching a game with
    /// multiple available cores. When disabled, a plain list picker is used instead.
    /// Disabled by default until core capability data is fully audited.
    case smartCoreSelection = "smartCoreSelection"
    /// Enables the light-gun crosshair overlay that renders a configurable crosshair
    /// at the cursor position during light-gun gameplay. When disabled, no crosshair
    /// is shown regardless of the `lightGunCrosshairStyle` setting.
    /// Disabled by default; enable in Settings > Advanced > Feature Flags.
    case lightGunCrosshair = "lightGunCrosshair"
    /// Enables the drag-to-reposition button layout editor for custom skins.
    /// When active, an "Edit Layout" toolbar appears over the skin view; users can drag
    /// individual buttons to new positions. Offsets are persisted per skin in UserDefaults.
    /// iOS only (tvOS lacks DragGesture). Disabled by default; enable in
    /// Settings > Advanced > Feature Flags.
    case skinButtonReposition = "skinButtonReposition"
    /// Enables multi-source artwork matching at ROM import time: queries TheGamesDB,
    /// LibretroDB, and OpenVGDB in parallel and selects the best result by artwork type priority.
    /// A background `ArtworkSearchQueue` retries games that were not matched
    /// during import. Enabled by default; disable via Settings > Advanced > Feature Flags
    /// if regressions are found.
    case enhancedArtworkSearch = "enhancedArtworkSearch"
}

/// Represents the type of app installation
public enum PVAppType: String, CaseIterable, Sendable {
    /// Standard non-App Store version
    case standard = "standard"
    /// Lite non-App Store version
    case lite = "lite"
    /// Standard App Store version
    case standardAppStore = "standard.appstore"
    /// Lite App Store version
    case liteAppStore = "lite.appstore"

    /// Determines if this is an App Store build
    public var isAppStore: Bool {
        self == .standardAppStore || self == .liteAppStore
    }

    /// Determines if this is a lite version
    public var isLite: Bool {
        self == .lite || self == .liteAppStore
    }
}

/// Represents a feature flag configuration from JSON
public struct FeatureFlag: Codable, Sendable {
    /// Whether the feature is enabled by default
    public let enabled: Bool
    /// Minimum version required for the feature (optional)
    public let minVersion: String?
    /// Minimum build number required for the feature (optional)
    public let minBuildNumber: String?
    /// List of app types where this feature is allowed
    public let allowedAppTypes: [String]?
    /// Description of the feature
    public let description: String?

    public init(
        enabled: Bool,
        minVersion: String? = nil,
        minBuildNumber: String? = nil,
        allowedAppTypes: [String]? = nil,
        description: String? = nil
    ) {
        self.enabled = enabled
        self.minVersion = minVersion
        self.minBuildNumber = minBuildNumber
        self.allowedAppTypes = allowedAppTypes
        self.description = description
    }

    public static let advancedSkinFeatures = FeatureFlag(
        enabled: false,
        description: "Enables advanced skin features like filters and debug mode"
    )

    public static let retroarchBuiltinEditor = FeatureFlag(
        enabled: false,
        minVersion: "3.0.5",
        allowedAppTypes: ["standard", "lite"],
        description: "Enables the built-in RetroArch editor. Disabled for App Store builds."
    )

    public static let contentlessCores = FeatureFlag(
        enabled: false,
        minVersion: "3.0.5",
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Enables contentless cores like DOOM, Quake, etc. Disabled for App Store builds."
    )

    public static let dynamicLibretroScanner = FeatureFlag(
        enabled: false,
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Scans Frameworks/ at startup for bare libretro dylibs/frameworks and loads them via PVThinLibretroFrontend. Disabled by default; enable via debug override UI (hidden behind cheat code on App Store builds)."
    )

    public static let pauseTileMenu = FeatureFlag(
        enabled: false,
        description: "Experimental tile/grid based pause menu overlay that floats over the game screen. Default is the classic tab/list menu."
    )

    public static let tapToRemapUI = FeatureFlag(
        enabled: false,
        description: "Tap-to-remap UX: press a physical controller button to select the remapping destination instead of choosing from a list. Disabled by default during development."
    )

    public static let mupenTransferPak = FeatureFlag(
        enabled: false,
        description: "Enables Transfer Pak configuration UI for Mupen64Plus N64 cores. Allows mounting a GB/GBC ROM into a virtual Transfer Pak for games like Pokémon Stadium. Disabled by default."
    )

    public static let netplayEnabled = FeatureFlag(
        enabled: false,
        minVersion: "3.1.0",
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Enables native SwiftUI netplay UI for RetroArch cores. LAN room discovery via Bonjour, host/join controls, and in-game HUD. Disabled by default during Phase 1-3 development."
    )

    public static let modernWebServer = FeatureFlag(
        enabled: false,
        minVersion: "3.1.0",
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Replaces the vendored 2015 ObjC GCDWebServer with a Swift-native Hummingbird HTTP/WebDAV server. Disabled by default while the new implementation stabilises (Epic #2758)."
    )

    public static let clipBuffering = FeatureFlag(
        enabled: false,
        description: "Always-on ReplayKit clip buffering. Keeps a rolling recording buffer so users can save recent gameplay clips. Disabled until stable."
    )

    public static let liveBroadcast = FeatureFlag(
        enabled: false,
        description: "ReplayKit Go Live broadcast button in the pause menu. Disabled until stable."
    )

    public static let companionController = FeatureFlag(
        enabled: false,
        description: "Companion Controller overlay — use this device as a secondary controller for systems with non-standard input peripherals (trackball, numpad, Atari 5200). Disabled until DSU integration is complete."
    )

    public static let smartCoreSelection = FeatureFlag(
        enabled: false,
        description: "Enriched core selection UI with capability badges, quality rankings, and per-game recommendations. Disabled until core capability data is fully audited."
    )

    public static let skinButtonReposition = FeatureFlag(
        enabled: false,
        description: "Drag-to-reposition button layout editor for custom skins. Shows an 'Edit Layout' toolbar over the skin; users drag buttons to reposition them. Offsets persist per skin in UserDefaults. iOS only. Disabled by default — enable in Settings > Advanced > Feature Flags."
        )
    
    public static let enhancedArtworkSearch = FeatureFlag(
        enabled: true,
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Multi-source artwork matching at import time (TheGamesDB, LibretroDB, OpenVGDB). Background ArtworkSearchQueue retries unmatched games. Enabled by default — disable in Settings > Advanced > Feature Flags if regressions are found."
    )
}

/// Root structure for feature flags JSON
public struct FeatureFlagsConfiguration: Codable, Sendable {
    /// Dictionary of feature flags keyed by feature name
    public let features: [String: FeatureFlag]

    public init(features: [String: FeatureFlag]) {
        self.features = features
    }
}

// MARK: - PVFeatureFlags

/// Thread-safe feature flag engine.
///
/// All flag reads (`isEnabled`, subscript) are **synchronous** and may be called from any
/// thread or actor — **no `await` required**. Internal state is protected by an
/// `OSAllocatedUnfairLock` (iOS/tvOS 16+), which eliminates bare lock/unlock pairs and
/// the associated early-return deadlock risk. Configuration mutations (loading from
/// network or disk) update a pre-computed cache so subsequent reads are a single
/// lock-protected dictionary lookup.
///
/// Combine subscribers receive a `stateDidChange` notification whenever the cache is
/// rebuilt (config load or debug-override change). `PVFeatureFlagsManager` uses this to
/// keep its `@Published featureStates` up to date on the main actor without polling.
///
/// Usage:
/// ```swift
/// // Synchronous — no await, no actor hop
/// if PVFeatureFlags.shared.isEnabled(.enhancedArtworkSearch) { ... }
/// if PVFeatureFlags.shared[.pauseTileMenu] { ... }
///
/// // Async configuration loading (network I/O)
/// try await PVFeatureFlags.shared.loadConfiguration(from: remoteURL)
/// ```
public final class PVFeatureFlags: @unchecked Sendable {

    // MARK: - Shared Singleton

    public static let shared = PVFeatureFlags()

    // MARK: - Immutable App Context (set once at init, never mutated)

    private let _appType: PVAppType
    private let _buildNumber: String?
    private let _appVersion: String

    // MARK: - Mutable State (lock-protected)

    private struct _State: Sendable {
        var configuration: FeatureFlagsConfiguration?
        /// Pre-computed flag states keyed by `PVFeature.rawValue`.
        /// Rebuilt whenever configuration or debug overrides change.
        var cachedStates: [String: Bool] = [:]
    }

#if canImport(os)
    /// `OSAllocatedUnfairLock` bundles all mutable state and eliminates bare
    /// lock/unlock pairs — available on iOS 16+ / tvOS 16+.
    private let _storage = OSAllocatedUnfairLock(initialState: _State())

    private func _withState<T>(_ body: (inout _State) -> T) -> T {
        _storage.withLockUnchecked(body)
    }
#else
    private let _lock = NSLock()
    private var _rawState = _State()

    private func _withState<T>(_ body: (inout _State) -> T) -> T {
        _lock.lock()
        defer { _lock.unlock() }
        return body(&_rawState)
    }
#endif

    // MARK: - Change Notifications

#if canImport(Combine)
    private let _changeSubject = PassthroughSubject<Void, Never>()

    /// Publisher that fires (on an unspecified thread) whenever any feature flag state changes.
    /// Downstream observers should use `.receive(on: DispatchQueue.main)` if they update UI.
    public var stateDidChange: AnyPublisher<Void, Never> {
        _changeSubject.eraseToAnyPublisher()
    }
#endif

    // MARK: - Init

    public init(
        appType: PVAppType? = nil,
        buildNumber: String? = nil,
        appVersion: String? = nil
    ) {
        _appType = appType ?? PVFeatureFlags.getCurrentAppType()
        _buildNumber = buildNumber ?? PVFeatureFlags.getCurrentBuildNumber()
        _appVersion = appVersion ?? PVFeatureFlags.getCurrentAppVersion()
    }

    /// Convenience initializer with a pre-loaded configuration (for testing).
    internal convenience init(
        configuration: FeatureFlagsConfiguration,
        appType: PVAppType? = nil,
        buildNumber: String? = nil,
        appVersion: String? = nil
    ) {
        self.init(appType: appType, buildNumber: buildNumber, appVersion: appVersion)
        _withState { state in
            state.configuration = configuration
            _rebuildCache(&state)
        }
    }

    // MARK: - Internal Configuration Access (tests + manager)

    /// Returns the current configuration (snapshot).
    internal var configuration: FeatureFlagsConfiguration? {
        _withState { $0.configuration }
    }

    internal func setConfiguration(_ configuration: FeatureFlagsConfiguration) {
        let changed = _withState { state -> Bool in
            state.configuration = configuration
            let before = state.cachedStates
            _rebuildCache(&state)
            return state.cachedStates != before
        }
        if changed { _notifyChange() }
    }

    // MARK: - Configuration Loading

    /// Load feature flags from a JSON URL (remote or local). The cache is rebuilt
    /// automatically on success.
    public func loadConfiguration(from url: URL) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        setConfiguration(config)
    }

    /// Load the bundled `features.json` shipped inside the SPM package.
    /// - Returns: `true` if the bundled configuration was loaded successfully.
    @discardableResult
    public func loadBundledConfiguration() -> Bool {
        guard let url = Bundle.module.url(forResource: "features", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        else { return false }
        setConfiguration(config)
        return true
    }

    // MARK: - App Metadata

    public static func getCurrentAppType() -> PVAppType {
        let str = Bundle.main.infoDictionary?["PVAppType"] as? String ?? "standard"
        return PVAppType(rawValue: str) ?? .standard
    }

    public static func getCurrentBuildNumber() -> String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    public static func getCurrentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Flag Reads (Synchronous, thread-safe, no actor hop required)

    /// Returns `true` if the feature is enabled.
    ///
    /// This is a **synchronous** call safe from any thread or Swift actor — no `await` needed.
    /// Debug overrides (stored in `UserDefaults`) take precedence over configuration values.
    public func isEnabled(_ feature: PVFeature) -> Bool {
        if let override = _debugOverride(for: feature) { return override }
        return _withState { $0.cachedStates[feature.rawValue] ?? false }
    }

    /// Returns `true` if the feature identified by `featureKey` is enabled.
    ///
    /// Known `PVFeature` raw values use the pre-computed cache. Unknown keys are evaluated
    /// live against the current configuration (useful for remotely-defined flags not in the enum).
    public func isEnabled(_ featureKey: String) -> Bool {
        if let feature = PVFeature(rawValue: featureKey) { return isEnabled(feature) }
        return _withState { state -> Bool in
            guard let featureConfig = state.configuration?.features[featureKey] else { return false }
            return _evaluate(featureConfig)
        }
    }

    /// Subscript shorthand: `PVFeatureFlags.shared[.pauseTileMenu]`
    public subscript(_ feature: PVFeature) -> Bool {
        isEnabled(feature)
    }

    // MARK: - Debug Overrides (synchronous, thread-safe via UserDefaults)

    private static let _overridesKey = "PVFeatureFlagsDebugOverrides"

    /// Set a per-feature debug override (`nil` clears the override for that feature).
    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        var dict = UserDefaults.standard.dictionary(forKey: Self._overridesKey) ?? [:]
        if let v = enabled {
            dict[feature.rawValue] = v
        } else {
            dict.removeValue(forKey: feature.rawValue)
        }
        UserDefaults.standard.set(dict, forKey: Self._overridesKey)
        _notifyChange()
    }

    /// Clear all debug overrides.
    public func clearDebugOverrides() {
        UserDefaults.standard.removeObject(forKey: Self._overridesKey)
        _notifyChange()
    }

    /// Dictionary view of current debug overrides (keyed by `PVFeature`).
    internal var debugOverrides: [PVFeature: Bool?] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: Self._overridesKey) ?? [:]
            var result: [PVFeature: Bool?] = [:]
            for (key, value) in raw {
                guard let feature = PVFeature(rawValue: key) else { continue }
                result[feature] = value as? Bool
            }
            return result
        }
        set {
            var dict: [String: Any] = [:]
            for (feature, opt) in newValue {
                if let b = opt { dict[feature.rawValue] = b }
            }
            UserDefaults.standard.set(dict, forKey: Self._overridesKey)
            _notifyChange()
        }
    }

    // MARK: - Feature Info

    /// Returns restriction reasons for a feature (empty = no restrictions).
    public func getFeatureRestrictions(_ featureKey: String) -> [String] {
        _withState { state -> [String] in
            guard let feature = state.configuration?.features[featureKey] else { return ["Feature not found"] }
            var restrictions: [String] = []
            if let allowed = feature.allowedAppTypes, !allowed.contains(_appType.rawValue) {
                restrictions.append("App type \(_appType.rawValue) not allowed")
            }
            if let minBuild = feature.minBuildNumber, let current = _buildNumber,
               Self._compareVersions(current, minBuild) < 0 {
                restrictions.append("Build \(current) below minimum \(minBuild)")
            }
            if let minVer = feature.minVersion, Self._compareVersions(_appVersion, minVer) < 0 {
                restrictions.append("Version \(_appVersion) below minimum \(minVer)")
            }
            return restrictions
        }
    }

    /// Returns all feature flags with their configuration and current enabled state.
    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        PVFeature.allCases.map { featureCase in
            let key = featureCase.rawValue
            let featureConfig = _withState { state in
                state.configuration?.features[key]
                    ?? FeatureFlag(enabled: false, description: "Feature not defined in configuration")
            }
            return (key: key, flag: featureConfig, enabled: isEnabled(featureCase))
        }
    }

    // MARK: - Debug Configuration

    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        setConfiguration(FeatureFlagsConfiguration(features: features))
    }

    // MARK: - Private Helpers

    /// Rebuilds `state.cachedStates` from `state.configuration`.
    /// Must be called inside `_withState { }`.
    private func _rebuildCache(_ state: inout _State) {
        var newStates: [String: Bool] = [:]
        for feature in PVFeature.allCases {
            guard let config = state.configuration?.features[feature.rawValue] else {
                newStates[feature.rawValue] = false
                continue
            }
            newStates[feature.rawValue] = _evaluate(config)
        }
        state.cachedStates = newStates
    }

    /// Evaluates a single `FeatureFlag` against the current (immutable) app context.
    /// Safe to call from inside or outside the lock — only reads `_appType`, `_buildNumber`,
    /// and `_appVersion`, which are set once at init and never mutated.
    private func _evaluate(_ featureConfig: FeatureFlag) -> Bool {
        if let allowedTypes = featureConfig.allowedAppTypes,
           !allowedTypes.contains(_appType.rawValue) {
            return false
        }
        if let minBuild = featureConfig.minBuildNumber,
           let currentBuild = _buildNumber,
           Self._compareVersions(currentBuild, minBuild) < 0 {
            return false
        }
        if let minVersion = featureConfig.minVersion,
           Self._compareVersions(_appVersion, minVersion) < 0 {
            return false
        }
        return featureConfig.enabled
    }

    private func _debugOverride(for feature: PVFeature) -> Bool? {
        UserDefaults.standard.dictionary(forKey: Self._overridesKey)?[feature.rawValue] as? Bool
    }

    private func _notifyChange() {
#if canImport(Combine)
        _changeSubject.send()
#endif
    }

    private static func _compareVersions(_ v1: String, _ v2: String) -> Int {
        let c1 = v1.split(separator: ".")
        let c2 = v2.split(separator: ".")
        let maxLen = max(c1.count, c2.count)
        for i in 0..<maxLen {
            let n1 = i < c1.count ? Int(c1[i]) ?? 0 : 0
            let n2 = i < c2.count ? Int(c2[i]) ?? 0 : 0
            if n1 < n2 { return -1 }
            if n1 > n2 { return 1 }
        }
        return 0
    }
}

// MARK: - PVFeatureFlagsManager

#if canImport(Combine)
/// `@MainActor`-isolated SwiftUI integration layer.
///
/// Wraps `PVFeatureFlags` and exposes a `@Published featureStates` dictionary so SwiftUI
/// views can react to flag changes. Convenience `Bool` properties are pre-computed from the
/// cached states — all reads are O(1) dictionary lookups on the main actor.
///
/// For non-UI code, prefer `PVFeatureFlags.shared.isEnabled(_:)` directly — it is
/// synchronous and does not require the main actor.
@MainActor public final class PVFeatureFlagsManager: ObservableObject, @unchecked Sendable {
    /// Shared singleton.
    public static let shared = PVFeatureFlagsManager()

    private let featureFlags: PVFeatureFlags
    private var remoteFetcher: PVFeatureFlagsFetcher?
    private var changeCancellable: AnyCancellable?

    /// Published dictionary of current feature states (rebuilt on the main actor whenever
    /// `PVFeatureFlags` reports a state change via its `stateDidChange` publisher).
    @Published public private(set) var featureStates: [PVFeature: Bool] = [:]

    private var flagObservablesCache: [PVFeature: FeatureFlagObservable] = [:]

    private init() {
        self.featureFlags = PVFeatureFlags.shared
        _bootstrap()
    }

    internal init(featureFlags: PVFeatureFlags) {
        self.featureFlags = featureFlags
        _bootstrap()
    }

    private func _bootstrap() {
        _updateFeatureStates()
        changeCancellable = featureFlags.stateDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?._updateFeatureStates() }
    }

    // MARK: - Convenience Feature Properties

    public var inAppFreeROMs: Bool { featureStates[.inAppFreeROMs] ?? false }
    public var romPathMigrator: Bool { featureStates[.romPathMigrator] ?? false }
    public var cheatsUseSwiftUI: Bool { featureStates[.cheatsUseSwiftUI] ?? false }
    public var retroarchBuiltinEditor: Bool { featureStates[.retroarchBuiltinEditor] ?? false }
    public var advancedSkinFeatures: Bool { featureStates[.advancedSkinFeatures] ?? false }
    public var contentlessCores: Bool { featureStates[.contentlessCores] ?? false }
    public var cheatsOnlineLookup: Bool { featureStates[.cheatsOnlineLookup] ?? false }
    public var dynamicLibretroScanner: Bool { featureStates[.dynamicLibretroScanner] ?? false }
    public var pauseTileMenu: Bool { featureStates[.pauseTileMenu] ?? false }
    public var tapToRemapUI: Bool { featureStates[.tapToRemapUI] ?? false }
    public var mupenTransferPak: Bool { featureStates[.mupenTransferPak] ?? false }
    public var netplayEnabled: Bool { featureStates[.netplayEnabled] ?? false }
    public var modernWebServer: Bool { featureStates[.modernWebServer] ?? false }
    public var clipBuffering: Bool { featureStates[.clipBuffering] ?? false }
    public var liveBroadcast: Bool { featureStates[.liveBroadcast] ?? false }
    public var companionController: Bool { featureStates[.companionController] ?? false }
    public var smartCoreSelection: Bool { featureStates[.smartCoreSelection] ?? false }
    public var lightGunCrosshair: Bool { featureStates[.lightGunCrosshair] ?? false }
    public var skinButtonReposition: Bool { featureStates[.skinButtonReposition] ?? false }
    public var enhancedArtworkSearch: Bool { featureStates[.enhancedArtworkSearch] ?? false }

    // MARK: - Feature Queries

    /// Returns `true` if the feature is enabled. For known `PVFeature` cases the
    /// pre-computed `featureStates` cache is used; unknown raw keys fall back to the engine.
    public func isEnabled(_ featureKey: String) -> Bool {
        if let feature = PVFeature(rawValue: featureKey) {
            return featureStates[feature] ?? false
        }
        return featureFlags.isEnabled(featureKey)
    }

    // MARK: - Remote Configuration

    /// Configure a remote URL for feature flags with optional cache and retry settings.
    public func configureRemote(url: URL, cacheDuration: TimeInterval = 3600, maxRetries: Int = 3) {
        remoteFetcher = PVFeatureFlagsFetcher(url: url, maxRetries: maxRetries, cacheDuration: cacheDuration)
    }

    /// Load configuration from a specific URL (simple, no retry/cache logic).
    public func loadConfiguration(from url: URL) async throws {
        try await featureFlags.loadConfiguration(from: url)
        // stateDidChange fires automatically; _updateFeatureStates will be called via Combine.
    }

    /// Load remote configuration using the configured fetcher.
    ///
    /// Priority order:
    /// 1. Fresh cache (if valid)
    /// 2. Remote fetch with exponential-backoff retry
    /// 3. Stale cache (if remote fails)
    /// 4. Bundled `features.json` (last resort)
    public func loadRemoteConfiguration() async throws {
        guard let fetcher = remoteFetcher else {
            throw PVFeatureFlagsFetcherError.notConfigured
        }

        if fetcher.isCacheValid(), let cached = fetcher.loadCached() {
            featureFlags.setConfiguration(cached)
            return
        }

        do {
            let config = try await fetcher.fetchWithRetry()
            featureFlags.setConfiguration(config)
        } catch {
            if let stale = fetcher.loadCached() {
                featureFlags.setConfiguration(stale)
                return
            }
            if featureFlags.loadBundledConfiguration() { return }
            throw error
        }
    }

    /// Refresh the configuration only if the cache has expired.
    public func refreshIfNeeded() async throws {
        guard let fetcher = remoteFetcher, !fetcher.isCacheValid() else { return }
        try await loadRemoteConfiguration()
    }

    /// Force a fresh fetch from remote, ignoring cache freshness.
    public func forceRefresh() async throws {
        guard let fetcher = remoteFetcher else {
            throw PVFeatureFlagsFetcherError.notConfigured
        }
        let config = try await fetcher.fetchWithRetry()
        featureFlags.setConfiguration(config)
    }

    // MARK: - Debug Overrides

    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        featureFlags.setDebugOverride(for: feature, enabled: enabled)
        // stateDidChange fires; manager updates via Combine subscription.
    }

    public func clearDebugOverrides() {
        featureFlags.clearDebugOverrides()
    }

    public func getCurrentDebugOverrides() -> [PVFeature: Bool?] {
        featureFlags.debugOverrides
    }

    // MARK: - Debug Configuration

    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        featureFlags.setDebugConfiguration(features: features)
    }

    // MARK: - Feature Info

    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        featureFlags.getAllFeatureFlags()
    }

    public func getFeatureRestrictions(_ featureKey: String) -> [String] {
        featureFlags.getFeatureRestrictions(featureKey)
    }

    // MARK: - Observable Access

    /// Returns a `FeatureFlagObservable` for a specific feature, cached for reuse.
    public func flag(_ feature: PVFeature) -> FeatureFlagObservable {
        if let existing = flagObservablesCache[feature] { return existing }
        let observable = FeatureFlagObservable(manager: self, feature: feature)
        flagObservablesCache[feature] = observable
        return observable
    }

    // MARK: - Private

    private func _updateFeatureStates() {
        var newStates: [PVFeature: Bool] = [:]
        var hasChanges = false
        for feature in PVFeature.allCases {
            let state = featureFlags.isEnabled(feature)
            newStates[feature] = state
            if featureStates[feature] != state { hasChanges = true }
        }
        if hasChanges || featureStates.count != newStates.count {
            featureStates = newStates
        }
    }
}

/// An observable object tracking the enabled state of a single feature flag.
@MainActor public final class FeatureFlagObservable: ObservableObject {
    @Published public var value: Bool
    private let feature: PVFeature
    private var cancellable: AnyCancellable?

    init(manager: PVFeatureFlagsManager, feature: PVFeature) {
        self.feature = feature
        self.value = manager.featureStates[feature] ?? false

        self.cancellable = manager.$featureStates
            .map { $0[feature] ?? false }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.value, on: self)
    }
}
#endif

// MARK: - SwiftUI Environment

#if canImport(SwiftUI)
import SwiftUI

private struct PVFeatureFlagsManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = PVFeatureFlagsManager.shared
}

extension EnvironmentValues {
    /// Access to feature flags in SwiftUI views
    public var featureFlags: PVFeatureFlagsManager {
        get { self[PVFeatureFlagsManagerKey.self] }
        set { self[PVFeatureFlagsManagerKey.self] = newValue }
    }
}
#endif
