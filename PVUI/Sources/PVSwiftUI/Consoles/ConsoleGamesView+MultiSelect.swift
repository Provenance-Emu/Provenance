//
//  ConsoleGamesView+MultiSelect.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-25.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVRealm
import PVThemes
import PVSettings
import PVLogging
import PVUIBase

// MARK: - Multi-Select UI Helpers

extension ConsoleGamesView {

    // MARK: - Selection toggle (shared helper)

    /// Fires a haptic tap and toggles the selection state for `md5`.
    /// Centralised here so `gameAction(for:)` and `multiSelectOverlay`'s
    /// tap gesture use identical behaviour and cannot drift.
    private func performSelectionToggle(md5: String) {
        #if !os(tvOS)
        Haptics.impact(style: .light)
        #endif
        Task { @MainActor in
            gamesViewModel.toggleSelection(md5: md5)
            updateCloudActionAvailability()
        }
    }

    // MARK: - Select-mode overlay wrapper

    /// Returns the appropriate tap action for a game cell, respecting multi-select mode.
    /// When in multi-select mode the action toggles selection; otherwise it launches the game.
    func gameAction(for md5: String) -> () -> Void {
        {
            if gamesViewModel.isMultiSelectMode {
                performSelectionToggle(md5: md5)
            } else {
                launchGame(md5: md5)
            }
        }
    }

