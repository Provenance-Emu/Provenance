import Testing
import Foundation
#if canImport(Combine)
import Combine
#endif
@testable import PVFeatureFlags

// MARK: - Test Fixtures

let sampleJSON = """
{
    "features": {
        "inAppFreeROMs": {
            "enabled": true,
            "minVersion": "1.0.0",
            "minBuildNumber": "100",
            "allowedAppTypes": ["standard", "standard.appstore"],
            "description": "Allows downloading free ROMs directly in the app"
        },
        "romPathMigrator": {
            "enabled": true,
            "description": "Enables the ROM path migration tool."
        },
        "cheatsUseSwiftUI": {
            "enabled": false,
            "description": "Use SwiftUI for the cheats interface."
        },
        "retroarchBuiltinEditor": {
            "enabled": false,
            "minVersion": "3.0.5",
            "allowedAppTypes": ["standard", "lite"],
            "description": "Enables the built-in RetroArch editor."
        },
        "advancedSkinFeatures": {
            "enabled": false,
            "description": "Enables advanced skin features."
        },
        "contentlessCores": {
            "enabled": false,
            "minVersion": "3.0.5",
            "allowedAppTypes": ["standard", "lite", "standard.appstore", "lite.appstore"],
            "description": "Enables contentless cores."
        }
    }
}
"""

private func makeConfig() throws -> FeatureFlagsConfiguration {
    let data = sampleJSON.data(using: .utf8)!
    return try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
}

// MARK: - JSON Parsing

@Test func testFeatureFlagParsing() throws {
    let config = try makeConfig()

    #expect(config.features["inAppFreeROMs"]?.enabled == true)
    #expect(config.features["inAppFreeROMs"]?.minVersion == "1.0.0")
    #expect(config.features["inAppFreeROMs"]?.minBuildNumber == "100")
    #expect(config.features["inAppFreeROMs"]?.allowedAppTypes?.contains("standard") == true)
    #expect(config.features["romPathMigrator"]?.enabled == true)
    #expect(config.features["cheatsUseSwiftUI"]?.enabled == false)
}

// MARK: - PVAppType

@Test func testAppTypeChecks() {
    let standardType = PVAppType.standard
    #expect(standardType.isAppStore == false)
    #expect(standardType.isLite == false)

    let liteAppStoreType = PVAppType.liteAppStore
    #expect(liteAppStoreType.isAppStore == true)
    #expect(liteAppStoreType.isLite == true)

    let liteType = PVAppType.lite
    #expect(liteType.isAppStore == false)
    #expect(liteType.isLite == true)

    let standardAppStoreType = PVAppType.standardAppStore
    #expect(standardAppStoreType.isAppStore == true)
    #expect(standardAppStoreType.isLite == false)
}

// MARK: - PVFeatureFlags (isEnabled)

@MainActor @Test func testIsEnabledByEnum() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    #expect(flags.isEnabled(.inAppFreeROMs) == true)
    #expect(flags.isEnabled(.romPathMigrator) == true)
    #expect(flags.isEnabled(.cheatsUseSwiftUI) == false)
}

@MainActor @Test func testIsEnabledByString() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    #expect(flags.isEnabled("inAppFreeROMs") == true)
    #expect(flags.isEnabled("romPathMigrator") == true)
    #expect(flags.isEnabled("cheatsUseSwiftUI") == false)
    #expect(flags.isEnabled("unknownFeature") == false)
}

@MainActor @Test func testAppTypeRestriction() throws {
    let config = try makeConfig()

    // standard.appstore is NOT in allowedAppTypes for retroarchBuiltinEditor
    let appStoreFlags = PVFeatureFlags(
        configuration: config, appType: .standardAppStore, buildNumber: "101", appVersion: "3.1.0"
    )
    #expect(appStoreFlags.isEnabled(.retroarchBuiltinEditor) == false)

    // lite is allowed for retroarchBuiltinEditor, but enabled: false in JSON
    let liteFlags = PVFeatureFlags(
        configuration: config, appType: .lite, buildNumber: "101", appVersion: "3.1.0"
    )
    #expect(liteFlags.isEnabled(.retroarchBuiltinEditor) == false)
}

@MainActor @Test func testVersionRestriction() throws {
    let config = try makeConfig()

    // version below minVersion — retroarchBuiltinEditor requires 3.0.5
    let oldFlags = PVFeatureFlags(
        configuration: config, appType: .standard, buildNumber: "101", appVersion: "2.0.0"
    )
    #expect(oldFlags.isEnabled(.retroarchBuiltinEditor) == false)
}

@MainActor @Test func testBuildNumberRestriction() throws {
    let config = try makeConfig()

    // build number below minimum for inAppFreeROMs (minBuildNumber: "100")
    let lowBuildFlags = PVFeatureFlags(
        configuration: config, appType: .standard, buildNumber: "50", appVersion: "2.0.0"
    )
    #expect(lowBuildFlags.isEnabled(.inAppFreeROMs) == false)
}

