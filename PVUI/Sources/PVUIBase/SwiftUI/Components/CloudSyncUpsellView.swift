//
//  CloudSyncUpsellView.swift
//  PVUI
//
//  Lightweight CTA for enabling CloudKit sync in empty-library contexts.
//

import SwiftUI
import Defaults
import PVSettings
import PVThemes
import PVUIBase
#if canImport(FreemiumKit)
import FreemiumKit
#endif

public struct CloudSyncUpsellView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @Default(.iCloudSync) private var iCloudSyncEnabled
    @Default(.iCloudSyncMode) private var iCloudSyncMode

    public let hasCachedCloudData: Bool
    public let onOpenSettings: () -> Void

    /// Optional hook to present upgrade flow for non-premium users.
    public let onUpgrade: (() -> Void)?

    @State private var disabledDueToPremiumLoss = false
    @State private var showPremiumLossAlert = false

    public init(hasCachedCloudData: Bool = false,
         onOpenSettings: @escaping () -> Void,
         onUpgrade: (() -> Void)? = nil) {
        self.hasCachedCloudData = hasCachedCloudData
        self.onOpenSettings = onOpenSettings
        self.onUpgrade = onUpgrade
    }

    #if canImport(FreemiumKit)
    private var isPremium: Bool {
        // Treat self-built, sideloaded, and TestFlight builds as premium.
        if !AppState.shared.isInstalledFromAppStore { return true }
        return FreemiumKit.shared.purchasedTier != nil
    }
    #else
    private var isPremium: Bool { true }
    #endif

    private var isTvOS: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    private var cachedRecordTotal: Int? {
        CloudSyncUpsellView.cachedRecordTotal()
    }

    private static let premiumStateKey = "org.provenance.cloudsync.lastPremiumState"
    private static let premiumLossPromptKey = "org.provenance.cloudsync.lastPremiumLossPrompt"
    private static let recordCountsKey = "org.provenance.cloudsync.cloudkit.lastRecordCounts"

    private var cloudKitToggleBinding: Binding<Bool> {
        Binding(
            get: { iCloudSyncEnabled },
            set: { newValue in
                iCloudSyncEnabled = newValue
                if newValue {
                    iCloudSyncMode = .cloudKit
                }
            }
        )
    }

    public static func detectCachedCloudData() -> Bool {
        // Presence of change token implies prior CloudKit activity; avoids network work.
        let changeTokenKey = "org.provenance.cloudsync.cloudkit.roms.zoneChangeToken.v1"
        if let data = UserDefaults.standard.data(forKey: changeTokenKey), !data.isEmpty {
            return true
        }
        if let total = cachedRecordTotal(), total > 0 { return true }
        return false
    }

    public static func cachedRecordTotal() -> Int? {
        guard let dict = UserDefaults.standard.dictionary(forKey: recordCountsKey) as? [String: Int] else {
            return nil
        }
        let total = dict.values.reduce(0, +)
        return total > 0 ? total : nil
    }

    public var body: some View {
        VStack(spacing: 10) {
            header
            descriptionText
            if isTvOS {
                tvOSActions
            } else if isPremium {
                premiumActions
            } else {
                nonPremiumActions
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentPalette.gameLibraryBackground.swiftUIColor.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .retroPink.opacity(0.35), radius: 6, x: 0, y: 0)
        .onAppear {
            guard !isTvOS else { return }
            let lastPremium = UserDefaults.standard.bool(forKey: Self.premiumStateKey)
            if lastPremium != isPremium {
                UserDefaults.standard.set(isPremium, forKey: Self.premiumStateKey)
            }
            if lastPremium && !isPremium {
                iCloudSyncEnabled = false
                disabledDueToPremiumLoss = true
                if UserDefaults.standard.object(forKey: Self.premiumLossPromptKey) == nil {
                    showPremiumLossAlert = true
                    UserDefaults.standard.set(Date(), forKey: Self.premiumLossPromptKey)
                }
            }
            if !isPremium && iCloudSyncEnabled {
                iCloudSyncEnabled = false
                disabledDueToPremiumLoss = true
            }
        }
        .alert("Cloud Sync Disabled", isPresented: $showPremiumLossAlert) {
            Button("OK", role: .cancel) { showPremiumLossAlert = false }
        } message: {
            Text("Provenance Plus is inactive, so CloudKit sync was turned off. Reactivate Plus to sync again.")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud")
                .foregroundColor(.retroPink)
            Text("Cloud Sync")
                .font(.headline)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            Spacer()
            if hasCachedCloudData {
                Label("Cloud data detected", systemImage: "tray.full")
                    .font(.caption)
                    .foregroundColor(.retroBlue)
            } else if let total = cachedRecordTotal {
                Label("Cloud items: \(total)", systemImage: "tray.full")
                    .font(.caption)
                    .foregroundColor(.retroBlue)
            }
        }
    }

    private var descriptionText: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isTvOS {
                Text("CloudKit sync is ready on Apple TV.")
            } else if isPremium {
                Text("Sync your library with iCloud (CloudKit).")
            } else {
                Text("CloudKit sync is included with Provenance Plus.")
            }

            if disabledDueToPremiumLoss {
                Text("Cloud sync was turned off because Provenance Plus is inactive.")
                    .font(.caption)
                    .foregroundColor(.retroPink)
            } else if let total = cachedRecordTotal {
                Text("We found \(total) items in CloudKit. Enable sync to restore them.")
                    .font(.caption)
                    .foregroundColor(.retroBlue)
            } else if hasCachedCloudData {
                Text("We found existing cloud records. Enable sync to restore them.")
                    .font(.caption)
                    .foregroundColor(.retroBlue)
            }
        }
        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
    }

    private var tvOSActions: some View {
        HStack {
            Spacer()
            Button("Manage Cloud Sync") {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var premiumActions: some View {
        VStack(spacing: 8) {
            Toggle(isOn: cloudKitToggleBinding) {
                Text("Enable CloudKit Sync")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
            .toggleStyle(RetroTheme.RetroToggleStyle())

            if iCloudSyncEnabled {
                Text("CloudKit sync is on. Manage advanced options in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                primaryButton(title: iCloudSyncEnabled ? "Open Cloud Sync Settings" : "Configure Cloud Sync") {
                    onOpenSettings()
                }
                Spacer()
            }
        }
    }

    private var nonPremiumActions: some View {
        VStack(spacing: 8) {
            Text("Unlock Provenance Plus to sync with CloudKit.")
                .font(.subheadline)
                .foregroundColor(.retroPink)

            HStack {
                primaryButton(title: "Learn More") {
                    if let onUpgrade {
                        onUpgrade()
                    } else {
                        onOpenSettings()
                    }
                }
                Spacer()
            }
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 32)
                .frame(maxWidth: 220, alignment: .center)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .retroBlue.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}
