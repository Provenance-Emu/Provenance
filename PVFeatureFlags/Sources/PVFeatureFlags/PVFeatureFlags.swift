//
//  PVFeatureFlags.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/6/25.
//  Copyright 2025 Joseph Mattiello. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Combine)
import Combine
#endif

/// Enum representing all available feature flags
public enum PVFeature: String, CaseIterable {
    case inAppFreeROMs = "inAppFreeROMs"
    case romPathMigrator = "romPathMigrator"
    case cheatsUseSwiftUI = "cheatsUseSwiftUI"
    case cheatsOnlineLookup = "cheatsOnlineLookup"
    case retroarchBuiltinEditor = "retroarchBuiltinEditor"
    case advancedSkinFeatures = "advancedSkinFeatures"
    case contentlessCores = "contentlessCores"
    /// Enables runtime scanning of Frameworks/ for bare libretro dylibs/frameworks
    /// and registers them through the thin PVThinLibretroFrontend. Disabled by default;
    /// enable via UserDefaults debug override or features.json to test dynamic cores.
    case dynamicLibretroScanner = "dynamicLibretroScanner"
}

/// Represents the type of app installation
public enum PVAppType: String, CaseIterable {
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
        allowedAppTypes: ["standard", "lite"],
        description: "Scans Frameworks/ at startup for bare libretro dylibs/frameworks and loads them via PVThinLibretroFrontend. Enable to test buildbot cores without RetroArch. Non-AppStore only."
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

/// Core feature flags engine: loads configuration, evaluates flag states against app criteria.
@MainActor public final class PVFeatureFlags: @unchecked Sendable {
    /// Shared instance
    public static let shared = PVFeatureFlags()

    internal private(set) var configuration: FeatureFlagsConfiguration?
    private let appType: PVAppType
    private let buildNumber: String?
    private let appVersion: String

    public init(appType: PVAppType? = nil,
                buildNumber: String? = nil,
                appVersion: String? = nil) {
        self.appType = appType ?? PVFeatureFlags.getCurrentAppType()
        self.buildNumber = buildNumber ?? PVFeatureFlags.getCurrentBuildNumber()
        self.appVersion = appVersion ?? PVFeatureFlags.getCurrentAppVersion()
    }

    /// Convenience initializer with a pre-loaded configuration (for testing)
    internal convenience init(
        configuration: FeatureFlagsConfiguration,
        appType: PVAppType? = nil,
        buildNumber: String? = nil,
        appVersion: String? = nil
    ) {
        self.init(appType: appType, buildNumber: buildNumber, appVersion: appVersion)
        self.configuration = configuration
    }

