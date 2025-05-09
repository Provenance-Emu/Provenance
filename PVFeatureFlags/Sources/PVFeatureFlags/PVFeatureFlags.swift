//
//  PVFeatureFlags.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/6/25.
//  Copyright 2025 Joseph Mattiello. All rights reserved.
//

import Foundation
import Combine

/// Enum representing all available feature flags
public enum PVFeature: String, CaseIterable {
    case inAppFreeROMs = "inAppFreeROMs"
    case romPathMigrator = "romPathMigrator"
    case cheatsUseSwiftUI = "cheatsUseSwiftUI"
    case retroarchBuiltinEditor = "retroarchBuiltinEditor"
    case advancedSkinFeatures = "advancedSkinFeatures"
    case contentlessCores = "contentlessCores"
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

    /// Initialize a new feature flag
    /// - Parameters:
    ///   - enabled: Whether the feature is enabled by default
    ///   - minVersion: Minimum version required (optional)
    ///   - minBuildNumber: Minimum build number required (optional)
    ///   - allowedAppTypes: List of allowed app types (optional)
    ///   - description: Description of the feature (optional)
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

    /// Enables advanced skin features like filters and debug mode
    public static let advancedSkinFeatures = FeatureFlag(
        enabled: false,
        description: "Enables advanced skin features like filters and debug mode"
    )

    /// Enables the built-in RetroArch editor
    public static let retroarchBuiltinEditor = FeatureFlag(
        enabled: false,
        minVersion: "3.0.5",
        allowedAppTypes: ["standard", "lite"],
        description: "Enables the built-in RetroArch editor. Disabled for App Store builds."
    )

    /// Enables contentless cores like DOOM, Quake, etc
    public static let contentlessCores = FeatureFlag(
        enabled: false,
        minVersion: "3.0.5",
        allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
        description: "Enables contentless cores like DOOM, Quake, etc. Disabled for App Store builds."
    )
}

/// Root structure for feature flags JSON
public struct FeatureFlagsConfiguration: Codable, Sendable {
    /// Dictionary of feature flags
    public let features: [String: FeatureFlag]
}

/// Main class for managing feature flags, handling configuration loading, and evaluating flag states against app criteria.
@MainActor public final class PVFeatureFlags: @unchecked Sendable {
    /// Shared instance for accessing feature flags
    public static let shared = PVFeatureFlags()

    internal private(set) var configuration: FeatureFlagsConfiguration?
    private let appType: PVAppType
    private let buildNumber: String?
    private let appVersion: String

    /// Initialize with custom parameters
    /// - Parameters:
    ///   - appType: The type of app installation
    ///   - buildNumber: Current build number
    ///   - appVersion: Current app version
    public init(appType: PVAppType? = nil,
                buildNumber: String? = nil,
                appVersion: String? = nil) {
        self.appType = appType ?? PVFeatureFlags.getCurrentAppType()
        self.buildNumber = buildNumber ?? PVFeatureFlags.getCurrentBuildNumber()
        self.appVersion = appVersion ?? PVFeatureFlags.getCurrentAppVersion()
    }

    /// Initialize with a pre-loaded configuration (for testing)
    internal convenience init(
        configuration: FeatureFlagsConfiguration,
        appType: PVAppType? = nil,
        buildNumber: String? = nil,
        appVersion: String? = nil
    ) {
        self.init(appType: appType, buildNumber: buildNumber, appVersion: appVersion)
        self.configuration = configuration
    }

    /// Set configuration directly (for testing)
    internal func setConfiguration(_ configuration: FeatureFlagsConfiguration) {
        self.configuration = configuration
    }

    /// Load feature flags from a JSON file URL
    /// - Parameter url: URL to the JSON configuration
    /// - Returns: Async task that loads and parses the configuration
    public func loadConfiguration(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        configuration = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        print("Loaded confuration. \(configuration?.features.count ?? 0) features")
    }

    /// Get current app type from Info.plist
    public static func getCurrentAppType() -> PVAppType {
        let appTypeString = Bundle.main.infoDictionary?["PVAppType"] as? String ?? "standard"
        return PVAppType(rawValue: appTypeString) ?? .standard
    }

