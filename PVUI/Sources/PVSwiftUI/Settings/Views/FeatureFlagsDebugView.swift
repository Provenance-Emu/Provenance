//
//  FeatureFlagsDebugView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/3/25.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import Reachability
import PVThemes
import PVSettings
import Combine
import PVUIBase
import PVUIKit
import RxRealm
import RxSwift
import RealmSwift
import Perception
import PVFeatureFlags
import Defaults

struct FeatureFlagsDebugView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared
    @State private var flags: [(key: String, flag: FeatureFlag, enabled: Bool)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            LoadingSection(isLoading: isLoading, flags: flags)
            FeatureFlagsSection(flags: flags, featureFlags: featureFlags)
            UserDefaultsSection()
            ConfigurationSection()
            DebugControlsSection(featureFlags: featureFlags, flags: $flags, isLoading: $isLoading, errorMessage: $errorMessage)
        }
        .navigationTitle("Feature Flags Debug")
        .task {
            await loadInitialConfiguration()
        }
        .uiKitAlert(
            "Error",
            message: errorMessage ?? "",
            isPresented: .constant(errorMessage != nil),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "OK", style: .default) { _ in
                print("OK tapped")
                errorMessage = nil
            }
        }
    }

    @MainActor
    private func loadInitialConfiguration() async {
        isLoading = true

        do {
            // First try to refresh from remote
            try await loadDefaultConfiguration()
            flags = featureFlags.getAllFeatureFlags()
            print("Initial flags loaded: \(flags)")
        } catch {
            errorMessage = "Failed to load remote configuration: \(error.localizedDescription)"
            print("Error loading remote configuration: \(error)")

            // If remote fails, try to refresh from current state
            flags = featureFlags.getAllFeatureFlags()
        }

        isLoading = false
    }

    @MainActor
    private func loadDefaultConfiguration() async throws {
        try await PVFeatureFlagsManager.shared.loadConfiguration(
            from: URL(string: "https://data.provenance-emu.com/features/features.json")!
        )
    }
}

private struct LoadingSection: View {
    let isLoading: Bool
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]

    var body: some View {
        if isLoading {
            Section {
                ProgressView("Loading configuration...")
            }
        }
    }
}

private struct FeatureFlagsSection: View {
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @ObservedObject var featureFlags: PVFeatureFlagsManager

    var body: some View {
        Section(header: Text("Feature Flags Status")) {
            if flags.isEmpty {
                Text("No feature flags found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(flags, id: \.key) { flag in
                    FeatureFlagRow(flag: flag, featureFlags: featureFlags)
                }
            }
        }
    }
}

private struct FeatureFlagRow: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    @State private var isEnabled: Bool

    init(flag: (key: String, flag: FeatureFlag, enabled: Bool), featureFlags: PVFeatureFlagsManager) {
        self.flag = flag
        self.featureFlags = featureFlags
        // Initialize state with current value
        if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
            _isEnabled = State(initialValue: featureFlags.debugOverrides[feature] ?? flag.enabled)
        } else {
            _isEnabled = State(initialValue: flag.enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                FeatureFlagInfo(flag: flag)
                Spacer()
                FeatureFlagStatus(flag: flag, featureFlags: featureFlags, isEnabled: isEnabled)
                #if os(tvOS)
                Button(action: {
                    if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                        isEnabled.toggle()
                        featureFlags.setDebugOverride(feature: feature, enabled: isEnabled)
                    }
                }) {
                    Text(isEnabled ? "On" : "Off")
                        .foregroundColor(isEnabled ? .green : .red)
                }
                #else
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                            isEnabled = newValue
                            featureFlags.setDebugOverride(feature: feature, enabled: newValue)
                        }
                    }
                ))
                #endif
            }
            FeatureFlagDetails(flag: flag.flag)
        }
        .padding(.vertical, 4)
        .onChange(of: featureFlags.debugOverrides) { _ in
            // Update state when debug overrides change
            if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                isEnabled = featureFlags.debugOverrides[feature] ?? flag.enabled
            }
        }
    }
}

