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

/// Extension for the Settings tab of CloudSyncSettingsView
extension CloudSyncSettingsView {
    /// The settings tab contains sync options, on-demand downloads, and other settings
    var settingsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Sync options
                syncOptionsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // On-demand downloads
                onDemandDownloadsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Reset sync
                resetSyncView
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Options")
                .retroSectionHeader()

            VStack(spacing: 12) {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .toggleStyle(RetroTheme.RetroToggleStyle())

                // Toggle("Auto-sync on App Launch", isOn: $autoSyncOnLaunch)
                //     .toggleStyle(RetroTheme.RetroToggleStyle())

                // Toggle("Sync Screenshots", isOn: $syncScreenshots)
                //     .toggleStyle(RetroTheme.RetroToggleStyle())

                // Toggle("Sync Save States", isOn: $syncSaveStates)
                //     .toggleStyle(RetroTheme.RetroToggleStyle())
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }

    /// On-demand downloads view with buttons for downloading specific content
    var onDemandDownloadsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On-Demand Downloads")
                .retroSectionHeader()

            VStack(spacing: 12) {
                Button(action: {
                    viewModel.downloadRoms()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download ROMs")
                        Spacer()
                    }
                    .padding()
                }
                .retroButton(colors: [.retroBlue, .retroPurple])

                Button(action: {
                    viewModel.downloadSaveStates()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download Save States")
                        Spacer()
                    }
                    .padding()
                }
                .retroButton(colors: [.retroPurple, .retroPink])

                Button(action: {
                    viewModel.downloadBios()
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playSuccess()
                    #endif
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download BIOS Files")
                        Spacer()
                    }
                    .padding()
                }
                .retroButton(colors: [.retroPink, .retroBlue])
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }

    /// Reset sync view with button for resetting cloud sync
    var resetSyncView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reset Sync")
                .retroSectionHeader()

            VStack(spacing: 12) {
                Text("If you're experiencing sync issues, you can reset the cloud sync data. This will not delete your local files, but will reset the sync state.")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: {
                    showingResetConfirmation = true
                    #if !os(tvOS)
                    HapticFeedbackService.shared.playWarning()
                    #endif
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                        Text("Reset Cloud Sync")
                        Spacer()
                    }
                    .padding()
                }
                .retroButton(colors: [.red.opacity(0.7), .orange.opacity(0.7)])
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
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }
}
