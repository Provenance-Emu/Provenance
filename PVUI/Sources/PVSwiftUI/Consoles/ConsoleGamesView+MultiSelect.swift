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
            }
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
}
#endif
