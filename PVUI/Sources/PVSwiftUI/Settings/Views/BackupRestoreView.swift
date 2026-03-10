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

import SwiftUI
import UniformTypeIdentifiers
import PVLibrary
import PVLogging
import PVUIBase

// MARK: - BackupRestoreView

struct BackupRestoreView: View {

    // MARK: - State

    @State private var backupState: BackupViewState = .idle
    @State private var restoreState: RestoreViewState = .idle
    @State private var backupURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    @State private var showRestartAlert = false
    @State private var selectedContents: BackupContents = .all

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
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Backup & Restore")
        #if !os(tvOS)
        .navigationBarHidden(false)
        .sheet(isPresented: $showShareSheet, onDismiss: {
            // Clean up temp file once the share sheet is dismissed
            if let url = backupURL {
                BackupManager.shared.cleanupBackup(at: url)
                backupURL = nil
            }
        }) {
            if let url = backupURL {
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
                }
            }
        )
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

                switch backupState {
                case .idle:
                    createBackupButton
                case .inProgress(let phase):
                    ProgressRow(message: phase.rawValue)
                case .done:
                    #if os(tvOS)
                    Label("Backup saved to Documents folder.", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    #else
                    createBackupButton
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

                switch restoreState {
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
        backupState = .inProgress(.preparing)

        Task {
            do {
                let url = try await BackupManager.shared.createBackup(
                    contents: selectedContents,
                    progressHandler: { phase in
                        Task { @MainActor in
                            backupState = .inProgress(phase)
                        }
                    }
                )
                await MainActor.run {
                    backupURL = url
                    backupState = .done
                    #if !os(tvOS)
                    showShareSheet = true
                    #else
                    // On tvOS, move backup to Documents so it can be retrieved via file sharing
                    moveTVOSBackup(from: url)
                    #endif
                }
            } catch {
                await MainActor.run {
                    backupState = .error(error.localizedDescription)
                }
            }
        }
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
            backupState = .error("Could not save backup: \(error.localizedDescription)")
        }
    }

    private func startTVOSRestore() {
        // On tvOS, look for the most recent .pvbackup in Documents
        let docs = URL.documentsPath
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            restoreState = .error("Could not read Documents folder.")
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
            restoreState = .error("No .pvbackup files found in Documents.")
            return
        }
        restoreState = .inProgress(.restoring)
        Task {
            do {
                let restored = try await BackupManager.shared.restoreBackup(
                    from: latest,
                    contents: selectedContents,
                    progressHandler: { phase in
                        Task { @MainActor in restoreState = .inProgress(phase) }
                    }
                )
                await MainActor.run {
                    restoreState = .done(restored)
                    if restored.contains(.database) {
                        showRestartAlert = true
                    } else {
                        alertMessage = "Restore complete from \(latest.lastPathComponent)."
                        showAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    restoreState = .error(error.localizedDescription)
                }
            }
        }
    }
    #endif

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            restoreState = .error("Could not access file: \(error.localizedDescription)")
        case .success(let urls):
            guard let url = urls.first else { return }
            restoreState = .inProgress(.restoring)

            Task {
                do {
                    // Security-scoped access for files from the document picker
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

                    let restored = try await BackupManager.shared.restoreBackup(
                        from: url,
                        contents: selectedContents,
                        progressHandler: { phase in
                            Task { @MainActor in
                                restoreState = .inProgress(phase)
                            }
                        }
                    )
                    await MainActor.run {
                        restoreState = .done(restored)
                        if restored.contains(.database) {
                            showRestartAlert = true
                        } else {
                            alertMessage = "Restore complete."
                            showAlert = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        restoreState = .error(error.localizedDescription)
                    }
                }
            }
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

// MARK: - View State Enums

private enum BackupViewState {
    case idle
    case inProgress(BackupPhase)
    case done
    case error(String)
}

private enum RestoreViewState {
    case idle
    case inProgress(BackupPhase)
    case done(BackupContents)
    case error(String)
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
    NavigationView {
        BackupRestoreView()
    }
}
