import Testing
import Foundation
#if canImport(Combine)
import Combine
#endif
@testable import PVFeatureFlags

// MARK: - Test Fixtures

private let sampleJSON = """
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
        "contentlessCores": {
            "enabled": false,
            "minVersion": "3.0.5",
            "allowedAppTypes": ["standard", "lite", "standard.appstore", "lite.appstore"],
            "description": "Enables contentless cores."
        },
        "netplayEnabled": {
            "enabled": false,
            "minVersion": "3.1.0",
            "allowedAppTypes": ["standard", "lite", "standard.appstore", "lite.appstore"],
            "description": "Enables native netplay UI."
        },
        "tapToRemapUI": {
            "enabled": false,
            "description": "Tap-to-remap UX in button remapping settings."
        }
    }
}
"""

private func makeConfig() throws -> FeatureFlagsConfiguration {
    let data = sampleJSON.data(using: .utf8)!
    return try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
}

// MARK: - Test Suite
//
// Tests are serialized to prevent race conditions on shared UserDefaults state
// (debug overrides are stored in UserDefaults.standard; parallel tests would
// interfere with each other when one test mutates overrides while another reads them).

@Suite(.serialized)
struct PVFeatureFlagsTests {

    // MARK: - JSON Parsing

    @Test func testFeatureFlagParsing() throws {
        let config = try makeConfig()

        #expect(config.features["inAppFreeROMs"]?.enabled == true)
        #expect(config.features["inAppFreeROMs"]?.minVersion == "1.0.0")
        #expect(config.features["inAppFreeROMs"]?.minBuildNumber == "100")
        #expect(config.features["inAppFreeROMs"]?.allowedAppTypes?.contains("standard") == true)
        #expect(config.features["romPathMigrator"]?.enabled == true)
        #expect(config.features["contentlessCores"]?.enabled == false)
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

    // MARK: - PVFeatureFlags (isEnabled — no actor isolation required)

    /// isEnabled is synchronous and nonisolated — no @MainActor needed.
    @Test func testIsEnabledByEnum() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        #expect(flags.isEnabled(.inAppFreeROMs) == true)
        #expect(flags.isEnabled(.romPathMigrator) == true)
        #expect(flags.isEnabled(.contentlessCores) == false)
    }