    /// Set configuration directly (for testing or programmatic setup)
    internal func setConfiguration(_ configuration: FeatureFlagsConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Configuration Loading

    /// Load feature flags from a JSON file at the given URL (remote or local).
    public func loadConfiguration(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        configuration = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
    }

    /// Load the bundled `features.json` shipped inside the SPM package as a fallback.
    /// - Returns: `true` if the bundled configuration was loaded successfully.
    @discardableResult
    public func loadBundledConfiguration() -> Bool {
        guard let url = Bundle.module.url(forResource: "features", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        else { return false }
        configuration = config
        return true
    }

    // MARK: - App Metadata

    public static func getCurrentAppType() -> PVAppType {
        let appTypeString = Bundle.main.infoDictionary?["PVAppType"] as? String ?? "standard"
        return PVAppType(rawValue: appTypeString) ?? .standard
    }

    public static func getCurrentBuildNumber() -> String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    public static func getCurrentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Feature Evaluation

    /// Check whether a feature is enabled by its `PVFeature` enum case.
    public func isEnabled(_ feature: PVFeature) -> Bool {
        // Debug overrides take highest priority
        if let overrideEntry = self.debugOverrides[feature],
           let boolValue = overrideEntry {
            return boolValue
        }

        guard let featureConfig = configuration?.features[feature.rawValue] else {
            return false
        }

        if let allowedTypes = featureConfig.allowedAppTypes,
           !allowedTypes.contains(appType.rawValue) {
            return false
        }

        if let minBuild = featureConfig.minBuildNumber,
           let currentBuild = buildNumber,
           compareVersions(currentBuild, minBuild) < 0 {
            return false
        }

        if let minVersion = featureConfig.minVersion,
           compareVersions(appVersion, minVersion) < 0 {
            return false
        }

        return featureConfig.enabled
    }

    /// Check whether a feature is enabled by its raw string key.
    public func isEnabled(_ featureKey: String) -> Bool {
        // If this key matches a known PVFeature, use the enum-based evaluation (including debug overrides).
        if let feature = PVFeature(rawValue: featureKey) {
            return isEnabled(feature)
        }

        // Otherwise, evaluate directly from the configuration using the raw key.
        guard let featureConfig = configuration?.features[featureKey] else {
            return false
        }

        if let allowedTypes = featureConfig.allowedAppTypes,
           !allowedTypes.contains(appType.rawValue) {
            return false
        }

        if let minBuild = featureConfig.minBuildNumber,
           let currentBuild = buildNumber,
           compareVersions(currentBuild, minBuild) < 0 {
            return false
        }

        if let minVersion = featureConfig.minVersion,
           compareVersions(appVersion, minVersion) < 0 {
            return false
        }

        return featureConfig.enabled
    }

    /// Returns an array of restriction reasons for a feature (empty = no restrictions / feature not found).
    public func getFeatureRestrictions(_ featureKey: String) -> [String] {
        guard let feature = configuration?.features[featureKey] else { return ["Feature not found"] }

        var restrictions: [String] = []

        if let allowedTypes = feature.allowedAppTypes,
           !allowedTypes.contains(appType.rawValue) {
            restrictions.append("App type \(appType.rawValue) not allowed")
        }

        if let minBuild = feature.minBuildNumber,
           let currentBuild = buildNumber,
           compareVersions(currentBuild, minBuild) < 0 {
            restrictions.append("Build \(currentBuild) below minimum \(minBuild)")
        }

        if let minVersion = feature.minVersion,
           compareVersions(appVersion, minVersion) < 0 {
            restrictions.append("Version \(appVersion) below minimum \(minVersion)")
        }

        return restrictions
    }

    /// Returns all feature flags with their config and current enabled state.
    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        PVFeature.allCases.map { featureCase in
            let key = featureCase.rawValue
            let featureConfig = configuration?.features[key]
                ?? FeatureFlag(enabled: false, description: "Feature not defined in configuration")
            return (key: key, flag: featureConfig, enabled: isEnabled(featureCase))
        }
    }

    // MARK: - Debug Overrides

    /// Set a debug/test configuration, replacing any loaded configuration.
    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        self.configuration = FeatureFlagsConfiguration(features: features)
    }

    internal var debugOverrides: [PVFeature: Bool?] {
        get {
            let defaults = UserDefaults.standard
            guard let rawDict = defaults.dictionary(forKey: "PVFeatureFlagsDebugOverrides") else {
                return [:]
            }
            var result: [PVFeature: Bool?] = [:]
            for (key, value) in rawDict {
                guard let feature = PVFeature(rawValue: key) else { continue }
                if let boolValue = value as? Bool {
                    result[feature] = boolValue
                } else if (value as? String) == "nil" {
                    result[feature] = nil
                }
            }
            return result
        }
        set {
            var storableDict: [String: Any] = [:]
            for (feature, optionalValue) in newValue {
                if let boolValue = optionalValue {
                    storableDict[feature.rawValue] = boolValue
                } else {
                    storableDict[feature.rawValue] = "nil"
                }
            }
            UserDefaults.standard.set(storableDict, forKey: "PVFeatureFlagsDebugOverrides")
        }
    }

    /// Set a per-feature debug override (`nil` clears the override).
    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        var current = self.debugOverrides
        current[feature] = enabled
        self.debugOverrides = current
    }

    /// Clear all debug overrides.
    public func clearDebugOverrides() {
        self.debugOverrides = [:]
    }

    // MARK: - Helpers

    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".")
        let components2 = version2.split(separator: ".")
        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let num1 = i < components1.count ? Int(components1[i]) ?? 0 : 0
            let num2 = i < components2.count ? Int(components2[i]) ?? 0 : 0
            if num1 < num2 { return -1 }
            if num1 > num2 { return 1 }
        }
        return 0
    }
}

// MARK: - PVFeatureFlagsManager

#if canImport(Combine)
/// Observable manager for SwiftUI integration; wraps `PVFeatureFlags` and publishes reactive state.
@MainActor public final class PVFeatureFlagsManager: ObservableObject, @unchecked Sendable {
    /// Shared singleton
    public static let shared = PVFeatureFlagsManager()

    private let featureFlags: PVFeatureFlags
    private var remoteFetcher: PVFeatureFlagsFetcher?

    /// Published dictionary of current feature states.
    @Published public private(set) var featureStates: [PVFeature: Bool] = [:]

