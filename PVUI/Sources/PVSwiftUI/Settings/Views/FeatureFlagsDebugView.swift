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
import PVLibrary
import AudioToolbox

struct FeatureFlagsDebugView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared
    @State private var flags: [(key: String, flag: FeatureFlag, enabled: Bool)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0
    
    private func refreshFlagsList() {
        flags = featureFlags.getAllFeatureFlags() // Ensure this is called after overrides
    }

    var body: some View {
        ZStack {
            // RetroWave background
            RetroTheme.retroBackground
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Title with retrowave styling
                    Text("FEATURE FLAGS")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(RetroTheme.retroPink)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
                    
                    // Content sections
                    LoadingSection(isLoading: isLoading, flags: flags)
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                    
                    FeatureFlagsSection(flags: flags, featureFlags: featureFlags, refreshAction: refreshFlagsList) // Pass refresh action
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                    
                    UserDefaultsSection()
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                    
                    ConfigurationSection()
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                    
                    DebugControlsSection(featureFlags: featureFlags, flags: $flags, isLoading: $isLoading, errorMessage: $errorMessage)
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Feature Flags Debug")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await loadInitialConfiguration()
            
            // Start animation for glow effect
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
            }
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
            flags = featureFlags.getAllFeatureFlags() // Correct: is a method call
            print("Initial flags loaded: \(flags)")
        } catch {
            errorMessage = "Failed to load remote configuration: \(error.localizedDescription)"
            print("Error loading remote configuration: \(error)")

            // If remote fails, try to refresh from current state
            flags = featureFlags.getAllFeatureFlags() // Correct: is a method call
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
            VStack(spacing: 12) {
                Text("LOADING CONFIGURATION")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                    .scaleEffect(1.5)
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

private struct FeatureFlagsSection: View {
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let refreshAction: () -> Void // Add refresh action closure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("FEATURE FLAGS STATUS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(RetroTheme.retroPurple)
                .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
                .padding(.horizontal)
            
            if flags.isEmpty {
                Text("NO FEATURE FLAGS FOUND")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(flags, id: \.key) { flag in
                        FeatureFlagRow(flag: flag, featureFlags: featureFlags, refreshAction: refreshAction) // Pass refresh action
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.6), RetroTheme.retroBlue.opacity(0.6)]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

private struct FeatureFlagRow: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let refreshAction: () -> Void
    @State private var isEnabled: Bool
    // Store the specific PVFeature enum case for convenience
    private var featureEnum: PVFeature? { PVFeature(rawValue: flag.key) }

    init(flag: (key: String, flag: FeatureFlag, enabled: Bool), featureFlags: PVFeatureFlagsManager, refreshAction: @escaping () -> Void) {
        self.flag = flag
        self.featureFlags = featureFlags
        self.refreshAction = refreshAction
        self._isEnabled = State(initialValue: flag.enabled) // Initialize from effective state
    }

    private var overrideStatusText: String {
        guard let feature = featureEnum else { return "Invalid Feature" }
        let currentOverrides = featureFlags.getCurrentDebugOverrides()
        if let overrideValue = currentOverrides[feature] {
            return overrideValue == true ? "Override: ON" : "Override: OFF"
        }
        return "Override: Default"
    }

    var body: some View {
#if os(tvOS)
        // tvOS: Keep the current button-based approach that works
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(flag.key)
                    .font(.headline)
                    .foregroundColor(RetroTheme.retroPink)
                Text(flag.flag.description ?? "Feature not defined in configuration")
                    .font(.caption)
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                Text("Effective: \(flag.enabled ? "ON" : "OFF")")
                    .font(.caption)
                    .foregroundColor(flag.enabled ? .green : .red)
                Text(overrideStatusText)
                    .font(.caption)
                    .foregroundColor(.gray)
                let restrictions = featureFlags.getFeatureRestrictions(flag.key)
                if !restrictions.isEmpty {
                    Text("Restrictions: \(restrictions.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(RetroTheme.retroPurple)
        }
        .onChange(of: isEnabled) { newValue in // React to local toggle changes
            guard let feature = featureEnum else { return }
            featureFlags.setDebugOverride(for: feature, enabled: newValue)
            refreshAction() // Refresh the main list to reflect changes
        }
#else
        // iOS: Use RetroWaveToggle for proper touch interaction
        VStack(alignment: .leading, spacing: 8) {
            // Feature info section
            VStack(alignment: .leading, spacing: 4) {
                Text(flag.key)
                    .font(.headline)
                    .foregroundColor(RetroTheme.retroPink)
                Text(flag.flag.description ?? "Feature not defined in configuration")
                    .font(.caption)
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                Text("Effective: \(flag.enabled ? "ON" : "OFF")")
                    .font(.caption)
                    .foregroundColor(flag.enabled ? .green : .red)
                Text(overrideStatusText)
                    .font(.caption)
                    .foregroundColor(.gray)
                let restrictions = featureFlags.getFeatureRestrictions(flag.key)
                if !restrictions.isEmpty {
                    Text("Restrictions: \(restrictions.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // RetroWave toggle
            RetroWaveToggle(isOn: $isEnabled, label: "Override")
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .onChange(of: isEnabled) { newValue in // React to local toggle changes
            guard let feature = featureEnum else { return }
            featureFlags.setDebugOverride(for: feature, enabled: newValue)
            refreshAction() // Refresh the main list to reflect changes
        }
#endif
    }
}

private struct FeatureFlagStatus: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    // This isEnabled is the effective enabled state passed in.
    // If this view needs to show override state, it should use getCurrentDebugOverrides as well.

    private var featureEnum: PVFeature? { PVFeature(rawValue: flag.key) }

    private var overrideDetailText: String {
        guard let feature = featureEnum else { return "Invalid Feature Key" }
        let currentOverrides = featureFlags.getCurrentDebugOverrides() // Corrected access
        if let specificOverride = currentOverrides[feature] {
            return specificOverride == true ? "Forced ON" : "Forced OFF"
        }
        return "Following Configuration"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Config Value: \(flag.flag.enabled ? "ON" : "OFF")")
            Text("Override: \(overrideDetailText)")
            Text("Effective Status: \(flag.enabled ? "ENABLED" : "DISABLED")")
                .foregroundColor(flag.enabled ? .green : .red)
        }
        .font(.footnote)
        .padding(.leading, 20)
    }
}

private struct ConfigurationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("CURRENT CONFIGURATION")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(RetroTheme.retroPurple)
                .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                // App type with icon
                HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
                    
                    Text("APP TYPE:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(PVFeatureFlags.getCurrentAppType().rawValue.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.6), radius: 2, x: 0, y: 0)
                }
                
                // App version with icon
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
                    
                    Text("APP VERSION:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(PVFeatureFlags.getCurrentAppVersion())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.6), radius: 2, x: 0, y: 0)
                }
                
                // Build number with icon (if available)
                if let buildNumber = PVFeatureFlags.getCurrentBuildNumber() {
                    HStack(spacing: 8) {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
                        
                        Text("BUILD NUMBER:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(buildNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(0.6), radius: 2, x: 0, y: 0)
                    }
                }
                
                // Remote URL with icon
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
                    
                    Text("REMOTE URL:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("data.provenance-emu.com")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

private struct DebugControlsSection: View {
    let featureFlags: PVFeatureFlagsManager
    @Binding var flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var isReindexingSpotlight = false
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with retrowave styling
            Text("DEBUG CONTROLS")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(RetroTheme.retroPurple)
                .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 3, x: 0, y: 0)
                .padding(.bottom, 4)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Clear All Overrides button
                Button(action: {
                    featureFlags.clearDebugOverrides()
                    flags = featureFlags.getAllFeatureFlags() // Correct: is a method call
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                        Text("CLEAR ALL OVERRIDES")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Spotlight Re-indexing button
                Button(action: {
                    isReindexingSpotlight = true
                    SpotlightHelper.shared.forceReindexAll {
                        isReindexingSpotlight = false
                    }
                }) {
                    HStack {
                        if isReindexingSpotlight {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                        }
                        Text(isReindexingSpotlight ? "REINDEXING SPOTLIGHT..." : "REINDEX SPOTLIGHT")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isReindexingSpotlight)
                
                // Refresh Flags button
                Button(action: {
                    flags = featureFlags.getAllFeatureFlags() // Correct: is a method call
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                        Text("REFRESH FLAGS")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(RetroTheme.retroPurple)
                    .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Load Test Configuration button
                Button(action: {
                    loadTestConfiguration()
                    flags = featureFlags.getAllFeatureFlags() // Correct: is a method call
                }) {
                    HStack {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 16))
                        Text("LOAD TEST CONFIG")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reset to Default button (destructive action)
                Button(action: {
                    Task {
                        do {
                            // Reset feature flags to default
                            try await loadDefaultConfiguration()
                            flags = featureFlags.getAllFeatureFlags() // Correct: is a method call

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
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                        Text("RESET TO DEFAULT")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPink.opacity(0.5)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .onAppear {
                // Start animation for glow effect
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.9
                }
            }
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

        featureFlags.setDebugConfiguration(features: testFeatures) // Correct: is a method call
        // The flags binding should update automatically if FeatureFlagsManager correctly publishes changes
        // or call refreshFlagsList() from parent if direct update is needed.
        // For now, assuming the call to getAllFeatureFlags in the Button action is sufficient for this debug view.
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

    #if os(tvOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User Defaults")
                .font(.headline)
                .foregroundColor(RetroTheme.retroPink)
                .padding(.bottom, 5)
            
            // User App Groups toggle
            UserDefaultRow(
                title: "useAppGroups",
                subtitle: "Use App Groups for shared storage",
                isOn: $useAppGroups
            )
            
            // Unsupported Cores toggle
            UserDefaultRow(
                title: "unsupportedCores",
                subtitle: "Enable experimental and unsupported cores",
                isOn: $unsupportedCores
            )
            
            // iCloud Sync toggle
            UserDefaultRow(
                title: "iCloudSync",
                subtitle: "Sync save states and settings with iCloud",
                isOn: $iCloudSync
            )
        }
        .padding()
        .background(RetroTheme.retroDarkBlue.opacity(0.3))
        .cornerRadius(8)
    }
    #else
    var body: some View {
        Section(header: Text("User Defaults")) {
            UserDefaultToggle(
                title: "useAppGroups",
                subtitle: "Use App Groups for shared storage",
                isOn: $useAppGroups
            )
            .focusableIfAvailable()

            UserDefaultToggle(
                title: "unsupportedCores",
                subtitle: "Enable experimental and unsupported cores",
                isOn: $unsupportedCores
            )
            .focusableIfAvailable()

            UserDefaultToggle(
                title: "iCloudSync",
                subtitle: "Sync save states and settings with iCloud",
                isOn: $iCloudSync
            )
            .focusableIfAvailable()
        }
    }
    #endif
}

// Standard toggle for iOS/macOS
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
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                    .focusableIfAvailable()
            }
        }
        .padding(.vertical, 4)
    }
}

// User Default row for tvOS that matches the style of FeatureFlagRow
private struct UserDefaultRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @State private var glowOpacity: Double = 0.6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Left side - title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Right side - ON/OFF button
                Button(action: {
                    isOn.toggle()
                    AudioServicesPlaySystemSound(1519)
                }) {
                    Text(isOn ? "ON" : "OFF")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isOn ? RetroTheme.retroBlue : RetroTheme.retroPink)
                        .shadow(color: isOn ? RetroTheme.retroBlue.opacity(glowOpacity) : RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }
}
