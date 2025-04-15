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
    
    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7
    @State private var scanlineOffset: CGFloat = 0

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
                    
                    FeatureFlagsSection(flags: flags, featureFlags: featureFlags)
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
                        FeatureFlagRow(flag: flag, featureFlags: featureFlags)
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
    @State private var isEnabled: Bool
    @State private var glowOpacity: Double = 0.6

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
        VStack(alignment: .leading, spacing: 6) {
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
                    Text(isEnabled ? "ON" : "OFF")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink)
                        .shadow(color: isEnabled ? RetroTheme.retroBlue.opacity(glowOpacity) : RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                #else
                // Custom toggle with retrowave styling
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key) {
                            isEnabled = newValue
                            featureFlags.setDebugOverride(feature: feature, enabled: newValue)
                        }
                    }
                ))
                .toggleStyle(RetroTheme.RetroToggleStyle())
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
        .onAppear {
            // Start animation for glow effect
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
    }
}

private struct FeatureFlagInfo: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)

    var body: some View {
        VStack(alignment: .leading) {
            Text(flag.key)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(RetroTheme.retroPurple)
                .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 2, x: 0, y: 0)
            if let description = flag.flag.description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
        }
    }
}

private struct FeatureFlagStatus: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Show base configuration state
            HStack(spacing: 4) {
                Text("BASE:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(flag.flag.enabled ? "ON" : "OFF")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(flag.flag.enabled ? RetroTheme.retroBlue : RetroTheme.retroPink)
                    .shadow(color: flag.flag.enabled ? RetroTheme.retroBlue.opacity(0.6) : RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
            }

            // Show effective state
            HStack(spacing: 4) {
                Text("ACTIVE:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(isEnabled ? "ON" : "OFF")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink)
                    .shadow(color: isEnabled ? RetroTheme.retroBlue.opacity(0.6) : RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
            }

            // Show debug override if present
            if let feature = PVFeatureFlags.PVFeature(rawValue: flag.key),
               let override = featureFlags.debugOverrides[feature] {
                HStack(spacing: 4) {
                    Text("OVERRIDE:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(override ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(override ? RetroTheme.retroPurple : RetroTheme.retroPink)
                        .shadow(color: override ? RetroTheme.retroPurple.opacity(0.6) : RetroTheme.retroPink.opacity(0.6), radius: 2, x: 0, y: 0)
                }
            }

            // Show restrictions if any
            let restrictions = featureFlags.getFeatureRestrictions(flag.key)
            if !restrictions.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(restrictions, id: \.self) { restriction in
                        Text(restriction)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 1, x: 0, y: 0)
                    }
                }
            }
        }
    }
}

private struct FeatureFlagDetails: View {
    let flag: FeatureFlag

    var body: some View {
        HStack(spacing: 8) {
            if let minVersion = flag.minVersion {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    
                    Text("v\(minVersion)+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            if let minBuild = flag.minBuildNumber {
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPurple.opacity(0.7))
                    
                    Text("#\(minBuild)+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            if let allowedTypes = flag.allowedAppTypes {
                HStack(spacing: 4) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 10))
                        .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                    
                    Text(allowedTypes.joined(separator: ", "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
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
                    flags = featureFlags.getAllFeatureFlags()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
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
                
                // Refresh Flags button
                Button(action: {
                    flags = featureFlags.getAllFeatureFlags()
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
                    flags = featureFlags.getAllFeatureFlags()
                }) {
                    HStack {
                        Image(systemName: "hammer.fill")
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
        .focusable(true)
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
                    .toggleStyle(RetroTheme.RetroToggleStyle())
            }
        }
        .padding(.vertical, 4)
    }
}