private struct FeatureFlagInfo: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)

    var body: some View {
        VStack(alignment: .leading) {
            Text(flag.key)
                .font(.headline)
            if let description = flag.flag.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct FeatureFlagStatus: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .trailing) {
            // Show base configuration state
            Text("Base Config: \(flag.flag.enabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(flag.flag.enabled ? .green : .red)

            // Show effective state
            Text("Effective: \(isEnabled ? "On" : "Off")")
                .font(.caption)
                .foregroundColor(isEnabled ? .green : .red)

            // Show debug override if present
            if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key),
               let override = featureFlags.debugOverrides[feature] {
                Text("Override: \(override ? "On" : "Off")")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // Show restrictions if any
            let restrictions = featureFlags.getFeatureRestrictions(flag.key)
            if !restrictions.isEmpty {
                ForEach(restrictions, id: \.self) { restriction in
                    Text(restriction)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

private struct FeatureFlagDetails: View {
    let flag: FeatureFlag

    var body: some View {
        Group {
            if let minVersion = flag.minVersion {
                Text("Min Version: \(minVersion)")
            }
            if let minBuild = flag.minBuildNumber {
                Text("Min Build: \(minBuild)")
            }
            if let allowedTypes = flag.allowedAppTypes {
                Text("Allowed Types: \(allowedTypes.joined(separator: ", "))")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

private struct ConfigurationSection: View {
    var body: some View {
        Section(header: Text("Current Configuration")) {
            Text("App Type: \(PVFeatureFlags.getCurrentAppType().rawValue)")
            Text("App Version: \(PVFeatureFlags.getCurrentAppVersion())")
            if let buildNumber = PVFeatureFlags.getCurrentBuildNumber() {
                Text("Build Number: \(buildNumber)")
            }
            Text("Remote URL: https://data.provenance-emu.com/features/features.json")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct DebugControlsSection: View {
    let featureFlags: PVFeatureFlagsManager
    @Binding var flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        Section(header: Text("Debug Controls")) {
            Button("Clear All Overrides") {
                featureFlags.clearDebugOverrides()
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Refresh Flags") {
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Load Test Configuration") {
                loadTestConfiguration()
                flags = featureFlags.getAllFeatureFlags()
            }

            Button("Reset to Default") {
                Task {
                    do {
                        // Reset feature flags to default
                        try await loadDefaultConfiguration()
                        flags = featureFlags.getAllFeatureFlags()

                        // Reset unlock status
                        showFeatureFlagsDebug = false

                        // Reset all user defaults to their default values
                        Defaults.Keys.useAppGroups.reset()
                        Defaults.Keys.unsupportedCores.reset()
                        Defaults.Keys.iCloudSync.reset()
                    } catch {
                        errorMessage = "Failed to load default configuration: \(error.localizedDescription)"
                    }
                }
            }
            .foregroundColor(.red) // Make it stand out as a destructive action
        }
    }

    @MainActor
    private func loadTestConfiguration() {
        let testFeatures: [String: FeatureFlag] = [
            "inAppFreeROMs": FeatureFlag(
                enabled: true,
                minVersion: "1.0.0",
                minBuildNumber: "100",
                allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
                description: "Test configuration - enabled for all builds"
            ),
            "romPathMigrator": FeatureFlag(
                enabled: true,
                minVersion: "1.0.0",
                minBuildNumber: "100",
                allowedAppTypes: ["standard", "lite", "standard.appstore", "lite.appstore"],
                description: "Test configuration - enabled for all builds"
            )
        ]

        featureFlags.setDebugConfiguration(features: testFeatures)
    }

    @MainActor
    private func loadDefaultConfiguration() async throws {
        try await PVFeatureFlagsManager.shared.loadConfiguration(
            from: URL(string: "https://data.provenance-emu.com/features/features.json")!
        )
    }
}

private struct UserDefaultsSection: View {
    @Default(.useAppGroups) var useAppGroups
    @Default(.unsupportedCores) var unsupportedCores
    @Default(.iCloudSync) var iCloudSync

    var body: some View {
        Section(header: Text("User Defaults")) {
            UserDefaultToggle(
                title: "useAppGroups",
                subtitle: "Use App Groups for shared storage",
                isOn: $useAppGroups
            )

            UserDefaultToggle(
                title: "unsupportedCores",
                subtitle: "Enable experimental and unsupported cores",
                isOn: $unsupportedCores
            )

            UserDefaultToggle(
                title: "iCloudSync",
                subtitle: "Sync save states and settings with iCloud",
                isOn: $iCloudSync
            )
        }
    }
}

private struct UserDefaultToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
            }
        }
        .padding(.vertical, 4)
    }
}