    private var flagObservablesCache: [PVFeature: FeatureFlagObservable] = [:]

    private init() {
        self.featureFlags = PVFeatureFlags()
        updateFeatureStates()
    }

    init(featureFlags: PVFeatureFlags) {
        self.featureFlags = featureFlags
        updateFeatureStates()
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

    // MARK: - Feature Queries

    /// Check whether a feature is enabled by its raw string key.
    /// - Parameter featureKey: The raw string key for the feature.
    /// - Returns: `true` if the feature is enabled. For keys that map to a `PVFeature` case,
    ///            the precomputed `featureStates` are used; otherwise, this falls back to
    ///            the underlying `featureFlags` configuration.
    public func isEnabled(_ featureKey: String) -> Bool {
        if let feature = PVFeature(rawValue: featureKey) {
            return featureStates[feature] ?? false
        }

        return featureFlags.isEnabled(featureKey)
    }

    // MARK: - Remote Configuration

    /// Configure a remote URL for feature flags with optional cache and retry settings.
    /// - Parameters:
    ///   - url: Remote URL of the JSON configuration
    ///   - cacheDuration: Seconds before a cached config is considered stale (default: 3600)
    ///   - maxRetries: Maximum retry attempts on network failure (default: 3)
    public func configureRemote(url: URL, cacheDuration: TimeInterval = 3600, maxRetries: Int = 3) {
        remoteFetcher = PVFeatureFlagsFetcher(url: url, maxRetries: maxRetries, cacheDuration: cacheDuration)
    }

    /// Load configuration from a specific URL (simple, no retry/cache logic).
    public func loadConfiguration(from url: URL) async throws {
        try await featureFlags.loadConfiguration(from: url)
        updateFeatureStates()
    }

    /// Load remote configuration using the configured fetcher.
    ///
    /// Priority order:
    /// 1. Fresh cache (if valid)
    /// 2. Remote fetch with exponential-backoff retry
    /// 3. Stale cache (if remote fails)
    /// 4. Bundled `features.json` (last resort)
    ///
    /// - Throws: `PVFeatureFlagsFetcherError.notConfigured` if no remote URL is set,
    ///           or any network/decoding error if all fallbacks fail.
    public func loadRemoteConfiguration() async throws {
        guard let fetcher = remoteFetcher else {
            throw PVFeatureFlagsFetcherError.notConfigured
        }

        // 1. Fresh cache
        if fetcher.isCacheValid(), let cached = fetcher.loadCached() {
            featureFlags.setConfiguration(cached)
            updateFeatureStates()
            return
        }

        // 2. Remote fetch with retry
        do {
            let config = try await fetcher.fetchWithRetry()
            featureFlags.setConfiguration(config)
            updateFeatureStates()
        } catch {
            // 3. Stale cache fallback
            if let stale = fetcher.loadCached() {
                featureFlags.setConfiguration(stale)
                updateFeatureStates()
                return
            }
            // 4. Bundled fallback
            if featureFlags.loadBundledConfiguration() {
                updateFeatureStates()
                return
            }
            // All fallbacks failed — propagate the original error
            throw error
        }
    }

    /// Refresh the configuration only if the cache has expired.
    /// Does nothing if no remote URL is configured or the cache is still valid.
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
        updateFeatureStates()
    }

    // MARK: - Debug Overrides

    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        featureFlags.setDebugOverride(for: feature, enabled: enabled)
        updateFeatureStates()
    }

    public func clearDebugOverrides() {
        featureFlags.clearDebugOverrides()
        updateFeatureStates()
    }

    public func getCurrentDebugOverrides() -> [PVFeature: Bool?] {
        featureFlags.debugOverrides
    }

    // MARK: - Debug Configuration

    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        featureFlags.setDebugConfiguration(features: features)
        updateFeatureStates()
    }

    // MARK: - Feature Info

    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        PVFeature.allCases.map { featureCase in
            let key = featureCase.rawValue
            let featureConfig = featureFlags.configuration?.features[key]
                ?? FeatureFlag(enabled: false, description: "Feature not defined in configuration")
            return (key: key, flag: featureConfig, enabled: featureFlags.isEnabled(featureCase))
        }
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

    private func updateFeatureStates() {
        var newStates: [PVFeature: Bool] = [:]
        var hasChanges = false

        for feature in PVFeature.allCases {
            let effectiveState = featureFlags.isEnabled(feature)
            newStates[feature] = effectiveState
            if featureStates[feature] != effectiveState { hasChanges = true }
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
