//
//  AllSaveStatesBrowserView.swift
//  PVUI
//
//  Created by Claude on 2026-03-13.
//

#if canImport(SwiftUI)
import SwiftUI
import PVLibrary
import PVRealm
import PVUIBase
import PVThemes
import PVLogging

/// Sort options for the all-saves browser
enum SaveStatesBrowserSort: String, CaseIterable, Identifiable {
    case dateDescending = "Most Recent"
    case dateAscending  = "Oldest First"
    case gameName       = "Game Name"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dateDescending: return "arrow.down.circle"
        case .dateAscending:  return "arrow.up.circle"
        case .gameName:       return "textformat.abc"
        }
    }
}

/// Full-page browser for all save states, grouped by game.
///
/// This view is shown when the user taps "Show All" in the Recent Saves
/// section header on the Home screen. It loads every save state across
/// all systems, groups them by game, and supports sorting and favourites
/// filtering. Each save state card supports a context menu with load,
/// manage, and delete actions.
@available(iOS 15, tvOS 15, *)
public struct AllSaveStatesBrowserView: View {
    @ObservedObject private var store: RetroSaveStatesStore = .shared
    @ObservedObject private var themeManager = ThemeManager.shared

    weak var rootDelegate: PVRootDelegate?

    @State private var items: [RetroSaveStateItem] = []
    @State private var isLoading = true
    @State private var sortOrder: SaveStatesBrowserSort = .dateDescending
    @State private var showFavoritesOnly = false

    #if os(tvOS)
    @FocusState private var focusedItemID: String?
    #endif

    public init(rootDelegate: PVRootDelegate?) {
        self.rootDelegate = rootDelegate
    }

    // MARK: - Derived data

    private var filteredItems: [RetroSaveStateItem] {
        showFavoritesOnly ? items.filter { $0.isFavorite } : items
    }

    private var groupedItems: [(key: String, value: [RetroSaveStateItem])] {
        let grouped = Dictionary(grouping: filteredItems, by: { $0.gameId })
        return grouped.sorted { lhs, rhs in
            switch sortOrder {
            case .dateDescending:
                let lhsDate = lhs.value.map(\.date).max() ?? .distantPast
                let rhsDate = rhs.value.map(\.date).max() ?? .distantPast
                return lhsDate > rhsDate
            case .dateAscending:
                let lhsDate = lhs.value.map(\.date).min() ?? .distantFuture
                let rhsDate = rhs.value.map(\.date).min() ?? .distantFuture
                return lhsDate < rhsDate
            case .gameName:
                let a = lhs.value.first?.gameTitle ?? ""
                let b = rhs.value.first?.gameTitle ?? ""
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
        }
    }

    // MARK: - Body

    public var body: some View {
        contentView
            .navigationTitle("All Save States")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { toolbarItems }
            .task { await loadItems() }
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            themeManager.currentPalette.gameLibraryBackground.swiftUIColor
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if groupedItems.isEmpty {
                emptyView
            } else {
                browserList
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Loading Save States…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Save States")
                .font(.title2.weight(.semibold))
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            Text(
                showFavoritesOnly
                    ? "You have no favourited save states."
                    : "Save states will appear here after you save your progress in a game."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }

    private var browserList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groupedItems, id: \.key) { group in
                    gameGroupSection(group: group)
                }
            }
            .padding(.vertical, 16)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    @ViewBuilder
    private func gameGroupSection(group: (key: String, value: [RetroSaveStateItem])) -> some View {
        let saves = group.value
        let gameTitle  = saves.first?.gameTitle  ?? "Unknown Game"
        let systemName = saves.first?.systemName ?? ""

        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gameTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .lineLimit(1)
                    if !systemName.isEmpty {
                        Text(systemName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("\(saves.count) save\(saves.count == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))

                Button {
                    manageGame(gameId: group.key)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                .focusable()
                #endif
            }
            .padding(.horizontal, 16)

            // Horizontal strip of save state cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(saves) { item in
                        saveCard(for: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                #if os(tvOS)
                .focusSection()
                #endif
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func saveCard(for item: RetroSaveStateItem) -> some View {
        Button {
            Task { await store.openSaveState(id: item.id) }
        } label: {
            RetroSaveStateCard(
                item: item,
                store: store,
                isFocused: {
                    #if os(tvOS)
                    return focusedItemID == item.id
                    #else
                    return false
                    #endif
                }()
            ) {
                Task { await store.openSaveState(id: item.id) }
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        .focused($focusedItemID, equals: item.id)
        #else
        .buttonStyle(.plain)
        #endif
        .contextMenu {
            Button {
                Task { await store.openSaveState(id: item.id) }
            } label: {
                Label("Load Save State", systemImage: "play.fill")
            }

            Button {
                manageGame(gameId: item.gameId)
            } label: {
                Label("Manage Save States", systemImage: "ellipsis.circle")
            }

            Divider()

            Button(role: .destructive) {
                deleteSaveState(item: item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // Favourites filter toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFavoritesOnly.toggle()
                }
            } label: {
                Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                    .foregroundColor(showFavoritesOnly ? .red : .secondary)
            }

            // Sort menu
            Menu {
                ForEach(SaveStatesBrowserSort.allCases) { sort in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOrder = sort
                        }
                    } label: {
                        if sortOrder == sort {
                            Label(sort.rawValue, systemImage: "checkmark")
                        } else {
                            Label(sort.rawValue, systemImage: sort.systemImage)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }

    // MARK: - Actions

    private func manageGame(gameId: String) {
        Task { @MainActor in
            guard let game = RomDatabase.sharedInstance.object(ofType: PVGame.self, wherePrimaryKeyEquals: gameId) else {
                ELOG("AllSaveStatesBrowserView: Game not found for id: \(gameId)")
                return
            }
            rootDelegate?.root_showContinuesManagement(game)
        }
    }

    private func deleteSaveState(item: RetroSaveStateItem) {
        Task { @MainActor in
            guard let saveState = RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: item.id) else {
                ELOG("AllSaveStatesBrowserView: Save state not found for id: \(item.id)")
                return
            }
            let systemId = saveState.game?.systemIdentifier ?? ""
            do {
                try RomDatabase.sharedInstance.delete(saveState: saveState)
                store.removeFromCache(id: item.id, systemID: systemId)
                // Reload after deletion
                await loadItems()
            } catch {
                ELOG("AllSaveStatesBrowserView: Failed to delete save state: \(error)")
            }
        }
    }

    private func loadItems() async {
        isLoading = true
        items = await store.loadAllRecent(limit: 500)
        isLoading = false
    }
}
#endif
