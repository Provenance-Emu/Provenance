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
import AudioToolbox

struct FeatureFlagsDebugView: View {
    @StateObject private var featureFlags = PVFeatureFlagsManager.shared
    @State private var flags: [(key: String, flag: FeatureFlag, enabled: Bool)] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Animation states for retrowave effects
    @State private var glowOpacity: Double = 0.7

    #if os(tvOS)
    @FocusState private var focusedButton: ButtonID?

    internal enum ButtonID: Hashable {
        case clearOverrides
        case reindexSpotlight
        case refreshFlags
        case loadTest
        case resetDefault
    }
    #endif

    private func refreshFlagsList() {
        flags = featureFlags.getAllFeatureFlags()
    }

    var body: some View {
        ZStack {
            RetroTheme.retroBackground

            ScrollView {
                VStack(spacing: 10) {
                    // Title
                    Text("FEATURE FLAGS")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(RetroTheme.retroPink)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)

                    if isLoading {
                        LoadingSection()
                            .modifier(RetroTheme.RetroSectionStyle())
                            .padding(.horizontal, 10)
                    }

                    FeatureFlagsSection(flags: flags, featureFlags: featureFlags, refreshAction: refreshFlagsList)
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal, 10)

                    UserDefaultsSection()
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal, 10)

                    ConfigurationSection()
                        .modifier(RetroTheme.RetroSectionStyle())
                        .padding(.horizontal, 10)

                    DebugControlsSection(
                        featureFlags: featureFlags,
                        flags: $flags,
                        isLoading: $isLoading,
                        errorMessage: $errorMessage
                    )
                    .modifier(RetroTheme.RetroSectionStyle())
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("Feature Flags Debug")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await loadInitialConfiguration()

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
                errorMessage = nil
            }
        }
    }

    @MainActor
    private func loadInitialConfiguration() async {
        isLoading = true

        do {
            try await loadDefaultConfiguration()
            flags = featureFlags.getAllFeatureFlags()
        } catch {
            errorMessage = "Failed to load remote configuration: \(error.localizedDescription)"
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

// MARK: - Loading Section

private struct LoadingSection: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: RetroTheme.retroPink))
                .scaleEffect(1.2)

            Text("LOADING CONFIGURATION")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(RetroTheme.retroBlue)
                .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Feature Flags Section