@MainActor @Test func testLiteAppTypeIsBlocked() throws {
    let config = try makeConfig()
    // inAppFreeROMs only allows "standard" and "standard.appstore"
    let liteFlags = PVFeatureFlags(
        configuration: config, appType: .lite, buildNumber: "101", appVersion: "1.1.0"
    )
    #expect(liteFlags.isEnabled(.inAppFreeROMs) == false)
}

// MARK: - Debug Overrides

@MainActor @Test func testDebugOverrides() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    flags.clearDebugOverrides()

    // cheatsUseSwiftUI is disabled in config; override to enable
    flags.setDebugOverride(for: .cheatsUseSwiftUI, enabled: true)
    #expect(flags.isEnabled(.cheatsUseSwiftUI) == true)

    // Clear all overrides — should revert to config value (false)
    flags.clearDebugOverrides()
    #expect(flags.isEnabled(.cheatsUseSwiftUI) == false)
}

// MARK: - Bundled Configuration

@MainActor @Test func testBundledConfigurationLoads() {
    let flags = PVFeatureFlags(appType: .standard, buildNumber: "200", appVersion: "3.0.5")
    let loaded = flags.loadBundledConfiguration()
    #expect(loaded == true)
    // bundled features.json should define at least inAppFreeROMs
    #expect(flags.configuration?.features["inAppFreeROMs"] != nil)
}

// MARK: - Local File Configuration Loading

@MainActor @Test func testLoadConfigurationFromJSON() throws {
    // Test that setting a parsed configuration works end-to-end (avoids URLSession file:// on Linux)
    let config = try makeConfig()
    let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    flags.setConfiguration(config)
    #expect(flags.isEnabled(.inAppFreeROMs) == true)
    #expect(flags.isEnabled(.romPathMigrator) == true)
}

// MARK: - PVFeatureFlagsFetcher

@Test func testFetcherCaching() throws {
    let url = URL(string: "https://example.com/features.json")!
    let fetcher = PVFeatureFlagsFetcher(url: url, maxRetries: 1, cacheDuration: 3600)

    // Initially cache should not be valid (clean state for test)
    fetcher.clearCache()
    #expect(fetcher.isCacheValid() == false)
    #expect(fetcher.loadCached() == nil)

    // Save a config to cache and verify it's retrievable
    let config = try makeConfig()
    fetcher.saveToCache(config)
    #expect(fetcher.isCacheValid() == true)
    #expect(fetcher.loadCached()?.features["inAppFreeROMs"] != nil)

    // Clear cache
    fetcher.clearCache()
    #expect(fetcher.isCacheValid() == false)
    #expect(fetcher.loadCached() == nil)
}

@Test func testFetcherExpiredCacheIsInvalid() throws {
    let url = URL(string: "https://example.com/expired-test-features.json")!
    // Use 0-second cache duration to immediately expire
    let fetcher = PVFeatureFlagsFetcher(url: url, maxRetries: 0, cacheDuration: 0)
    fetcher.clearCache()

    let config = try makeConfig()
    fetcher.saveToCache(config)
    // With 0s duration the cache should be immediately invalid
    #expect(fetcher.isCacheValid() == false)

    fetcher.clearCache()
}

@Test func testFetcherSaveAndReloadCycle() throws {
    // Verify a full save-to-cache / load-from-cache cycle using a unique URL key
    let url = URL(string: "https://example.com/cycle-test-features.json")!
    let fetcher = PVFeatureFlagsFetcher(url: url, maxRetries: 0, cacheDuration: 3600)
    fetcher.clearCache()

    let config = try makeConfig()
    fetcher.saveToCache(config)

    let loaded = fetcher.loadCached()
    #expect(loaded != nil)
    #expect(loaded?.features["inAppFreeROMs"]?.enabled == true)
    #expect(loaded?.features["romPathMigrator"]?.enabled == true)

    fetcher.clearCache()
}

// MARK: - PVFeatureFlagsManager (Combine-dependent)

#if canImport(Combine)
@MainActor @Test func testManagerComputedProperties() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    #expect(manager.inAppFreeROMs == true)
    #expect(manager.romPathMigrator == true)
    #expect(manager.cheatsUseSwiftUI == false)
    #expect(manager.advancedSkinFeatures == false)
    #expect(manager.contentlessCores == false)
}

@MainActor @Test func testManagerIsEnabledByString() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    #expect(manager.isEnabled("inAppFreeROMs") == true)
    #expect(manager.isEnabled("cheatsUseSwiftUI") == false)
    #expect(manager.isEnabled("unknownFeature") == false)
}

@MainActor @Test func testManagerDebugOverrides() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    flags.clearDebugOverrides()
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    // cheatsUseSwiftUI is false in config
    #expect(manager.cheatsUseSwiftUI == false)

    manager.setDebugOverride(for: .cheatsUseSwiftUI, enabled: true)
    #expect(manager.cheatsUseSwiftUI == true)

    manager.clearDebugOverrides()
    #expect(manager.cheatsUseSwiftUI == false)
}

