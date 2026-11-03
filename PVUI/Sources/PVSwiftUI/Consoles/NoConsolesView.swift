///
/// NoConsolesView.swift
/// PVUI
///
/// Created by Joseph Mattiello on 9/22/24.
/// Updated with retrowave styling on 04/07/25.
///

import SwiftUI
import PVThemes
import PVUIBase
import PVHelp
import AnimatedGradient
import PVFeatureFlags

/// Animated gradient background for the NoConsolesView
public struct PVAnimatedGradient: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    public var body: some View {
        AnimatedLinearGradient(colors: [
            Color.retroPink,
            Color.retroPurple,
            Color.retroBlue,
            Color.retroDarkBlue])
        .numberOfSimultaneousColors(3)
        .setAnimation(.bouncy(duration: 5))
        .gradientPoints(start: .topTrailing, end: .bottomLeading)
        .ignoresSafeArea()
    }
}

/// A retrowave-styled view displayed when no games are found
public struct NoConsolesView: SwiftUI.View {
    /// Delegate to handle user actions
    weak var delegate: PVMenuDelegate!

    @ObservedObject private var themeManager = ThemeManager.shared

    public var body: some SwiftUI.View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 48) {
                            welcome.frame(width: 450)
                            LibraryCartridgeIllustration().frame(width: 300, height: 260)
                        }
                        VStack(alignment: .leading, spacing: 28) {
                            welcome
                            LibraryCartridgeIllustration()
                                .frame(width: 240, height: 210)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) { helpLinks }
                        VStack(alignment: .leading, spacing: 8) { helpLinks }
                    }
                    .font(.subheadline)
                    Button(action: openCloudSettings) {
                        Label("Restore or sync your library with iCloud", systemImage: "icloud")
                            .font(.subheadline)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    if CloudSyncUpsellView.detectCachedCloudData() {
                        CloudSyncUpsellView(hasCachedCloudData: true, onOpenSettings: openCloudSettings, onUpgrade: openCloudSettings)
                    }
                }
                .frame(maxWidth: 850, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .background(RetroTheme.RetroBackgroundView().environmentObject(themeManager))
        }
        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
    }

    @ViewBuilder
    private var helpLinks: some View {
        NavigationLink(destination: WikiHelpView()) {
            Label("Help & Wiki", systemImage: "books.vertical").frame(minHeight: 44).contentShape(Rectangle())
        }
        NavigationLink(destination: ControllerGuideView()) {
            Label("Controller Guide", systemImage: "gamecontroller").frame(minHeight: 44).contentShape(Rectangle())
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your library starts here.")
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Add your first game. Your systems will fall into place.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { delegate?.didTapAddGames() } label: {
                Label("Add games", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(LinearGradient(colors: [.retroBlue.opacity(0.85), .retroPurple.opacity(0.75)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: .retroCyan.opacity(0.12), radius: 12)
            .frame(maxWidth: 280)
            if PVFeatureFlagsManager.shared.featureStates[.inAppFreeROMs] == true {
                Button { delegate?.didTapFreeROMs() } label: {
                    Text("Explore free games")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: 280, minHeight: 50)
                        .contentShape(Rectangle())
                }
                .background(Color.retroDarkBlue, in: RoundedRectangle(cornerRadius: 15))
            }
        }
    }

    private func openCloudSettings() {
        SettingsNavigator.shared.navigate(to: .cloudSync)
        NotificationCenter.default.post(name: .pvShowSettings, object: nil)
    }
}

/// The empty library's archival cartridges are decorative, never game artwork.
private struct LibraryCartridgeIllustration: View {
    var body: some View {
        ZStack {
            cartridge.rotationEffect(.degrees(9)).offset(x: -55, y: -4)
            cartridge.rotationEffect(.degrees(-8)).offset(x: 38, y: -24)
            cartridge.offset(y: 36)
        }
        .scaleEffect(0.86)
        .accessibilityHidden(true)
    }

    private var cartridge: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Color.retroBlue).frame(width: 78, height: 3)
                Capsule().fill(Color.retroBlue).frame(width: 55, height: 2)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 127, height: 80)
            .background(Color.retroBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.retroBlue.opacity(0.55), lineWidth: 0.7) }
            VStack(spacing: 5) {
                ForEach(0..<5) { _ in
                    Capsule().fill(Color.retroBlue.opacity(0.2)).frame(width: 75, height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            Capsule().fill(Color.retroBlue).frame(width: 83, height: 10).frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 157, height: 182)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [.retroDarkBlue.opacity(0.95), .retroBlack.opacity(0.95)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.retroBlue.opacity(0.38), lineWidth: 1) }
        .shadow(color: .retroCyan.opacity(0.09), radius: 12, y: 7)
    }
}

#if DEBUG
#Preview {
    NoConsolesView()
}
#endif