    /// Get current build number from Info.plist
    public static func getCurrentBuildNumber() -> String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    /// Get current app version from Info.plist
    public static func getCurrentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Helper function to compare version strings
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".")
        let components2 = version2.split(separator: ".")

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let num1 = i < components1.count ? Int(components1[i]) ?? 0 : 0
            let num2 = i < components2.count ? Int(components2[i]) ?? 0 : 0

            if num1 < num2 {
                return -1
            } else if num1 > num2 {
                return 1
            }
        }
        return 0
    }

    /// Retrieves a list of restriction reasons for a specific feature flag.
    /// - Parameter featureKey: The raw string value of the `PVFeature`.
    /// - Returns: An array of strings, each describing a reason the feature might be restricted (e.g., version, app type). Empty if no restrictions or feature not found.
    public func getFeatureRestrictions(_ featureKey: String) -> [String] {
        guard let feature = configuration?.features[featureKey] else { return ["Feature not found"] }

        var restrictions: [String] = []

        // Check app type restrictions
        if let allowedTypes = feature.allowedAppTypes,
           !allowedTypes.contains(PVFeatureFlags.getCurrentAppType().rawValue) {
            restrictions.append("App type \(PVFeatureFlags.getCurrentAppType().rawValue) not allowed")
        }

        // Check build number requirement
        if let minBuild = feature.minBuildNumber,
           let currentBuild = PVFeatureFlags.getCurrentBuildNumber(),
           compareVersions(currentBuild, minBuild) < 0 {
            restrictions.append("Build \(currentBuild) below minimum \(minBuild)")
        }

        // Check version requirement
        if let minVersion = feature.minVersion,
           compareVersions(PVFeatureFlags.getCurrentAppVersion(), minVersion) < 0 {
            restrictions.append("Version \(PVFeatureFlags.getCurrentAppVersion()) below minimum \(minVersion)")
        }

        return restrictions
    }

    /// Allows setting a debug/test configuration directly, bypassing JSON loading.
    /// - Parameter features: A dictionary where keys are feature raw string values and values are `FeatureFlag` configurations.
    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        self.configuration = FeatureFlagsConfiguration(features: features)
    }

    // Reverted to manual UserDefaults access for _debugOverridesStorage
    /// Internal storage for debug overrides, persisted in UserDefaults. Keys are feature raw strings.
    private var _debugOverridesStorage: [String: Bool?] {
        get {
            // UserDefaults can't directly store Bool? values, so we need to convert
            // We'll use a dictionary where:
            // - Key exists with value true = Bool?(true)
            // - Key exists with value false = Bool?(false)
            // - Key doesn't exist = nil (no override)
            let defaults = UserDefaults.standard
            guard let rawDict = defaults.dictionary(forKey: "PVFeatureFlagsDebugOverrides") as? [String: Any] else {
                return [:]
            }
            
            var result: [String: Bool?] = [:]
            for (key, value) in rawDict {
                if let boolValue = value as? Bool {
                    result[key] = boolValue
                } else if let stringValue = value as? String, stringValue == "nil" {
                    // This represents an explicit nil override
                    result[key] = nil
                }
            }
            
            print("Debug overrides loaded from UserDefaults: \(result)")
            return result
        }
        set {
            // Convert Bool? to a format UserDefaults can store
            var storableDict: [String: Any] = [:]
            for (key, optionalValue) in newValue {
                if let boolValue = optionalValue {
                    // Store true/false directly
                    storableDict[key] = boolValue
                } else {
                    // Store nil as a special string marker
                    storableDict[key] = "nil"
                }
            }
            
            print("Saving debug overrides to UserDefaults: \(storableDict)")
            UserDefaults.standard.set(storableDict, forKey: "PVFeatureFlagsDebugOverrides")
        }
    }

    // Stored as [String: Bool?] in UserDefaults
    /// Computed property to access and manage debug overrides with `PVFeature` keys, backed by `_debugOverridesStorage`.
    internal var debugOverrides: [PVFeature: Bool?] { // Changed to internal
        get {
            let stringKeyedOverrides = _debugOverridesStorage
            var featureKeyedOverrides: [PVFeature: Bool?] = [:]
            for (key, value) in stringKeyedOverrides {
                if let featureKey = PVFeature(rawValue: key) {
                    featureKeyedOverrides[featureKey] = value
                }
            }
            return featureKeyedOverrides
        }
        set {
            var stringKeyedOverrides: [String: Bool?] = [:]
            for (featureKey, value) in newValue {
                stringKeyedOverrides[featureKey.rawValue] = value
            }
            _debugOverridesStorage = stringKeyedOverrides
            // No call to updateFeatureStates here; manager handles its own updates.
        }
    }

    /// Checks if a specific feature is currently enabled based on its configuration, app criteria (version, build, type), and any debug overrides.
    /// - Parameter feature: The `PVFeature` to check.
    /// - Returns: `true` if the feature is enabled, `false` otherwise.
    public func isEnabled(_ feature: PVFeature) -> Bool {
        // Check for a debug override first
        if let overrideValue = self.debugOverrides[feature] {
            // If we have an explicit override value (true or false), return it
            if let boolValue = overrideValue {
                print("Feature \(feature.rawValue) using override value: \(boolValue)")
                return boolValue
            }
            // If we have a nil value in the dictionary, it means the override was cleared
            // Fall through to normal logic
        }
        
        guard let featureConfig = configuration?.features[feature.rawValue] else {
            print("Error: Feature \(feature) not found")
            return false
        }

        // Check app type restrictions
        if let allowedTypes = featureConfig.allowedAppTypes,
           !allowedTypes.contains(appType.rawValue) {
            print("Feature: \(feature) is not allowed for app type \(appType.rawValue)")
            return false
        }

        // Check build number requirement
        if let minBuild = featureConfig.minBuildNumber,
           let currentBuild = buildNumber,
           compareVersions(currentBuild, minBuild) < 0 {
            print("Feature: \(feature) is not allowed for build \(currentBuild)")
            return false
        }

        // Check version requirement
        if let minVersion = featureConfig.minVersion,
           compareVersions(appVersion, minVersion) < 0 {
            print("Feature: \(feature) is not allowed for version \(appVersion)")
            return false
        }
        print("Feature: \(feature) is enabled")
        return featureConfig.enabled
    }
    
    /// Set a debug override for a specific feature flag.
    /// This will override any configuration from the JSON file or default settings.
    /// - Parameters:
    ///   - feature: The `PVFeature` to override.
    ///   - enabled: `true` to force enable, `false` to force disable, `nil` to clear the override.
    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        print("Setting debug override for feature \(feature.rawValue) to \(String(describing: enabled))")
        
        var currentOverrides = self.debugOverrides
        currentOverrides[feature] = enabled
        self.debugOverrides = currentOverrides
        
        // Verify the override was set correctly
        let verifyOverrides = self.debugOverrides
        if let verifyValue = verifyOverrides[feature] {
            print("Verified override for \(feature.rawValue) is now set to \(String(describing: verifyValue))")
        } else {
            print("Warning: Failed to set override for \(feature.rawValue)")
        }
    }
    
    /// Clears all currently set debug overrides, reverting features to their configured states based on JSON/defaults.
    public func clearDebugOverrides() {
        print("Clearing all debug overrides")
        self.debugOverrides = [:]
    }

    /// Retrieves all feature flags along with their configuration details and current enabled status.
    /// Primarily intended for debugging and displaying feature flag information.
    /// - Returns: An array of tuples, each containing the feature key (String), its `FeatureFlag` configuration, and its current enabled state (Bool).
    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        PVFeature.allCases.map { featureCase in
            let key = featureCase.rawValue
            let featureConfig = self.configuration?.features[key] ?? FeatureFlag(enabled: false, description: "Feature not defined in configuration")
            let isEnabled = self.isEnabled(featureCase) // This now correctly checks overrides first
            return (key: key, flag: featureConfig, enabled: isEnabled)
        }
    }
}