@MainActor @Test func testManagerLoadFromCachedConfig() throws {
    // Simulate loading from a pre-cached config (avoids URLSession file:// on Linux)
    let config = try makeConfig()
    let cacheURL = URL(string: "https://example.com/manager-cached-features.json")!
    let fetcher = PVFeatureFlagsFetcher(url: cacheURL, maxRetries: 0, cacheDuration: 3600)
    fetcher.clearCache()
    fetcher.saveToCache(config)

    let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    // Initially no config loaded
    #expect(manager.inAppFreeROMs == false)

    // Inject config via debug API (simulating what loadRemoteConfiguration would do after cache hit)
    manager.setDebugConfiguration(features: config.features)
    #expect(manager.inAppFreeROMs == true)
    #expect(manager.romPathMigrator == true)

    fetcher.clearCache()
}

@MainActor @Test func testManagerLoadRemoteFromValidCache() async throws {
    // Pre-seed the cache via a temporary fetcher, then verify the manager hits it
    let cacheURL = URL(string: "https://example.com/manager-valid-cache-hit.json")!
    let config = try makeConfig()

    let seedFetcher = PVFeatureFlagsFetcher(url: cacheURL, maxRetries: 0, cacheDuration: 3600)
    seedFetcher.clearCache()
    seedFetcher.saveToCache(config)

    let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)
    manager.configureRemote(url: cacheURL, cacheDuration: 3600, maxRetries: 0)

    // Cache is valid — no network call is made; config should be applied from cache
    try await manager.loadRemoteConfiguration()

    #expect(manager.inAppFreeROMs == true)
    #expect(manager.romPathMigrator == true)

    seedFetcher.clearCache()
}

@MainActor @Test func testManagerLoadRemoteStaleCacheFallback() async throws {
    // Use a file:// URL that doesn't exist so the remote fetch fails immediately
    let failURL = URL(string: "file:///nonexistent/stale-cache-fallback-test.json")!
    let config = try makeConfig()

    // Pre-seed cache with 0-duration (immediately stale)
    let seedFetcher = PVFeatureFlagsFetcher(url: failURL, maxRetries: 0, cacheDuration: 0)
    seedFetcher.clearCache()
    seedFetcher.saveToCache(config)
    #expect(seedFetcher.isCacheValid() == false, "Cache should be stale immediately with 0-duration")

    let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)
    manager.configureRemote(url: failURL, cacheDuration: 0, maxRetries: 0)

    // Stale cache → remote fails → falls back to stale cache data
    try await manager.loadRemoteConfiguration()

    #expect(manager.inAppFreeROMs == true)

    seedFetcher.clearCache()
}

@MainActor @Test func testManagerLoadRemoteBundledFallback() async throws {
    // Use a file:// URL that doesn't exist so the remote fetch fails
    let failURL = URL(string: "file:///nonexistent/bundled-fallback-test.json")!

    // Ensure no cache for this URL
    let tempFetcher = PVFeatureFlagsFetcher(url: failURL, maxRetries: 0, cacheDuration: 3600)
    tempFetcher.clearCache()

    let flags = PVFeatureFlags(appType: .standard, buildNumber: "200", appVersion: "3.0.5")
    let manager = PVFeatureFlagsManager(featureFlags: flags)
    manager.configureRemote(url: failURL, cacheDuration: 3600, maxRetries: 0)

    // No cache, remote fails → falls back to bundled features.json
    try await manager.loadRemoteConfiguration()

    // Bundled config should define inAppFreeROMs
    #expect(flags.configuration?.features["inAppFreeROMs"] != nil)
}

@MainActor @Test func testManagerNotConfiguredThrows() async {
    let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    await #expect(throws: PVFeatureFlagsFetcherError.self) {
        try await manager.loadRemoteConfiguration()
    }
}

@MainActor @Test func testManagerGetAllFeatureFlags() throws {
    let config = try makeConfig()
    let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
    let manager = PVFeatureFlagsManager(featureFlags: flags)

    let allFlags = manager.getAllFeatureFlags()
    #expect(allFlags.count == PVFeature.allCases.count)

    let inAppROMs = allFlags.first { $0.key == "inAppFreeROMs" }
    #expect(inAppROMs?.enabled == true)
}
#endif

// MARK: - Example SwiftUI usage (compile-only, not executed)

#if false
import SwiftUI

struct ExampleView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some View {
        VStack {
            if featureFlags.inAppFreeROMs {
                Text("Free ROMs feature is enabled!")
            }
            if featureFlags.cheatsUseSwiftUI {
                Text("SwiftUI cheats enabled!")
            }
        }
        .task {
            featureFlags.configureRemote(url: URL(string: "https://example.com/features.json")!)
            try? await featureFlags.loadRemoteConfiguration()
        }
    }
}

struct EnvironmentExampleView: View {
    @Environment(\.featureFlags) var featureFlags

    var body: some View {
        if featureFlags.inAppFreeROMs {
            Text("Free ROMs feature is enabled!")
        }
    }
}
#endif
