//
//  SaveStateBrowserView.swift
//  PVUI
//
//  Created by Claude Code on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Full-page save state browser: all games with save states,
//  grouped by game title, with expand/collapse per game.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVLogging

// MARK: - Data Models

/// Lightweight snapshot of a PVSaveState for UI use, decoupled from Realm.
private struct SaveStateBrowserItem: Identifiable {
    let id: String
    let date: Date
    let isAutosave: Bool
    let coreVersion: String?
    let screenshotURL: URL?
    /// Resolves the live Realm object on demand (e.g. for launch/delete).
    let resolver: () -> PVSaveState?

    init(saveState: PVSaveState) {
        let snap = saveState.isFrozen ? saveState : saveState.freeze()
        self.id = snap.id
        self.date = snap.date
        self.isAutosave = snap.isAutosave
        self.coreVersion = snap.createdWithCoreVersion
        self.screenshotURL = snap.image?.url
        let pk = snap.id
        self.resolver = {
            RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: pk)
        }
    }
}

/// A group of save states belonging to a single game.
private struct SaveStateGameGroup: Identifiable {
    let id: String              // game primary key
    let gameTitle: String
    let artworkURL: URL?        // local file URL for artwork (may be nil)
    let systemShortName: String?
    var items: [SaveStateBrowserItem]
}

// MARK: - Main View

/// Full-page save state browser that lists all games with save states,
/// grouped by game title. Each game row can be expanded to see its
/// individual save states.
///
/// Accessible from the main app via the "Save States" tab in RetroMainView.
public struct SaveStateBrowserView: View {

    @ObservedResults(
        PVSaveState.self,
        filter: NSPredicate(format: "game != nil AND game.system != nil"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) private var allSaveStates

    @State private var showAutosaves: Bool = false
    @State private var expandedGameIDs: Set<String> = []
    @State private var searchText: String = ""

    @ObservedObject private var themeManager = ThemeManager.shared

    public init() {}

    // MARK: - Computed Groups

    private var groups: [SaveStateGameGroup] {
        var dict: [String: SaveStateGameGroup] = [:]
        var order: [String] = []

        for state in allSaveStates {
            guard !state.isInvalidated,
                  let game = state.game, !game.isInvalidated else { continue }

            // Filter autosaves unless toggle is on
            if !showAutosaves && state.isAutosave { continue }

            // Search filter (applied to game title)
            if !searchText.isEmpty {
                guard game.title.localizedCaseInsensitiveContains(searchText) else { continue }
            }

            let gameID = game.id
            let item = SaveStateBrowserItem(saveState: state)

            if dict[gameID] != nil {
                dict[gameID]!.items.append(item)
            } else {
                order.append(gameID)
                dict[gameID] = SaveStateGameGroup(
                    id: gameID,
                    gameTitle: game.title,
                    artworkURL: game.originalArtworkFile?.url,
                    systemShortName: game.system?.shortName,
                    items: [item]
                )
            }
        }

        // Sort alphabetically by game title
        return order
            .compactMap { dict[$0] }
            .sorted { $0.gameTitle.localizedCaseInsensitiveCompare($1.gameTitle) == .orderedAscending }
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            Group {
                if groups.isEmpty {
                    emptyStateView
                } else {
                    gameList
                }
            }
            .navigationTitle("Save States")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    autosaveToggleButton
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    autosaveToggleButton
                }
            }
            #endif
            #if os(iOS)
            .searchable(text: $searchText, prompt: "Search games…")
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private var autosaveToggleButton: some View {
        Button {
            withAnimation { showAutosaves.toggle() }
        } label: {
            Label(
                showAutosaves ? "Hide Autosaves" : "Show Autosaves",
                systemImage: showAutosaves ? "clock.arrow.circlepath" : "clock"
            )
            .labelStyle(.iconOnly)
        }
        .foregroundColor(showAutosaves
            ? (themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor)
            : .secondary
        )
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No Save States")
                .font(.title2.weight(.semibold))

            Text(showAutosaves
                ? "You haven't created any save states yet."
                : "No manual save states found. Tap the clock icon to include autosaves.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var gameList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    if expandedGameIDs.contains(group.id) {
                        ForEach(group.items) { item in
                            SaveStateBrowserItemRow(
                                item: item,
                                gameTitle: group.gameTitle
                            )
                        }
                    }
                } header: {
                    SaveStateBrowserGameHeader(
                        group: group,
                        isExpanded: expandedGameIDs.contains(group.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedGameIDs.contains(group.id) {
                                expandedGameIDs.remove(group.id)
                            } else {
                                expandedGameIDs.insert(group.id)
                            }
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.grouped)
        #endif
    }
}

// MARK: - Game Section Header

private struct SaveStateBrowserGameHeader: View {
    let group: SaveStateGameGroup
    let isExpanded: Bool
    let onTap: () -> Void

    private static let thumbnailSize: CGFloat = 44

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Game artwork thumbnail
                CachedAsyncImageView(
                    url: group.artworkURL,
                    fallbackImage: UIImage.missingArtworkImage(
                        gameTitle: group.gameTitle,
                        ratio: 1
                    ),
                    height: Self.thumbnailSize,
                    zoomFactor: 1.0
                )
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .cornerRadius(6)
                .clipped()

                // Game info
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.gameTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let system = group.systemShortName {
                            Text(system)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        let count = group.items.count
                        Text("\(count) save\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save State Row

private struct SaveStateBrowserItemRow: View {
    let item: SaveStateBrowserItem
    let gameTitle: String

    @State private var showDeleteAlert: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Screenshot thumbnail
            CachedAsyncImageView(
                url: item.screenshotURL,
                fallbackImage: UIImage.missingArtworkImage(gameTitle: "Save State", ratio: 1.78),
                height: 48,
                zoomFactor: 1.0
            )
            .frame(width: 85, height: 48)
            .cornerRadius(4)
            .clipped()

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFormatter.string(from: item.date))
                    .font(.subheadline)
                    .lineLimit(1)

                if let version = item.coreVersion {
                    Text("Core v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if item.isAutosave {
                    Label("Autosave", systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Play button
            Button {
                if let state = item.resolver() {
                    SceneCoordinator.shared.launchSaveState(
                        state.freeze(),
                        core: state.core?.freeze()
                    )
                }
            } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(.accentColor)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .uiKitAlert(
            "Delete Save State",
            message: "Delete this save state for \(gameTitle)?",
            isPresented: $showDeleteAlert,
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            UIAlertAction(title: "Delete", style: .destructive) { _ in
                if let state = RomDatabase.sharedInstance.object(
                    ofType: PVSaveState.self,
                    wherePrimaryKeyEquals: item.id
                ) {
                    do {
                        try RomDatabase.sharedInstance.delete(saveState: state)
                    } catch {
                        ELOG("SaveStateBrowserView: Failed to delete save state: \(error)")
                    }
                }
                showDeleteAlert = false
            }
            UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                showDeleteAlert = false
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Save State Browser") {
    SaveStateBrowserView()
}
#endif