    /// Wraps a game cell with a selection indicator overlay when multi-select is active.
    /// Selection checkmark is placed top-leading to avoid conflicting with the
    /// cloud sync indicator badge at top-trailing.
    @ViewBuilder
    func multiSelectOverlay(md5: String, @ViewBuilder content: () -> some View) -> some View {
        let isSelected = gamesViewModel.selectedGameMD5s.contains(md5)
        ZStack(alignment: .topLeading) {
            content()
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.retroPink, lineWidth: 3)
                    }
                }
                // Disable hit-testing on the inner content when in multi-select mode
                // so only the outer tap gesture fires.
                .allowsHitTesting(!gamesViewModel.isMultiSelectMode)

            if gamesViewModel.isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.retroPink : Color.white.opacity(0.7))
                    .background(
                        Circle()
                            .fill(isSelected ? Color.retroPink.opacity(0.25) : Color.black.opacity(0.5))
                            .shadow(color: isSelected ? Color.retroPink.opacity(0.5) : .clear, radius: 4)
                    )
                    .font(.system(size: 22, weight: .bold))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if gamesViewModel.isMultiSelectMode {
                performSelectionToggle(md5: md5)
            }
        }
    }

    // MARK: - Multi-select state sync

    /// Syncs local multi-select state to the shared `MultiSelectToolbarState`
    /// so `RetroMainView` can render the toolbar above the tab bar.
    var multiSelectToolbar: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: gamesViewModel.isMultiSelectMode) { isActive in
                let state = MultiSelectToolbarState.shared
                if isActive {
                    state.activate()
                    state.onNormalizeTitles = { [weak gamesViewModel] in
                        gamesViewModel?.showNormalizeTitlePreview = true
                    }
                    state.onDelete = { [weak gamesViewModel] in
                        guard let vm = gamesViewModel else { return }
                        vm.showBatchDeleteConfirmation = true
                    }
                    state.onMoveToSystem = { [weak gamesViewModel] in
                        guard let vm = gamesViewModel else { return }
                        vm.showBatchMoveToSystem = true
                    }
                    state.onOffload = { [weak gamesViewModel] in
                        guard let vm = gamesViewModel else { return }
                        vm.showBatchOffloadConfirmation = true
                    }
                    state.onDownload = { [weak gamesViewModel] in
                        guard let vm = gamesViewModel else { return }
                        vm.showBatchDownloadConfirmation = true
                    }
                    state.onDone = { [weak gamesViewModel] in
                        Task { @MainActor in
                            gamesViewModel?.exitMultiSelectMode()
                        }
                    }
                } else {
                    state.deactivate()
                }
            }
            .onChange(of: gamesViewModel.selectedGameMD5s.count) { count in
                MultiSelectToolbarState.shared.updateCount(count)
                updateCloudActionAvailability()
            }
    }

    // MARK: - Cloud action availability

    /// Updates the toolbar's offload/download button visibility based on selected games.
    private func updateCloudActionAvailability() {
        let state = MultiSelectToolbarState.shared
        guard Defaults[.iCloudSync] else {
            state.canOffload = false
            state.canDownload = false
            return
        }
        let realm = RomDatabase.sharedInstance.realm
        var hasOffloadable = false
        var hasDownloadable = false
        for md5 in gamesViewModel.selectedGameMD5s {
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { continue }
            if game.cloudRecordID != nil {
                if game.isDownloaded { hasOffloadable = true }
                else { hasDownloadable = true }
            }
            if hasOffloadable && hasDownloadable { break }
        }
        state.canOffload = hasOffloadable
        state.canDownload = hasDownloadable
    }

    // MARK: - Edit / Done toggle button (placed in titleBar)

    @ViewBuilder
    var multiSelectToggleButton: some View {
        Button {
            #if !os(tvOS)
            Haptics.impact(style: .light)
            #endif
            Task { @MainActor in
                if gamesViewModel.isMultiSelectMode {
                    gamesViewModel.exitMultiSelectMode()
                } else {
                    gamesViewModel.enterMultiSelectMode()
                }
            }
        } label: {
            Text(gamesViewModel.isMultiSelectMode ? "Done" : "Select")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(gamesViewModel.isMultiSelectMode
                              ? Color.retroPink.opacity(0.2)
                              : Color.retroPurple.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(gamesViewModel.isMultiSelectMode
                                              ? Color.retroPink
                                              : Color.retroBlue,
                                              lineWidth: 1)
                        )
                )
                .foregroundColor(gamesViewModel.isMultiSelectMode ? .retroPink : .retroBlue)
        }
    }

    // MARK: - Normalize-titles sheet

    /// Builds the preview rows from the current selection and presents the sheet.
    @ViewBuilder
    var normalizeTitleSheet: some View {
        // Sort for deterministic ordering (Set iteration is nondeterministic).
        let selectedMD5s = gamesViewModel.selectedGameMD5s.sorted()
        let realm = RomDatabase.sharedInstance.realm
        let rows: [NormalizeTitlePreviewRow] = selectedMD5s.compactMap { md5 in
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                return nil
            }
            let proposed = ROMTitleNormalizer.normalize(game.title)
            return NormalizeTitlePreviewRow(
                id: game.md5Hash,
                currentTitle: game.title,
                proposedTitle: proposed
            )
        }

        NormalizeTitlePreviewSheet(
            rows: rows,
            onConfirm: { changingRows in
                applyNormalization(rows: changingRows)
            },
            onCancel: {
                gamesViewModel.showNormalizeTitlePreview = false
            }
        )
    }

    // MARK: - Realm write via ROMTitleNormalizationService

    private func applyNormalization(rows: [NormalizeTitlePreviewRow]) {
        // Convert preview rows to ROMTitleRenameProposal for the shared service.
        // The service runs writes on a background Realm context to avoid
        // blocking the main thread during a large batch rename.
        let proposals = rows.map {
            ROMTitleRenameProposal(id: $0.id, currentTitle: $0.currentTitle, proposedTitle: $0.proposedTitle)
        }

        Task {
            do {
                let count = try await ROMTitleNormalizationService().applyProposals(proposals)
                await MainActor.run {
                    gamesViewModel.showNormalizeTitlePreview = false
                    gamesViewModel.exitMultiSelectMode()
                    rootDelegate?.showMessage(
                        "\(count) title\(count == 1 ? "" : "s") normalized.",
                        title: "Done"
                    )
                }
            } catch {
                await MainActor.run {
                    gamesViewModel.showNormalizeTitlePreview = false
                    rootDelegate?.showMessage(
                        "Failed to normalize titles: \(error.localizedDescription)",
                        title: "Error"
                    )
                }
            }
        }
    }

    // MARK: - Batch Delete

    func performBatchDelete() {
        let selectedMD5s = gamesViewModel.selectedGameMD5s
        guard !selectedMD5s.isEmpty else { return }

        let realm = RomDatabase.sharedInstance.realm
        var failedTitles: [String] = []
        var deletedCount = 0

        for md5 in selectedMD5s {
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { continue }
            do {
                try RomDatabase.sharedInstance.delete(game: game, deleteSaves: false)
                deletedCount += 1
            } catch {
                failedTitles.append(game.title)
                ELOG("Failed to delete game \(game.title): \(error)")
            }
        }

        gamesViewModel.exitMultiSelectMode()

        if failedTitles.isEmpty {
            rootDelegate?.showMessage(
                "Deleted \(deletedCount) game\(deletedCount == 1 ? "" : "s").",
                title: "Deleted"
            )
        } else {
            rootDelegate?.showMessage(
                "Deleted \(deletedCount) game\(deletedCount == 1 ? "" : "s"). Failed: \(failedTitles.joined(separator: ", "))",
                title: "Partial Delete"
            )
        }
    }

    // MARK: - Batch Move to System

    func performBatchMove(to system: PVSystem) {
        let selectedMD5s = gamesViewModel.selectedGameMD5s
        guard !selectedMD5s.isEmpty else { return }

        let realm = RomDatabase.sharedInstance.realm
        var movedCount = 0
        var failedTitles: [String] = []

        for md5 in selectedMD5s {
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { continue }

            // Skip games already on this system
            if game.systemIdentifier == system.identifier { continue }

            do {
                guard let sourceURL = PVEmulatorConfiguration.path(forGame: game) else {
                    failedTitles.append(game.title)
                    continue
                }
                let destinationURL = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: system.identifier)
                    .appendingPathComponent(sourceURL.lastPathComponent)

                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

                try realm.write {
                    let thawedGame = game.thaw()
                    thawedGame?.system = system
                    thawedGame?.systemIdentifier = system.identifier
                    // Update ROM path
                    let newRelativePath = "\(system.identifier)/\(sourceURL.lastPathComponent)"
                    thawedGame?.romPath = newRelativePath
                }
                movedCount += 1
            } catch {
                failedTitles.append(game.title)
                ELOG("Failed to move game \(game.title): \(error)")
            }
        }

        gamesViewModel.exitMultiSelectMode()

        if failedTitles.isEmpty {
            rootDelegate?.showMessage(
                "Moved \(movedCount) game\(movedCount == 1 ? "" : "s") to \(system.name).",
                title: "Moved"
            )
        } else {
            rootDelegate?.showMessage(
                "Moved \(movedCount), failed \(failedTitles.count): \(failedTitles.joined(separator: ", "))",
                title: "Partial Move"
            )
        }
    }

    // MARK: - Batch Offload

    func performBatchOffload() {
        let selectedMD5s = gamesViewModel.selectedGameMD5s
        guard !selectedMD5s.isEmpty else { return }

        Task {
            let realm = RomDatabase.sharedInstance.realm
            var offloadedCount = 0
            var failedTitles: [String] = []

            for md5 in selectedMD5s {
                guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                        ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { continue }
                guard game.cloudRecordID != nil, game.isDownloaded else { continue }

                do {
                    if let url = game.file?.url, FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try await RomDatabase.sharedInstance.asyncWriteTransaction {
                        if let thawed = game.thaw() {
                            thawed.isDownloaded = false
                            thawed.file = nil
                        }
                    }
                    offloadedCount += 1
                } catch {
                    failedTitles.append(game.title)
                    ELOG("Failed to offload game \(game.title): \(error)")
                }
            }

            await MainActor.run {
                gamesViewModel.exitMultiSelectMode()
                if failedTitles.isEmpty {
                    rootDelegate?.showMessage(
                        "Offloaded \(offloadedCount) game\(offloadedCount == 1 ? "" : "s") from this device.",
                        title: "Offloaded"
                    )
                } else {
                    rootDelegate?.showMessage(
                        "Offloaded \(offloadedCount), failed \(failedTitles.count): \(failedTitles.joined(separator: ", "))",
                        title: "Partial Offload"
                    )
                }
            }
        }
    }

    // MARK: - Batch Download

    func performBatchDownload() {
        let selectedMD5s = gamesViewModel.selectedGameMD5s
        guard !selectedMD5s.isEmpty else { return }

        let realm = RomDatabase.sharedInstance.realm
        var gamesToDownload: [(recordID: String, md5: String, title: String)] = []

        for md5 in selectedMD5s {
            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
                    ?? realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else { continue }
            guard let recordID = game.cloudRecordID, !game.isDownloaded else { continue }
            gamesToDownload.append((recordID: recordID, md5: game.md5Hash, title: game.title))
        }

        gamesViewModel.exitMultiSelectMode()

        guard !gamesToDownload.isEmpty else { return }

        rootDelegate?.showMessage(
            "Downloading \(gamesToDownload.count) game\(gamesToDownload.count == 1 ? "" : "s") from Cloud…",
            title: "Downloading"
        )

        Task {
            guard let syncer = CloudKitSyncerStore.shared.getSyncer() else {
                await MainActor.run {
                    rootDelegate?.showMessage("No CloudKit syncer available.", title: "Error")
                }
                return
            }

            var downloadedCount = 0
            var failedTitles: [String] = []

            for game in gamesToDownload {
                do {
                    let _ = try await syncer.downloadFileOnDemand(recordName: game.recordID)
                    try await updateGameDownloadStatus(recordID: game.recordID, isDownloaded: true)
                    downloadedCount += 1
                } catch {
                    failedTitles.append(game.title)
                    ELOG("Failed to download game \(game.title): \(error)")
                }
            }

            await MainActor.run {
                if failedTitles.isEmpty {
                    rootDelegate?.showMessage(
                        "Downloaded \(downloadedCount) game\(downloadedCount == 1 ? "" : "s").",
                        title: "Done"
                    )
                } else {
                    rootDelegate?.showMessage(
                        "Downloaded \(downloadedCount), failed \(failedTitles.count): \(failedTitles.joined(separator: ", "))",
                        title: "Partial Download"
                    )
                }
            }
        }
    }

    // MARK: - Batch Move Sheet

    @ViewBuilder
    var batchMoveToSystemSheet: some View {
        let systems = PVEmulatorConfiguration.systems.filter {
            !(AppState.shared.isAppStore && $0.appStoreDisabled)
        }
        NavigationStack {
            List {
                ForEach(systems) { system in
                    Button {
                        gamesViewModel.showBatchMoveToSystem = false
                        performBatchMove(to: system)
                    } label: {
                        HStack {
                            Text(system.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(system.shortName)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Move \(gamesViewModel.selectedGameMD5s.count) Game\(gamesViewModel.selectedGameMD5s.count == 1 ? "" : "s") to…")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        gamesViewModel.showBatchMoveToSystem = false
                    }
                }
            }
        }
    }
}
#endif
