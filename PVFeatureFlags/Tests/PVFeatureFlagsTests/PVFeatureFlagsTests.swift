import Testing
import Foundation
import SwiftUI
@testable import PVFeatureFlags

let sampleJSON = """
{
    "features": {
        "inAppFreeROMs": {
            "enabled": true,
            "minVersion": "1.0.0",
            "minBuildNumber": "100",
            "allowedAppTypes": ["standard", "standard.appstore"],
            "description": "Allows downloading free ROMs directly in the app"
        }
    }
}
"""

@Test func testFeatureFlagParsing() throws {
    let data = sampleJSON.data(using: .utf8)!
    let config = try JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)

    #expect(config.features["inAppFreeROMs"]?.enabled == true)
    #expect(config.features["inAppFreeROMs"]?.minVersion == "1.0.0")
    #expect(config.features["inAppFreeROMs"]?.minBuildNumber == "100")
    #expect(config.features["inAppFreeROMs"]?.allowedAppTypes?.contains("standard") == true)
}

@Test func testAppTypeChecks() throws {
    let standardType = PVAppType.standard
    #expect(standardType.isAppStore == false)
    #expect(standardType.isLite == false)

    let liteAppStoreType = PVAppType.liteAppStore
    #expect(liteAppStoreType.isAppStore == true)
    #expect(liteAppStoreType.isLite == true)
}

@Test func testFeatureFlag() async throws {
    await MainActor.run {
        let data = sampleJSON.data(using: .utf8)!
        let config = try! JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)

        // Create feature flags with pre-loaded configuration
        let featureFlags = PVFeatureFlags(
            configuration: config,
            appType: .standard,
            buildNumber: "101",
            appVersion: "1.1.0"
        )

        #expect(featureFlags.isEnabled("inAppFreeROMs") == true)

        // Test with lite version (should be disabled)
        let liteFeatureFlags = PVFeatureFlags(
            configuration: config,
            appType: .lite,
            buildNumber: "101",
            appVersion: "1.1.0"
        )

        #expect(liteFeatureFlags.isEnabled("inAppFreeROMs") == false)
    }
}

@Test func testFeatureFlagsManager() async throws {
    await MainActor.run {
        let data = sampleJSON.data(using: .utf8)!
        let config = try! JSONDecoder().decode(FeatureFlagsConfiguration.self, from: data)

        let featureFlags = PVFeatureFlags(
            configuration: config,
            appType: .standard,
            buildNumber: "101",
            appVersion: "1.1.0"
        )
        let manager = PVFeatureFlagsManager(featureFlags: featureFlags)

        #expect(manager.inAppFreeROMs == true)
        #expect(manager.isEnabled("inAppFreeROMs") == true)
    }
}

// Example of how to use in SwiftUI views (add as documentation)
#if false
struct ExampleView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared
    // Or if using as an observed object passed from parent:
    // @ObservedObject var featureFlags: PVFeatureFlagsManager

    var body: some View {
        if featureFlags.inAppFreeROMs {
            Text("Free ROMs feature is enabled!")
        }
    }
}

// Alternative using environment
struct EnvironmentExampleView: View {
    @Environment(\.featureFlags) var featureFlags

    var body: some View {
        if featureFlags.inAppFreeROMs {
            Text("Free ROMs feature is enabled!")
        }
    }
}

struct ExampleApp: App {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(featureFlags)
                .task {
                    try? await featureFlags.loadConfiguration(
                        from: URL(string: "https://your-domain.com/features.json")!
                    )
                }
        }
    }
}
#endif
