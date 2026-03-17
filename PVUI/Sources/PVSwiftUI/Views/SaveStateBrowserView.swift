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
import PVLibrary
import PVMediaCache
import PVRealm
import PVThemes
import PVUIBase
import PVLogging

// MARK: - Data Models

/// A group of save states belonging to a single game.
private struct SaveStateGameGroup: Identifiable {
    let id: String              // game primary key
    let gameTitle: String
    let artworkURL: URL?        // local file URL for artwork (may be nil)
    let systemShortName: String?
    var items: [RetroSaveStateItem]
}

// MARK: - Main View

/// Full-page save state browser that lists all games with save states,
/// grouped by game title. Each game row can be expanded to see its
/// individual save states.
///
/// Data is fetched via ``RetroSaveStatesStore`` (never directly from Realm)
/// so it is forward-compatible with the planned SwiftData migration (#2510).
///
/// Accessible from the main app via the "Save States" tab in RetroMainView.
public struct SaveStateBrowserView: View {

    @ObservedObject private var store: RetroSaveStatesStore = .shared
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showAutosaves: Bool = false
    @State private var expandedGameIDs: Set<String> = []
    @State private var searchText: String = ""

    /// Pre-built group list, recomputed asynchronously on load and filter changes.
    @State private var computedGroups: [SaveStateGameGroup] = []
    /// Raw items fetched from the store — filtering/grouping is applied client-side.
    @State private var allItems: [RetroSaveStateItem] = []

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationView {
            Group {
                if computedGroups.isEmpty {
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
        .task {
            allItems = await store.loadAll()
            applyFilters()
        }
        .onChange(of: showAutosaves) { _ in applyFilters() }
        .onChange(of: searchText) { _ in applyFilters() }
    }

    // MARK: - Data Helpers

    /// Filters and groups `allItems` client-side, then stores the result.
    ///
    /// Runs on the MainActor synchronously so SwiftUI picks up the change
    /// immediately. RomDatabase artwork lookups are main-thread safe.
    @MainActor
    private func applyFilters() {
        var dict: [String: SaveStateGameGroup] = [:]
        var order: [String] = []

        for item in allItems {
            if !showAutosaves && item.isAutosave { continue }
            if !searchText.isEmpty {
                guard item.gameTitle.localizedCaseInsensitiveContains(searchText) else { continue }
            }

            if dict[item.gameId] != nil {
                dict[item.gameId]!.items.append(item)
            } else {
                order.append(item.gameId)
                // Resolve artwork URL for this game.
                // 1. Prefer originalArtworkFile.url — the local cached copy when set.
                // 2. Fall back to PVMediaCache lookup via trueArtworkURL for legacy games
                //    that have only originalArtworkURL (openvgdb URL) and no file entry.
                let artworkURL: URL? = {
                    guard let game = RomDatabase.sharedInstance
                        .object(ofType: PVGame.self, wherePrimaryKeyEquals: item.gameId)
                    else { return nil }
                    if let fileURL = game.originalArtworkFile?.url {
                        return fileURL
                    }
                    let key = game.trueArtworkURL
                    guard !key.isEmpty,
                          PVMediaCache.fileExists(forKey: key),
                          let localURL = PVMediaCache.filePath(forKey: key)
                    else { return nil }
                    return localURL
                }()
                dict[item.gameId] = SaveStateGameGroup(
                    id: item.gameId,
                    gameTitle: item.gameTitle,
                    artworkURL: artworkURL,
                    systemShortName: item.systemName.isEmpty ? nil : item.systemName,
                    items: [item]
                )
            }
        }

        computedGroups = order
            .compactMap { dict[$0] }
            .sorted { $0.gameTitle.localizedCaseInsensitiveCompare($1.gameTitle) == .orderedAscending }
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
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)

                Text("No Results")
                    .font(.title2.weight(.semibold))

                Text("No save states match your search.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var gameList: some View {
        List {
            ForEach(computedGroups) { group in
                Section {
                    if expandedGameIDs.contains(group.id) {
                        ForEach(group.items) { item in
                            SaveStateBrowserItemRow(
                                item: item,
                                gameTitle: group.gameTitle,
                                onDeleted: {
                                    // Remove from allItems and recompute
                                    allItems.removeAll { $0.id == item.id }
                                    applyFilters()
                                }
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
    let item: RetroSaveStateItem
    let gameTitle: String
    let onDeleted: () -> Void

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
                url: item.imageURL,
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

                if let version = item.createdWithCoreVersion {
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

            // Play button — launch via the store (DB-layer, not raw Realm)
            Button {
                Task { await RetroSaveStatesStore.shared.openSaveState(id: item.id) }
            } label: {
                Image(systemName: "play.fill")
                    .foregroundColor(.accentColor)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        #if !os(tvOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
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
                        RetroSaveStatesStore.shared.removeFromCache(id: item.id, systemID: item.systemId)
                        onDeleted()
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