/// Observable class for managing feature flags in SwiftUI, providing reactive updates to the UI.
/// This class acts as a wrapper around `PVFeatureFlags`, exposing feature states through Combine publishers
/// and providing an interface for observing individual flags.
@MainActor public final class PVFeatureFlagsManager: ObservableObject, @unchecked Sendable {
    /// Shared singleton instance of the feature flags manager.
    public static let shared = PVFeatureFlagsManager()

    /// The underlying `PVFeatureFlags` instance that handles core logic and data persistence.
    private let featureFlags: PVFeatureFlags

    /// Published dictionary of current feature states. Views can subscribe to this to react to changes in any feature flag.
    /// Keys are `PVFeature` enums, values are `Bool` indicating if the feature is enabled.
    @Published public private(set) var featureStates: [PVFeature: Bool] = [:]

    /// Cache for `FeatureFlagObservable` instances to avoid recreating them, ensuring a single observable per feature.
    private var flagObservablesCache: [PVFeature: FeatureFlagObservable] = [:]

    /// Private initializer to enforce singleton pattern. Loads initial states.
    private init() {
        self.featureFlags = PVFeatureFlags()
        updateFeatureStates() // Initialize states
    }

    /// Internal initializer for testing purposes, allowing injection of a custom `PVFeatureFlags` instance.
    /// - Parameter featureFlags: A specific `PVFeatureFlags` instance to use.
    init(featureFlags: PVFeatureFlags) {
        self.featureFlags = featureFlags
        updateFeatureStates()
    }

