//
//  EcosystemIntegrationView.swift
//  PVUI
//
//  Created by Agent on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Shows available ecosystem apps (XeniOS, MeloNX, MeloCafe) and provides
//  launch buttons for cross-app game integration.
//
//  This view is iOS-only and gated behind the `thirdPartyEcosystemIntegration`
//  feature flag. It must not be instantiated on tvOS.
//

#if !os(tvOS)
import SwiftUI
import PVLibrary
import PVUIBase

// MARK: - EcosystemIntegrationView

/// Displays installed ecosystem apps and explains cross-app game launching.
///
/// Gated behind `thirdPartyEcosystemIntegration` feature flag (disabled by default).
/// Navigate to this view from `ExternalEmulatorMigrationView` when the flag is active.
public struct EcosystemIntegrationView: View {
    @State private var installedApps: [EcosystemApp] = []
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if installedApps.isEmpty {
                        emptyStateSection
                    } else {
                        installedSection
                    }

                    allAppsSection

                    featureFlagNoteBox
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(Text("ecosystem.nav.title", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await detectInstalledApps()
        }
        .settingsSubpageTracking()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .retroBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .purple.opacity(0.4), radius: 8)

            Text("ecosystem.header.title", bundle: .module)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroPurple, .retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("ecosystem.header.subtitle", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Installed apps

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: Text("ecosystem.section.detected", bundle: .module),
                icon: "checkmark.circle.fill",
                color: .green
            )

            ForEach(installedApps, id: \.rawValue) { app in
                EcosystemAppRowView(app: app, isInstalled: true)
            }
        }
    }

    // MARK: - Empty state

    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            sectionHeader(
                title: Text("ecosystem.section.not_detected", bundle: .module),
                icon: "magnifyingglass",
                color: .orange
            )

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "app.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("ecosystem.empty.body", bundle: .module)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Text("ecosystem.empty.footer", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 20)
                )
                .frame(minHeight: 120)
        }
    }

    // MARK: - All apps (not yet installed or combined list)

    @ViewBuilder
    private var allAppsSection: some View {
        let notInstalled = EcosystemApp.allCases.filter { app in
            !installedApps.contains(where: { $0.rawValue == app.rawValue })
        }
        if !notInstalled.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: Text("ecosystem.section.not_installed", bundle: .module),
                    icon: "square.and.arrow.down",
                    color: .secondary
                )
                ForEach(notInstalled, id: \.rawValue) { app in
                    EcosystemAppRowView(app: app, isInstalled: false)
                }
            }
        }
    }

    // MARK: - Feature flag note

    private var featureFlagNoteBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flag.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text("ecosystem.feature_flag.note", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Section header

    private func sectionHeader(title: Text, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline.weight(.semibold))
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    // MARK: - Detection

    @MainActor
    private func detectInstalledApps() async {
        installedApps = EcosystemApp.allCases.filter { $0.isInstalled }
    }
}

// MARK: - EcosystemAppRowView

private struct EcosystemAppRowView: View {
    let app: EcosystemApp
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isInstalled ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: app.symbolName)
                    .font(.system(size: 18))
                    .foregroundStyle(isInstalled ? Color.purple : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(app.platformSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isInstalled {
                    Text(appDescription(for: app))
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer()

            if isInstalled {
                Button {
                    openApp(app)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(isInstalled ? 0.06 : 0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isInstalled ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func appDescription(for app: EcosystemApp) -> String {
        switch app {
        case .xenios:   return NSLocalizedString("ecosystem.app.xenios.description", bundle: .module, comment: "")
        case .melonx:   return NSLocalizedString("ecosystem.app.melonx.description", bundle: .module, comment: "")
        case .meloCafe: return NSLocalizedString("ecosystem.app.melocafe.description", bundle: .module, comment: "")
        }
    }

    @MainActor
    private func openApp(_ app: EcosystemApp) {
        guard let url = URL(string: "\(app.urlScheme)://") else { return }
        UIApplication.shared.open(url)
    }
}
#endif