    @Test func testIsEnabledByString() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        #expect(flags.isEnabled("inAppFreeROMs") == true)
        #expect(flags.isEnabled("romPathMigrator") == true)
        #expect(flags.isEnabled("contentlessCores") == false)
        #expect(flags.isEnabled("unknownFeature") == false)
    }

    /// Subscript convenience: flags[.feature]
    @Test func testSubscriptAccess() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        #expect(flags[.inAppFreeROMs] == true)
        #expect(flags[.contentlessCores] == false)
    }

    @Test func testAppTypeRestriction() throws {
        let config = try makeConfig()

        // netplayEnabled allows standard, lite, standard.appstore, lite.appstore — all types allowed
        // but enabled: false in JSON, so it should still be false
        let appStoreFlags = PVFeatureFlags(
            configuration: config, appType: .standardAppStore, buildNumber: "101", appVersion: "3.1.0"
        )
        appStoreFlags.clearDebugOverrides()
        #expect(appStoreFlags.isEnabled(.netplayEnabled) == false)

        // contentlessCores allows all 4 app types but enabled: false in JSON
        let liteFlags = PVFeatureFlags(
            configuration: config, appType: .lite, buildNumber: "101", appVersion: "3.1.0"
        )
        liteFlags.clearDebugOverrides()
        #expect(liteFlags.isEnabled(.contentlessCores) == false)
    }

    @Test func testVersionRestriction() throws {
        let config = try makeConfig()

        // version below minVersion — netplayEnabled requires 3.1.0
        let oldFlags = PVFeatureFlags(
            configuration: config, appType: .standard, buildNumber: "101", appVersion: "2.0.0"
        )
        oldFlags.clearDebugOverrides()
        #expect(oldFlags.isEnabled(.netplayEnabled) == false)
    }

    @Test func testBuildNumberRestriction() throws {
        let config = try makeConfig()

        // build number below minimum for inAppFreeROMs (minBuildNumber: "100")
        let lowBuildFlags = PVFeatureFlags(
            configuration: config, appType: .standard, buildNumber: "50", appVersion: "2.0.0"
        )
        lowBuildFlags.clearDebugOverrides()
        #expect(lowBuildFlags.isEnabled(.inAppFreeROMs) == false)
    }

    // MARK: - PVPlatform

    @Test func testPVPlatformRawValues() {
        #expect(PVPlatform.ios.rawValue == "ios")
        #expect(PVPlatform.tvos.rawValue == "tvos")
        #expect(PVPlatform.macos.rawValue == "macos")
        #expect(PVPlatform.visionos.rawValue == "visionos")
    }

    @Test func testPVPlatformCurrentIsNonNil() {
        // current must resolve to one of the four known platforms
        let platform = PVPlatform.current
        #expect(PVPlatform.allCases.contains(platform))
    }

    // MARK: - allowedPlatforms

    @Test func testAllowedPlatformsNilMeansAllPlatformsAllowed() throws {
        // A flag with no allowedPlatforms restriction should be enabled on every platform.
        let data = """
        {"features": {"romPathMigrator": {"enabled": true, "description": "No platform restriction"}}}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "1", appVersion: "1.0.0")
        flags.clearDebugOverrides()
        #expect(flags.isEnabled(.romPathMigrator) == true)
    }

    @Test func testAllowedPlatformsCurrentPlatformAllowed() throws {
        // A flag that lists the current platform should be allowed.
        let currentPlatform = PVPlatform.current.rawValue
        let json = """
        {"features": {"romPathMigrator": {"enabled": true, "allowedPlatforms": ["\(currentPlatform)"], "description": "Current platform allowed"}}}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "1", appVersion: "1.0.0")
        flags.clearDebugOverrides()
        #expect(flags.isEnabled(.romPathMigrator) == true)
    }

    @Test func testAllowedPlatformsOtherPlatformBlocked() throws {
        // A flag whose allowedPlatforms does NOT include the current platform must be disabled.
        // Pick a platform that is NOT the current one.
        let nonCurrentPlatform = PVPlatform.allCases.first { $0 != PVPlatform.current }!.rawValue
        let json = """
        {"features": {"romPathMigrator": {"enabled": true, "allowedPlatforms": ["\(nonCurrentPlatform)"], "description": "Other platform only"}}}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "1", appVersion: "1.0.0")
        flags.clearDebugOverrides()
        #expect(flags.isEnabled(.romPathMigrator) == false)
    }

    @Test func testAllowedPlatformsAppearsInRestrictions() throws {
        // getFeatureRestrictions should report a platform restriction when the current platform is excluded.
        let nonCurrentPlatform = PVPlatform.allCases.first { $0 != PVPlatform.current }!.rawValue
        let json = """
        {"features": {"romPathMigrator": {"enabled": true, "allowedPlatforms": ["\(nonCurrentPlatform)"], "description": "Other platform only"}}}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "1", appVersion: "1.0.0")
        flags.clearDebugOverrides()
        let restrictions = flags.getFeatureRestrictions("romPathMigrator")
        #expect(restrictions.contains { $0.contains("not allowed") })
    }

    @Test func testDebugOverrideBypassesPlatformRestriction() throws {
        // A platform-gated flag that is blocked on the current platform can still be
        // force-enabled via a debug override — the override takes precedence over all
        // other restrictions (platform, app-type, version).
        let nonCurrentPlatform = PVPlatform.allCases.first { $0 != PVPlatform.current }!.rawValue
        let json = """
        {"features": {"romPathMigrator": {"enabled": true, "allowedPlatforms": ["\(nonCurrentPlatform)"], "description": "Other platform only"}}}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "1", appVersion: "1.0.0")
        flags.clearDebugOverrides()

        // Without override: blocked by platform gate
        #expect(flags.isEnabled(.romPathMigrator) == false)

        // Debug override enabled: bypasses platform gate
        flags.setDebugOverride(for: .romPathMigrator, enabled: true)
        #expect(flags.isEnabled(.romPathMigrator) == true)

        // Clear the override: platform gate re-applies
        flags.setDebugOverride(for: .romPathMigrator, enabled: nil)
        #expect(flags.isEnabled(.romPathMigrator) == false)

        flags.clearDebugOverrides()
    }

    @Test func testLiteAppTypeIsBlocked() throws {
        let config = try makeConfig()
        // inAppFreeROMs only allows "standard" and "standard.appstore"
        let liteFlags = PVFeatureFlags(
            configuration: config, appType: .lite, buildNumber: "101", appVersion: "1.1.0"
        )
        liteFlags.clearDebugOverrides()
        #expect(liteFlags.isEnabled(.inAppFreeROMs) == false)
    }

    // MARK: - Debug Overrides

    @Test func testDebugOverrides() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()

        // contentlessCores is disabled in config; override to enable
        flags.setDebugOverride(for: .contentlessCores, enabled: true)
        #expect(flags.isEnabled(.contentlessCores) == true)

        // nil clears the per-feature override — should revert to config value (false)
        flags.setDebugOverride(for: .contentlessCores, enabled: nil)
        #expect(flags.isEnabled(.contentlessCores) == false)

        // Clear all overrides
        flags.clearDebugOverrides()
        #expect(flags.isEnabled(.contentlessCores) == false)
    }

    // MARK: - Nonisolated reads from a background actor

    @Test func testIsEnabledFromBackgroundActor() async throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()

        // Detached task runs on a background thread (not @MainActor).
        // isEnabled must be callable without await.
        let result = await Task.detached {
            // No await needed — isEnabled is synchronous
            flags.isEnabled(.inAppFreeROMs)
        }.value

        #expect(result == true)
    }

    @Test func testSubscriptFromBackgroundActor() async throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()

        let result = await Task.detached {
            flags[.romPathMigrator]
        }.value

        #expect(result == true)
    }

    // MARK: - Bundled Configuration

    @Test func testBundledConfigurationLoads() {
        let flags = PVFeatureFlags(appType: .standard, buildNumber: "200", appVersion: "3.0.5")
        flags.clearDebugOverrides()
        let loaded = flags.loadBundledConfiguration()
        #expect(loaded == true)
        #expect(flags.configuration?.features["inAppFreeROMs"] != nil)
    }

    // MARK: - Local File Configuration Loading

    @Test func testLoadConfigurationFromJSON() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        flags.setConfiguration(config)
        #expect(flags.isEnabled(.inAppFreeROMs) == true)
        #expect(flags.isEnabled(.romPathMigrator) == true)
    }

    // MARK: - PVFeatureFlagsFetcher

    @Test func testFetcherCaching() throws {
        let url = URL(string: "https://example.com/features.json")!
        let fetcher = PVFeatureFlagsFetcher(url: url, maxRetries: 1, cacheDuration: 3600)

        fetcher.clearCache()
        #expect(fetcher.isCacheValid() == false)
        #expect(fetcher.loadCached() == nil)

        let config = try makeConfig()
        fetcher.saveToCache(config)
        #expect(fetcher.isCacheValid() == true)
        #expect(fetcher.loadCached()?.features["inAppFreeROMs"] != nil)

        fetcher.clearCache()
        #expect(fetcher.isCacheValid() == false)
        #expect(fetcher.loadCached() == nil)
    }

    @Test func testFetcherExpiredCacheIsInvalid() throws {
        let url = URL(string: "https://example.com/expired-test-features.json")!
        let fetcher = PVFeatureFlagsFetcher(url: url, maxRetries: 0, cacheDuration: 0)
        fetcher.clearCache()

        let config = try makeConfig()
        fetcher.saveToCache(config)
        #expect(fetcher.isCacheValid() == false)

        fetcher.clearCache()
    }

    @Test func testFetcherSaveAndReloadCycle() throws {
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
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        #expect(manager.inAppFreeROMs == true)
        #expect(manager.romPathMigrator == true)
        #expect(manager.contentlessCores == false)
    }

    @MainActor @Test func testManagerIsEnabledByString() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        #expect(manager.isEnabled("inAppFreeROMs") == true)
        #expect(manager.isEnabled("contentlessCores") == false)
        #expect(manager.isEnabled("unknownFeature") == false)
    }

    @MainActor @Test func testManagerDebugOverrides() async throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        #expect(manager.tapToRemapUI == false)

        manager.setDebugOverride(for: .tapToRemapUI, enabled: true)
        // stateDidChange fires and manager updates via Combine on main queue;
        // yield to allow the Combine pipeline to propagate.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(manager.tapToRemapUI == true)

        manager.clearDebugOverrides()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(manager.tapToRemapUI == false)
    }

    @MainActor @Test func testManagerLoadFromCachedConfig() throws {
        let config = try makeConfig()
        let cacheURL = URL(string: "https://example.com/manager-cached-features.json")!
        let fetcher = PVFeatureFlagsFetcher(url: cacheURL, maxRetries: 0, cacheDuration: 3600)
        fetcher.clearCache()
        fetcher.saveToCache(config)

        let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        // PVFeatureFlags.init() eagerly loads the bundled features.json, so
        // inAppFreeROMs is already enabled for the "standard" app type (minBuild 100,
        // minVersion 1.0.0 satisfied). netplayEnabled is enabled: false in both
        // bundled config and sampleJSON, so it stays false either way.
        #expect(manager.inAppFreeROMs == true)   // enabled in bundled features.json

        manager.setDebugConfiguration(features: config.features)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        #expect(manager.inAppFreeROMs == true)
        #expect(manager.romPathMigrator == true)
        #expect(manager.contentlessCores == false)

        fetcher.clearCache()
    }

    @MainActor @Test func testManagerLoadRemoteFromValidCache() async throws {
        let cacheURL = URL(string: "https://example.com/manager-valid-cache-hit.json")!
        let config = try makeConfig()

        let seedFetcher = PVFeatureFlagsFetcher(url: cacheURL, maxRetries: 0, cacheDuration: 3600)
        seedFetcher.clearCache()
        seedFetcher.saveToCache(config)

        let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)
        manager.configureRemote(url: cacheURL, cacheDuration: 3600, maxRetries: 0)

        try await manager.loadRemoteConfiguration()

        #expect(manager.inAppFreeROMs == true)
        #expect(manager.romPathMigrator == true)

        seedFetcher.clearCache()
    }

    @MainActor @Test func testManagerLoadRemoteStaleCacheFallback() async throws {
        let failURL = URL(string: "file:///nonexistent/stale-cache-fallback-test.json")!
        let config = try makeConfig()

        let seedFetcher = PVFeatureFlagsFetcher(url: failURL, maxRetries: 0, cacheDuration: 0)
        seedFetcher.clearCache()
        seedFetcher.saveToCache(config)
        #expect(seedFetcher.isCacheValid() == false, "Cache should be stale immediately with 0-duration")

        let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)
        manager.configureRemote(url: failURL, cacheDuration: 0, maxRetries: 0)

        try await manager.loadRemoteConfiguration()

        #expect(manager.inAppFreeROMs == true)

        seedFetcher.clearCache()
    }

    @MainActor @Test func testManagerLoadRemoteBundledFallback() async throws {
        let failURL = URL(string: "file:///nonexistent/bundled-fallback-test.json")!

        let tempFetcher = PVFeatureFlagsFetcher(url: failURL, maxRetries: 0, cacheDuration: 3600)
        tempFetcher.clearCache()

        let flags = PVFeatureFlags(appType: .standard, buildNumber: "200", appVersion: "3.0.5")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)
        manager.configureRemote(url: failURL, cacheDuration: 3600, maxRetries: 0)

        try await manager.loadRemoteConfiguration()

        #expect(flags.configuration?.features["inAppFreeROMs"] != nil)
    }

    @MainActor @Test func testManagerNotConfiguredThrows() async {
        let flags = PVFeatureFlags(appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        await #expect(throws: PVFeatureFlagsFetcherError.self) {
            try await manager.loadRemoteConfiguration()
        }
    }

    @MainActor @Test func testManagerGetAllFeatureFlags() throws {
        let config = try makeConfig()
        let flags = PVFeatureFlags(configuration: config, appType: .standard, buildNumber: "101", appVersion: "1.1.0")
        flags.clearDebugOverrides()
        let manager = PVFeatureFlagsManager(featureFlags: flags)

        let allFlags = manager.getAllFeatureFlags()
        #expect(allFlags.count == PVFeature.allCases.count)

        let inAppROMs = allFlags.first { $0.key == "inAppFreeROMs" }
        #expect(inAppROMs?.enabled == true)
    }
    #endif
}

// MARK: - Example SwiftUI usage (compile-only, not executed)

#if false
import SwiftUI

struct ExampleView: View {
    // Use @ObservedObject (not @StateObject) for singletons — the view does not own
    // the object's lifetime. @StateObject is only correct for locally-created instances.
    @ObservedObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some View {
        VStack {
            if featureFlags.inAppFreeROMs {
                Text("Free ROMs feature is enabled!")
            }
            if featureFlags.contentlessCores {
                Text("Contentless cores enabled!")
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