private struct FeatureFlagsSection: View {
    let flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "FEATURE FLAGS STATUS")

            if flags.isEmpty {
                Text("NO FEATURE FLAGS FOUND")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(flags, id: \.key) { flag in
                        FeatureFlagRow(flag: flag, featureFlags: featureFlags, refreshAction: refreshAction)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(RetroTheme.retroBlack.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.5), RetroTheme.retroBlue.opacity(0.5)]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Feature Flag Row (Compact, Unified)

private struct FeatureFlagRow: View {
    let flag: (key: String, flag: FeatureFlag, enabled: Bool)
    @ObservedObject var featureFlags: PVFeatureFlagsManager
    let refreshAction: () -> Void
    @State private var isEnabled: Bool

    private var featureEnum: PVFeature? { PVFeature(rawValue: flag.key) }

    init(flag: (key: String, flag: FeatureFlag, enabled: Bool), featureFlags: PVFeatureFlagsManager, refreshAction: @escaping () -> Void) {
        self.flag = flag
        self.featureFlags = featureFlags
        self.refreshAction = refreshAction
        self._isEnabled = State(initialValue: flag.enabled)
    }

    private var overrideBadge: (text: String, color: Color)? {
        guard let feature = featureEnum else { return nil }
        let currentOverrides = featureFlags.getCurrentDebugOverrides()
        if let overrideValue = currentOverrides[feature] {
            return overrideValue ? ("OVR:ON", RetroTheme.retroBlue) : ("OVR:OFF", RetroTheme.retroPink)
        }
        return nil
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 8) {
            // Left: key + description, compact
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(flag.key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RetroTheme.retroPink)
                        .lineLimit(1)

                    // Status badge
                    Text(flag.enabled ? "ON" : "OFF")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(flag.enabled ? RetroTheme.retroGreen : RetroTheme.retroPink)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill((flag.enabled ? RetroTheme.retroGreen : RetroTheme.retroPink).opacity(0.2))
                        )

                    // Override badge (only if overridden)
                    if let badge = overrideBadge {
                        Text(badge.text)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(badge.color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(badge.color.opacity(0.2))
                            )
                    }
                }

                if let desc = flag.flag.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                        .lineLimit(1)
                }

                // Restrictions only if present
                let restrictions = featureFlags.getFeatureRestrictions(flag.key)
                if !restrictions.isEmpty {
                    Text(restrictions.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Right: toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(RetroTheme.retroPurple)
        }
    }

    var body: some View {
#if os(tvOS)
        rowContent
            .onChange(of: isEnabled) { newValue in
                guard let feature = featureEnum else { return }
                featureFlags.setDebugOverride(for: feature, enabled: newValue)
                refreshAction()
            }
#else
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(flag.key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RetroTheme.retroPink)
                        .lineLimit(1)

                    Text(flag.enabled ? "ON" : "OFF")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(flag.enabled ? RetroTheme.retroGreen : RetroTheme.retroPink)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill((flag.enabled ? RetroTheme.retroGreen : RetroTheme.retroPink).opacity(0.2))
                        )

                    if let badge = overrideBadge {
                        Text(badge.text)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(badge.color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(badge.color.opacity(0.2))
                            )
                    }
                }

                if let desc = flag.flag.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                        .lineLimit(1)
                }

                let restrictions = featureFlags.getFeatureRestrictions(flag.key)
                if !restrictions.isEmpty {
                    Text(restrictions.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            RetroWaveToggle(isOn: $isEnabled, label: "")
        }
        .padding(.vertical, 2)
        .onChange(of: isEnabled) { newValue in
            guard let feature = featureEnum else { return }
            featureFlags.setDebugOverride(for: feature, enabled: newValue)
            refreshAction()
        }
#endif
    }
}

// MARK: - Configuration Section (Compact)

private struct ConfigurationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "CURRENT CONFIGURATION")

            VStack(alignment: .leading, spacing: 4) {
                ConfigRow(icon: "app.fill", label: "APP TYPE", value: PVFeatureFlags.getCurrentAppType().rawValue.uppercased())
                ConfigRow(icon: "tag.fill", label: "VERSION", value: PVFeatureFlags.getCurrentAppVersion())
                if let buildNumber = PVFeatureFlags.getCurrentBuildNumber() {
                    ConfigRow(icon: "number.circle.fill", label: "BUILD", value: "\(buildNumber)")
                }
                ConfigRow(icon: "link", label: "REMOTE", value: "data.provenance-emu.com")
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

private struct ConfigRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(RetroTheme.retroPink)
                .frame(width: 16)

            Text(label + ":")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(RetroTheme.retroBlue)
                .shadow(color: RetroTheme.retroBlue.opacity(0.5), radius: 2, x: 0, y: 0)
        }
    }
}

// MARK: - Debug Controls Section (Grid Layout)

private struct DebugControlsSection: View {
    let featureFlags: PVFeatureFlagsManager
    @Binding var flags: [(key: String, flag: FeatureFlag, enabled: Bool)]
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    #if os(tvOS)
    @FocusState private var focusedButton: FeatureFlagsDebugView.ButtonID?
    #endif

