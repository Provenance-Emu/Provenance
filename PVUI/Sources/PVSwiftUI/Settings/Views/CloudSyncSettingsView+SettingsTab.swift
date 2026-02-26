//
//  CloudSyncSettingsView+SettingsTab.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/28/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLogging
import Defaults
import PVSettings

/// Extension for the Settings tab of CloudSyncSettingsView
extension CloudSyncSettingsView {
    /// The settings tab contains sync options, on-demand downloads, and other settings
    var settingsTab: some View {
        ScrollView {
            #if os(tvOS)
            let sectionSpacing: CGFloat = 32
            #else
            let sectionSpacing: CGFloat = 16
            #endif
            LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                syncOptionsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                onDemandDownloadsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                resetSyncView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                cloudKitDiagnosticsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)
            }
            .padding(.vertical)
        }
        .onAppear {
            #if !os(tvOS)
            HapticFeedbackService.shared.playSelection(style: .light)
            #endif
        }
    }

    /// Sync options view with toggles for enabling/disabling sync features
    var syncOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Options")
                .cloudSyncSectionTitle()

            VStack(spacing: 12) {
                #if os(tvOS)
                CloudSyncToggleRow(
                    title: "Enable iCloud Sync",
                    subtitle: "Sync data between devices via iCloud",
                    isOn: $iCloudSyncEnabled
                )
                #else
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                #endif

                if iCloudSyncEnabled {
                    syncModePickerView
                }
            }
            #if !os(tvOS)
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
            #endif
        }
    }

    /// On-demand downloads view with buttons for downloading specific content
    var onDemandDownloadsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("On-Demand Downloads")
                .cloudSyncSectionTitle()

            VStack(spacing: 12) {
                cloudSyncActionButton(
                    title: "Download ROMs",
                    icon: "arrow.down.circle",
                    colors: [.retroBlue, .retroPurple]
                ) {
                    viewModel.downloadRoms()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }

                cloudSyncActionButton(
                    title: "Download Save States",
                    icon: "arrow.down.circle",
                    colors: [.retroPurple, .retroPink]
                ) {
                    viewModel.downloadSaveStates()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }

                cloudSyncActionButton(
                    title: "Download BIOS Files",
                    icon: "arrow.down.circle",
                    colors: [.retroPink, .retroBlue]
                ) {
                    viewModel.downloadBios()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }
            }
            #if !os(tvOS)
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
            #endif
        }
    }

    /// Reset sync view with button for resetting cloud sync
    var resetSyncView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset Sync")
                .cloudSyncSectionTitle()

            VStack(spacing: 12) {
                Text("If you're experiencing sync issues, you can reset the cloud sync data. This will not delete your local files, but will reset the sync state.")
                    #if os(tvOS)
                    .font(.system(size: 16))
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor(.gray)

                cloudSyncActionButton(
                    title: "Reset Cloud Sync",
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    colors: [.red.opacity(0.7), .orange.opacity(0.7)]
                ) {
                    showingResetConfirmation = true
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playWarning()
                    #endif
                }
                .alert(isPresented: $showingResetConfirmation) {
                    Alert(
                        title: Text("Reset Cloud Sync"),
                        message: Text("Are you sure you want to reset cloud sync? This will clear all sync metadata and may cause files to be re-uploaded."),
                        primaryButton: .destructive(Text("Reset")) {
                            viewModel.resetCloudSync()
                            #if !os(tvOS)
                            HapticFeedbackService.shared.playError()
                            #endif
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            #if !os(tvOS)
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
            #endif
        }
    }
    
    /// Sync mode picker view for selecting between iCloud Drive and CloudKit
    var syncModePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Mode")
                #if os(tvOS)
                .font(.system(size: 18, weight: .medium))
                #else
                .font(.subheadline)
                #endif
                .foregroundColor(.white)

            VStack(spacing: 4) {
                ForEach(iCloudSyncMode.allCases, id: \.self) { mode in
                    #if os(tvOS)
                    CloudSyncSelectionRow(
                        title: mode.description,
                        subtitle: mode.subtitle,
                        isSelected: currentiCloudSyncMode == mode
                    ) {
                        withAnimation { currentiCloudSyncMode = mode }
                    }
                    #else
                    syncModeOptionView(mode: mode)
                    #endif
                }
            }
        }
        .padding(.top, 8)
    }

    #if !os(tvOS)
    /// Individual sync mode option view (iOS only)
    private func syncModeOptionView(mode: iCloudSyncMode) -> some View {
        Button(action: {
            currentiCloudSyncMode = mode
            HapticFeedbackService.shared.playSelection()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: currentiCloudSyncMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(currentiCloudSyncMode == mode ? .retroPink : .gray)
                    .font(.title2)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentiCloudSyncMode == mode ? Color.retroPink.opacity(0.2) : Color.retroBlack.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentiCloudSyncMode == mode ? Color.retroPink : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    #endif
    
    /// CloudKit diagnostics view with button for opening CloudKit diagnostic tools
    var cloudKitDiagnosticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .cloudSyncSectionTitle()

            VStack(spacing: 12) {
                Text("Advanced diagnostic tools for troubleshooting CloudKit sync issues.")
                    #if os(tvOS)
                    .font(.system(size: 16))
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor(.gray)

                cloudSyncActionButton(
                    title: "CloudKit Diagnostics",
                    icon: "stethoscope",
                    colors: [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)],
                    trailing: AnyView(
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
                ) {
                    showDiagnostics = true
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSelection()
                    #endif
                }

                cloudSyncActionButton(
                    title: "Force Initial Sync",
                    icon: "icloud.and.arrow.up",
                    colors: [.retroGreen.opacity(0.7), .retroBlue.opacity(0.7)],
                    trailing: viewModel.isPerformingInitialSync ? AnyView(ProgressView().scaleEffect(0.8)) : nil
                ) {
                    viewModel.forceInitialSync()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSelection()
                    #endif
                }
                .disabled(viewModel.isPerformingInitialSync)
            }
            #if !os(tvOS)
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
            #endif
        }
    }

    /// Reusable action button with retrowave gradient styling and tvOS focus support
    func cloudSyncActionButton(
        title: String,
        icon: String,
        colors: [Color],
        trailing: AnyView? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    #if os(tvOS)
                    .font(.system(size: 18, weight: .medium))
                    #endif
                Spacer()
                if let trailing = trailing {
                    trailing
                }
            }
            .padding()
            .background(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .cornerRadius(12)
            .foregroundColor(.white)
        }
        #if os(tvOS)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
    }
}
