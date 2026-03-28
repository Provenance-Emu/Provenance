//
//  BackupRestoreView.swift
//  PVUI
//
//  Created by Agent on 2026-03-07.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides a UI for manually backing up and restoring Provenance user data.
//  Addresses issue #1005 (Backup / Restore).
//
//  Backup state lives in BackupCoordinator.shared so compression continues
//  even after this view is dismissed, and the share sheet re-appears on return.
//

import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVLogging
import PVUIBase

// MARK: - BackupRestoreView

struct BackupRestoreView: View {

    // MARK: - Coordinator (persists across view dismissal)

    @ObservedObject private var coordinator = BackupCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local view state

    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    @State private var showRestartAlert = false
    @State private var selectedContents: BackupContents = .all
    /// Tracks a security-scoped URL that must be released when restore finishes.
    @State private var pendingSecurityScopedURL: URL? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            RetroGrid()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3)

            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    contentsSelectionView
                    backupSectionView
                    restoreSectionView
                    infoView
                }
                #if os(tvOS)
                .padding(.horizontal, 80)
                #else
                .padding(.horizontal)
                #endif
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Backup & Restore")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    #if !os(tvOS)
        .navigationBarHidden(false)
        .sheet(isPresented: $showShareSheet, onDismiss: {
            coordinator.cleanupAfterShare()
        }) {
            if let url = coordinator.backupURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        #endif
        .uiKitAlert(
            "Backup & Restore",
            message: alertMessage ?? "",
            isPresented: $showAlert,
            buttons: {
                UIAlertAction(title: "OK", style: .default) { _ in
                    showAlert = false
                    alertMessage = nil
                }
            }
        )
        .uiKitAlert(
            "Restore Complete",
            message: "The backup has been restored. Please restart the app for all changes to take effect.",
            isPresented: $showRestartAlert,
            buttons: {
                UIAlertAction(title: "OK", style: .default) { _ in
                    showRestartAlert = false
                    coordinator.resetRestoreState()
                }
            }
        )
        .onAppear {
            // If backup finished while the view was away, show share sheet immediately.
            #if !os(tvOS)
            if coordinator.backupState == .done, coordinator.backupURL != nil {
                showShareSheet = true
            }
            #endif
        }
        #if !os(tvOS)
        .onChange(of: coordinator.backupState) { state in
            if state == .done, coordinator.backupURL != nil {
                showShareSheet = true
            }
        }
        #endif
        .onChange(of: coordinator.restoreState) { state in
            switch state {
            case .done(let restored):
                // Release security-scoped access now that restore has finished
                pendingSecurityScopedURL?.stopAccessingSecurityScopedResource()
                pendingSecurityScopedURL = nil
                if restored.contains(.database) {
                    showRestartAlert = true
                } else {
                    alertMessage = "Restore complete."
                    showAlert = true
                }
            case .error:
                pendingSecurityScopedURL?.stopAccessingSecurityScopedResource()
                pendingSecurityScopedURL = nil
            default:
                break
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("BACKUP & RESTORE")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 20)
                .shadow(color: .retroPink.opacity(0.5), radius: 10)

            Text("Manually back up and restore your game library,\nsave states, and custom artwork.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var contentsSelectionView: some View {
        retroCard {
            VStack(alignment: .leading, spacing: 12) {
                retroSectionLabel("Include in Backup")

                BackupContentsToggle(
                    label: "Game Library Database",
                    icon: "cylinder.split.1x2",
                    subtitle: "Game metadata and settings",
                    isOn: binding(for: .database)
                )
                BackupContentsToggle(
                    label: "Save States",
                    icon: "arrow.down.doc",
                    subtitle: "In-game save state files",
                    isOn: binding(for: .saveStates)
                )
                BackupContentsToggle(
                    label: "Custom Artwork",
                    icon: "photo.on.rectangle",
                    subtitle: "User-provided game artwork",
                    isOn: binding(for: .customArtwork)
                )
                BackupContentsToggle(
                    label: "Battery Saves",
                    icon: "memorychip",
                    subtitle: "SRAM / in-game saves",
                    isOn: binding(for: .batterySaves)
                )
            }
        }
    }

    private var backupSectionView: some View {
        retroCard {
            VStack(alignment: .leading, spacing: 16) {
                retroSectionLabel("Create Backup")

                #if os(tvOS)
                Text("Creates a .pvbackup archive in the Documents folder.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                #else
                Text("Creates a .pvbackup archive of the selected data and lets you save or share it.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                #endif

                switch coordinator.backupState {
                case .idle:
                    createBackupButton
                case .inProgress(let phase):
                    backupProgressView(phase: phase)
                case .done:
                    #if os(tvOS)
                    Label("Backup saved to Documents folder.", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    createBackupButton
                    #else
                    // Share sheet auto-presented; show a "tap to share again" button
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Backup ready — share sheet opened.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Button("Share Again") { showShareSheet = true }
                            .font(.caption)
                            .foregroundColor(.retroBlue)
                        createBackupButton
                    }
                    #endif
                case .error(let msg):
                    VStack(alignment: .leading, spacing: 8) {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        createBackupButton
                    }
                }
            }
        }
    }

    /// Shows the current phase plus a hint that the user can leave the screen.
    @ViewBuilder
    private func backupProgressView(phase: BackupPhase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressRow(message: phase.rawValue)
            if phase == .compressing {
                Text("You can close this screen — the backup will continue in the background.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var restoreSectionView: some View {
        retroCard {
            VStack(alignment: .leading, spacing: 16) {
                retroSectionLabel("Restore Backup")

                #if os(tvOS)
                Text("On Apple TV, use Web Server or iTunes File Sharing to transfer a .pvbackup file, then tap Restore.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                #else
                Text("Select a .pvbackup file to restore from. The app must restart after restoring the database.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                #endif

                switch coordinator.restoreState {
                case .idle:
                    restoreButton
                case .inProgress(let phase):
                    ProgressRow(message: phase.rawValue)
                case .done(let restored):
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Restore complete", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        if restored.contains(.database) {
                            Label("Restart required to load restored database", systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        restoreButton
                    }
                case .error(let msg):
                    VStack(alignment: .leading, spacing: 8) {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        restoreButton
                    }
                }
            }
        }
    }

    private var createBackupButton: some View {
        Button(action: startBackup) {
            HStack {
                Image(systemName: "arrow.up.doc.fill")
                Text("Create Backup")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(selectedContents.isEmpty)
    }

    private var restoreButton: some View {
        Button(action: {
            #if !os(tvOS)
            showFileImporter = true
            #else
            startTVOSRestore()
            #endif
        }) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                #if os(tvOS)
                Text("Restore from Documents")
                    .fontWeight(.semibold)
                #else
                Text("Choose Backup File")
                    .fontWeight(.semibold)
                #endif
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }

    private var infoView: some View {
        retroCard {
            VStack(alignment: .leading, spacing: 8) {
                retroSectionLabel("Notes")
                Label("ROMs are not included in backups.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Label("After restoring the database, restart the app.", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Label("Backups do not replace iCloud sync.", systemImage: "icloud.slash")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Actions

    private func startBackup() {
        guard !selectedContents.isEmpty else { return }
        coordinator.startBackup(contents: selectedContents)
    }

    #if os(tvOS)
    private func moveTVOSBackup(from tempURL: URL) {
        let dest = URL.documentsPath.appendingPathComponent(tempURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: tempURL, to: dest)
            alertMessage = "Backup saved to Documents: \(dest.lastPathComponent)"
            showAlert = true
        } catch {
            // State update handled via coordinator.backupState observer
            ELOG("BackupRestoreView: could not move tvOS backup: \(error)")
        }
    }

    private func startTVOSRestore() {
        let docs = URL.documentsPath
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            coordinator.resetRestoreState()
            alertMessage = "Could not read Documents folder."
            showAlert = true
            return
        }
        let backups = files
            .filter { $0.pathExtension == "pvbackup" }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
        guard let latest = backups.first else {
            alertMessage = "No .pvbackup files found in Documents."
            showAlert = true
            return
        }
        coordinator.startRestore(from: latest, contents: selectedContents)
    }
    #endif

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertMessage = "Could not access file: \(error.localizedDescription)"
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            // Security-scoped access for files from the document picker.
            // We hold it open until the restore finishes (tracked via onChange above).
            if url.startAccessingSecurityScopedResource() {
                pendingSecurityScopedURL = url
            }
            coordinator.startRestore(from: url, contents: selectedContents)
        }
    }

    // MARK: - Helpers

    private func binding(for content: BackupContents) -> Binding<Bool> {
        Binding(
            get: { selectedContents.contains(content) },
            set: { isOn in
                if isOn { selectedContents.insert(content) }
                else { selectedContents.remove(content) }
            }
        )
    }

    @ViewBuilder
    private func retroCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink.opacity(0.4), .retroBlue.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private func retroSectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.bottom, 4)
    }
}

// MARK: - BackupContentsToggle

private struct BackupContentsToggle: View {
    let label: String
    let icon: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundColor(.retroBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        #if os(tvOS)
        .toggleStyle(RetroTheme.RetroToggleStyle())
        #else
        .toggleStyle(SwitchToggleStyle(tint: .retroPink))
        #endif
    }
}

// MARK: - ProgressRow

private struct ProgressRow: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.retroPink)
            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
}