    @State private var glowOpacity: Double = 0.7
    @State private var isReindexingSpotlight = false
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "DEBUG CONTROLS")

            // Two-column grid for buttons
            let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
            LazyVGrid(columns: columns, spacing: 6) {
                RetroDebugButton(
                    icon: "xmark.circle.fill",
                    title: "CLEAR OVERRIDES",
                    color: RetroTheme.retroBlue,
                    glowOpacity: glowOpacity
                ) {
                    featureFlags.clearDebugOverrides()
                    flags = featureFlags.getAllFeatureFlags()
                }
                #if os(tvOS)
                .focused($focusedButton, equals: .clearOverrides)
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif

                RetroDebugButton(
                    icon: isReindexingSpotlight ? nil : "magnifyingglass",
                    title: isReindexingSpotlight ? "REINDEXING..." : "REINDEX SPOTLIGHT",
                    color: RetroTheme.retroPink,
                    glowOpacity: glowOpacity,
                    showSpinner: isReindexingSpotlight
                ) {
                    isReindexingSpotlight = true
                    SpotlightHelper.shared.forceReindexAll {
                        isReindexingSpotlight = false
                    }
                }
                .disabled(isReindexingSpotlight)
                #if os(tvOS)
                .focused($focusedButton, equals: .reindexSpotlight)
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif

                RetroDebugButton(
                    icon: "arrow.clockwise",
                    title: "REFRESH FLAGS",
                    color: RetroTheme.retroPurple,
                    glowOpacity: glowOpacity
                ) {
                    flags = featureFlags.getAllFeatureFlags()
                }
                #if os(tvOS)
                .focused($focusedButton, equals: .refreshFlags)
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif

                RetroDebugButton(
                    icon: "testtube.2",
                    title: "LOAD TEST",
                    color: RetroTheme.retroBlue,
                    glowOpacity: glowOpacity
                ) {
                    loadTestConfiguration()
                    flags = featureFlags.getAllFeatureFlags()
                }
                #if os(tvOS)
                .focused($focusedButton, equals: .loadTest)
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
            }
            .padding(.horizontal, 4)

            // Reset button full-width (destructive)
            RetroDebugButton(
                icon: "trash.fill",
                title: "RESET TO DEFAULT",
                color: RetroTheme.retroPink,
                glowOpacity: glowOpacity
            ) {
                Task {
                    do {
                        try await loadDefaultConfiguration()
                        flags = featureFlags.getAllFeatureFlags()
                        showFeatureFlagsDebug = false
                        Defaults.Keys.useAppGroups.reset()
                        Defaults.Keys.unsupportedCores.reset()
                        Defaults.Keys.iCloudSync.reset()
                    } catch {
                        errorMessage = "Failed to load default configuration: \(error.localizedDescription)"
                    }
                }
            }
            .padding(.horizontal, 4)
            #if os(tvOS)
            .focused($focusedButton, equals: .resetDefault)
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
            #else
            .buttonStyle(PlainButtonStyle())
            #endif
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.9
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

// MARK: - Reusable Debug Button

private struct RetroDebugButton: View {
    let icon: String?
    let title: String
    let color: Color
    let glowOpacity: Double
    var showSpinner: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if showSpinner {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(color)
            .background(RetroTheme.retroBlack.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: color.opacity(glowOpacity), radius: 3, x: 0, y: 0)
        }
    }
}

// MARK: - User Defaults Section (Unified)

private struct UserDefaultsSection: View {
    @Default(.useAppGroups) var useAppGroups
    @Default(.unsupportedCores) var unsupportedCores
    @Default(.iCloudSync) var iCloudSync
    @Default(.obfuscateArtwork) var obfuscateArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "USER DEFAULTS")

            VStack(spacing: 4) {
                UserDefaultRow(title: "useAppGroups", subtitle: "Shared storage via App Groups", isOn: $useAppGroups)
                UserDefaultRow(title: "unsupportedCores", subtitle: "Experimental cores", isOn: $unsupportedCores)
                UserDefaultRow(title: "iCloudSync", subtitle: "Sync saves with iCloud", isOn: $iCloudSync)
                UserDefaultRow(title: "obfuscateArtwork", subtitle: "Blur artwork for screenshots", isOn: $obfuscateArtwork)
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

private struct UserDefaultRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
#if os(tvOS)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(RetroTheme.retroPurple)
#else
            Toggle("", isOn: $isOn)
                .toggleStyle(RetroTheme.RetroToggleStyle())
                .focusableIfAvailable()
#endif
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(RetroTheme.retroBlack.opacity(0.3))
        )
    }
}

// MARK: - Shared Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(RetroTheme.retroPurple)
            .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 3, x: 0, y: 0)
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
    }
}