    /// Asynchronously loads the feature flag configuration from a given URL.
    /// After loading, it updates the internal `featureStates` to reflect the new configuration.
    /// - Parameter url: The URL of the JSON configuration file.
    /// - Throws: An error if loading or parsing the configuration fails.
    public func loadConfiguration(from url: URL) async throws {
        do {
            try await featureFlags.loadConfiguration(from: url)
            print("Loaded configuration from \(url)")
            updateFeatureStates()
        } catch {
            print("Failed to load configuration from \(url): \(error)")
            throw error
        }
    }

    /// Sets a debug override for a specific feature flag.
    /// This will override any configuration from the JSON file or default settings.
    /// - Parameters:
    ///   - feature: The `PVFeature` to override.
    ///   - enabled: `true` to force enable, `false` to force disable, `nil` to clear the override.
    public func setDebugOverride(for feature: PVFeature, enabled: Bool?) {
        // Delegate to the underlying PVFeatureFlags instance to set the override
        self.featureFlags.setDebugOverride(for: feature, enabled: enabled)
        // Then, update the manager's published states
        self.updateFeatureStates()
    }

    /// Clears all currently set debug overrides, reverting features to their configured states.
    public func clearDebugOverrides() {
        self.featureFlags.clearDebugOverrides() // Delegate
        self.updateFeatureStates() // Update manager's state
    }

    /// Updates the `featureStates` dictionary based on the current configuration in `featureFlags` and any active debug overrides.
    /// This method is called internally whenever the configuration or overrides change to ensure `featureStates` is consistent.
    private func updateFeatureStates() {
        var newStates: [PVFeature: Bool] = [:]
        var hasChanges = false

        for featureKey in PVFeature.allCases {
            // self.featureFlags.isEnabled(featureKey) now correctly incorporates override logic.
            let effectiveState = self.featureFlags.isEnabled(featureKey)
            
            newStates[featureKey] = effectiveState

            if self.featureStates[featureKey] != effectiveState {
                hasChanges = true
            }
        }
        
        // Only update and send notification if there were actual changes
        if hasChanges || self.featureStates.count != newStates.count { // also check count in case a flag was removed/added (though enum prevents this)
            let changedStates = newStates.filter { key, value in
                self.featureStates[key] != value || self.featureStates.keys.contains(key) == false
            }
            if !changedStates.isEmpty {
                print("PVFeatureFlagsManager: Broadcasting feature state changes. Changed: \(changedStates.mapValues { String(describing: $0) })")
            }
            self.featureStates = newStates
            // objectWillChange.send() is automatically called by @Published when featureStates is set.
        }
    }

    /// Returns an observable object for the given feature flag.
    /// SwiftUI views can use instances of this class with `@ObservedObject` or `@StateObject`
    /// to react to changes in a specific feature's enabled status.
    /// - Parameter feature: The specific `PVFeature` this observable should track.
    /// - Returns: A `FeatureFlagObservable` instance bound to the specified feature.
    public func flag(_ feature: PVFeature) -> FeatureFlagObservable {
        if let existingObservable = flagObservablesCache[feature] {
            return existingObservable
        }
        let newObservable = FeatureFlagObservable(manager: self, feature: feature)
        flagObservablesCache[feature] = newObservable
        return newObservable
    }

    /// Retrieves all feature flags along with their configuration details and current enabled status.
    /// Primarily intended for debugging and displaying feature flag information.
    /// - Returns: An array of tuples, each containing the feature key (String), its `FeatureFlag` configuration, and its current enabled state (Bool).
    public func getAllFeatureFlags() -> [(key: String, flag: FeatureFlag, enabled: Bool)] {
        PVFeature.allCases.map { featureCase in
            let key = featureCase.rawValue
            let featureConfig = self.featureFlags.configuration?.features[key] ?? FeatureFlag(enabled: false, description: "Feature not defined in configuration")
            let isEnabled = self.featureFlags.isEnabled(featureCase) // This now correctly checks overrides first
            return (key: key, flag: featureConfig, enabled: isEnabled)
        }
    }

    /// Retrieves the current raw debug overrides.
    /// - Returns: A dictionary mapping features to their optional boolean override state (`nil` if not overridden).
    public func getCurrentDebugOverrides() -> [PVFeature: Bool?] {
        return self.featureFlags.debugOverrides
    }

    /// Retrieves the restriction reasons for a specific feature flag by its key.
    /// Delegates to the underlying `PVFeatureFlags` instance.
    /// - Parameter featureKey: The raw string value of the `PVFeature`.
    /// - Returns: An array of strings describing restriction reasons.
    public func getFeatureRestrictions(_ featureKey: String) -> [String] {
        return featureFlags.getFeatureRestrictions(featureKey)
    }

    /// Allows setting a debug/test configuration directly on the underlying `PVFeatureFlags` instance.
    /// After setting, it triggers an update of the manager's `featureStates`.
    /// - Parameter features: A dictionary where keys are feature raw string values and values are `FeatureFlag` configurations.
    public func setDebugConfiguration(features: [String: FeatureFlag]) {
        featureFlags.setDebugConfiguration(features: features)
        updateFeatureStates() // Crucial to refresh all states after setting debug config
    }
}

/// An observable object that represents the state of a single feature flag.
/// SwiftUI views can use instances of this class with `@ObservedObject` or `@StateObject`
/// to react to changes in a specific feature's enabled status.
@MainActor public final class FeatureFlagObservable: ObservableObject {
    /// Published property indicating whether the observed feature flag is currently enabled. Changes to this property will trigger UI updates.
    @Published public var value: Bool {
        didSet {
            if oldValue != value { // Only log if the value actually changed
                print("FeatureFlagObservable: \(self.feature.rawValue) changed from \(oldValue) to \(self.value)")
            }
        }
    }
    private let feature: PVFeature // Added to store the feature for logging
    /// Cancellable for the subscription to the manager's `featureStates`.
    private var cancellable: AnyCancellable?

    /// Initializes a new `FeatureFlagObservable`.
    /// - Parameters:
    ///   - manager: The `PVFeatureFlagsManager` instance that manages the state of all feature flags.
    ///   - feature: The specific `PVFeature` this observable should track.
    init(manager: PVFeatureFlagsManager, feature: PVFeature) {
        self.feature = feature // Store the feature
        // Initialize value correctly from the manager's current state
        self.value = manager.featureStates[feature] ?? false

        // Subscribe to changes in the manager's featureStates dictionary
        self.cancellable = manager.$featureStates
            .map { states -> Bool in // Extract the specific flag's state
                states[feature] ?? false // Default to false if key somehow missing
            }
            .removeDuplicates() // Only emit if the value has actually changed
            .receive(on: DispatchQueue.main) // Ensure updates are on the main thread for UI
            .assign(to: \.value, on: self) // Assign to our @Published value property, this returns AnyCancellable
    }
}

// MARK: - Environment Values
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
