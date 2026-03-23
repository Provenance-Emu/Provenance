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
private enum SaveStatesBrowserSort: String, CaseIterable, Identifiable {
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

    // MARK: - Pagination
    private static let pageSize = 100

    @State private var items: [RetroSaveStateItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentOffset = 0
    @State private var sortOrder: SaveStatesBrowserSort = .dateDescending
    @State private var showFavoritesOnly = false

    // MARK: - Export
    /// URL of the zip produced by `exportGame(gameId:)`; non-nil triggers the share sheet.
    @State private var exportShareURL: URL? = nil
    /// gameId currently being packaged; used to show a progress indicator on the export button.
    @State private var exportingGameId: String? = nil

    /// Paging is only used for the default date-descending view without a favourites filter.
    /// Other sorts and the favourites filter require the full dataset to be correct,
    /// so we fall back to loading everything at once.
    private var shouldUsePaging: Bool {
        sortOrder == .dateDescending && !showFavoritesOnly
    }

    #if os(tvOS)
    @FocusState private var focusedItemID: String?
    #endif

    public init(rootDelegate: PVRootDelegate?) {
        self.rootDelegate = rootDelegate
    }

    /// Preview-only initialiser — injects items directly so previews don't
    /// need a running Realm database.
    #if DEBUG
    init(previewItems: [RetroSaveStateItem], isLoading: Bool = false) {
        self.rootDelegate = nil
        self._items = State(initialValue: previewItems)
        self._isLoading = State(initialValue: isLoading)
    }
    #endif

    // MARK: - Derived data

    @State private var groupedItemsCache: [(key: String, value: [RetroSaveStateItem])] = []

    private var filteredItems: [RetroSaveStateItem] {
        showFavoritesOnly ? items.filter { $0.isFavorite } : items
    }

    private var groupedItems: [(key: String, value: [RetroSaveStateItem])] {
        groupedItemsCache
    }

    private func recomputeGroupedItems() {
        let sourceItems = filteredItems
        let grouped = Dictionary(grouping: sourceItems, by: { $0.gameId })

        // Precompute per-group metadata so the sort comparator is O(1) per comparison.
        var metadata = [String: (newest: Date, oldest: Date, title: String)]()
        metadata.reserveCapacity(grouped.count)

        for (key, items) in grouped {
            let dates = items.map(\.date)
            let newest = dates.max() ?? .distantPast
            let oldest = dates.min() ?? .distantFuture
            let title = items.first?.gameTitle ?? ""
            metadata[key] = (newest: newest, oldest: oldest, title: title)
        }

        groupedItemsCache = grouped.sorted { lhs, rhs in
            guard let lhsMeta = metadata[lhs.key],
                  let rhsMeta = metadata[rhs.key] else {
                // Fallback to key-based ordering if metadata is missing for any reason.
                return lhs.key < rhs.key
            }

            switch sortOrder {
            case .dateDescending:
                return lhsMeta.newest > rhsMeta.newest
            case .dateAscending:
                return lhsMeta.oldest < rhsMeta.oldest
            case .gameName:
                return lhsMeta.title.localizedCaseInsensitiveCompare(rhsMeta.title) == .orderedAscending
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
            .task {
                #if DEBUG
                // Skip live load when items were injected by the preview initialiser
                guard items.isEmpty else { return }
                #endif
                await loadItems()
                recomputeGroupedItems()
            }
            .onChange(of: items) { _ in
                recomputeGroupedItems()
            }
            .onChange(of: sortOrder) { _ in
                // Re-sort what's already loaded immediately for responsiveness, then
                // reload from the store in case the new sort needs a different fetch order
                // (e.g. Oldest First requires ascending DB queries, not just group reordering).
                recomputeGroupedItems()
                Task { await loadItems() }
            }
            .onChange(of: showFavoritesOnly) { _ in
                // Favourites filter requires the full dataset so the user doesn't see
                // "no favourites" when they simply haven't been loaded yet.
                Task { await loadItems() }
            }
            #if canImport(UIKit) && !os(tvOS)
            .sheet(isPresented: Binding<Bool>(
                get: { exportShareURL != nil },
                set: { presenting in
                    if !presenting {
                        if let url = exportShareURL {
                            SaveExporter.shared.cleanupExport(at: url)
                        }
                        exportShareURL = nil
                    }
                }
            )) {
                if let url = exportShareURL {
                    ActivityViewController(activityItems: [url])
                } else {
                    Color.clear.onAppear { exportShareURL = nil }
                }
            }
            #endif
    }

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            themeManager.currentPalette.gameLibraryBackground.swiftUIColor
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if groupedItems.isEmpty && !hasMorePages && !isLoadingMore {
                emptyView
            } else if groupedItems.isEmpty && isLoadingMore {
                loadingView
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

                // Pagination sentinel — loads the next page when this row
                // scrolls into view, providing seamless infinite scroll.
                if hasMorePages {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 12)
                        }
                        Spacer()
                    }
                    .onAppear {
                        guard !isLoadingMore else { return }
                        Task { await loadNextPage() }
                    }
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

                #if canImport(UIKit) && !os(tvOS)
                Button {
                    exportGame(gameId: group.key)
                } label: {
                    if exportingGameId == group.key {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(exportingGameId != nil)
                #endif

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
        .onDrag {
            // Provide the save state file for drag to Files / AirDrop.
            // Realm access is safe here: onDrag is called on the main thread.
            guard let saveState = RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: item.id),
                  let fileURL = saveState.file?.url else {
                return NSItemProvider()
            }
            return NSItemProvider(contentsOf: fileURL) ?? NSItemProvider()
        }
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
            // gameId is PVGame.id (UUID), not the Realm primary key (md5Hash) — use filter.
            guard let game = RomDatabase.sharedInstance.realm
                    .objects(PVGame.self)
                    .filter("id == %@", gameId)
                    .first else {
                ELOG("AllSaveStatesBrowserView: Game not found for id: \(gameId)")
                return
            }
            rootDelegate?.root_showContinuesManagement(game)
        }
    }

    #if canImport(UIKit) && !os(tvOS)
    /// Exports all saves for the given game as a zip and presents the system share sheet.
    ///
    /// `gameId` is `PVGame.id` (UUID), not the Realm primary key (`md5Hash`), so we use a
    /// filter predicate rather than `forPrimaryKey`.
    private func exportGame(gameId: String) {
        guard exportingGameId == nil else { return }
        exportingGameId = gameId
        Task { @MainActor in
            defer { exportingGameId = nil }
            guard let game = RomDatabase.sharedInstance.realm
                    .objects(PVGame.self)
                    .filter("id == %@", gameId)
                    .first else {
                ELOG("AllSaveStatesBrowserView: Game not found for export, id: \(gameId)")
                return
            }
            do {
                let url = try await SaveExporter.shared.exportSaves(for: game)
                exportShareURL = url
            } catch {
                ELOG("AllSaveStatesBrowserView: Export failed: \(error.localizedDescription)")
            }
        }
    }
    #endif

    private func deleteSaveState(item: RetroSaveStateItem) {
        Task { @MainActor in
            guard let saveState = RomDatabase.sharedInstance.object(ofType: PVSaveState.self, wherePrimaryKeyEquals: item.id) else {
                ELOG("AllSaveStatesBrowserView: Save state not found for id: \(item.id)")
                return
            }
            let systemId: String
            if !item.systemId.isEmpty {
                systemId = item.systemId
            } else if let derivedSystemId = saveState.game?.systemIdentifier, !derivedSystemId.isEmpty {
                systemId = derivedSystemId
            } else {
                ELOG("AllSaveStatesBrowserView: Missing system identifier for save state id: \(item.id)")
                systemId = ""
            }
            do {
                try RomDatabase.sharedInstance.delete(saveState: saveState)
                store.removeFromCache(id: item.id, systemID: systemId)
                // Remove from local list immediately for snappy UI, then reload for consistency
                items.removeAll { $0.id == item.id }
                recomputeGroupedItems()
            } catch {
                ELOG("AllSaveStatesBrowserView: Failed to delete save state: \(error)")
            }
        }
    }

    /// Loads the first page (or all items) and resets pagination state.
    ///
    /// Paging is only used when `sortOrder == .dateDescending` and `showFavoritesOnly` is off.
    /// Other configurations load the full dataset so sort/filter correctness is guaranteed.
    private func loadItems() async {
        isLoading = true
        currentOffset = 0

        if shouldUsePaging {
            hasMorePages = true
            let page = await store.loadPage(offset: 0, pageSize: Self.pageSize, ascending: false)
            items = page
            hasMorePages = page.count == Self.pageSize
            currentOffset = page.count
        } else {
            // Load everything; sort is applied client-side by recomputeGroupedItems().
            hasMorePages = false
            items = await store.loadAll()
            if sortOrder == .dateAscending {
                items.sort { $0.date < $1.date }
            }
        }

        isLoading = false
    }

    /// Appends the next page of results (called when the scroll sentinel appears).
    /// Only invoked when `shouldUsePaging` is true.
    private func loadNextPage() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true
        let page = await store.loadPage(offset: currentOffset, pageSize: Self.pageSize, ascending: false)
        items.append(contentsOf: page)
        currentOffset += page.count
        hasMorePages = page.count == Self.pageSize
        isLoadingMore = false
    }
}

// MARK: - Previews

#if DEBUG
private extension RetroSaveStateItem {
    /// Builds a fake save-state item for SwiftUI canvas previews.
    static func mock(
        id: String = UUID().uuidString,
        gameId: String,
        gameTitle: String,
        systemId: String = "com.provenance.nes",
        systemName: String = "NES",
        date: Date = Date(),
        isFavorite: Bool = false
    ) -> RetroSaveStateItem {
        RetroSaveStateItem(
            id: id,
            gameId: gameId,
            gameTitle: gameTitle,
            systemId: systemId,
            systemName: systemName,
            date: date,
            isAutosave: false,
            isFavorite: isFavorite,
            fileSize: 32_768,
            imageURL: nil,
            coreName: "FCEUmm",
            createdWithCoreVersion: "1.0",
            coreIdentifier: "com.provenance.fceumm"
        )
    }
}

#Preview("Populated — grouped by game") {
    let now = Date()
    let items: [RetroSaveStateItem] = [
        .mock(gameId: "g1", gameTitle: "Super Mario Bros.", systemName: "NES",
              date: now.addingTimeInterval(-60)),
        .mock(gameId: "g1", gameTitle: "Super Mario Bros.", systemName: "NES",
              date: now.addingTimeInterval(-3600), isFavorite: true),
        .mock(gameId: "g1", gameTitle: "Super Mario Bros.", systemName: "NES",
              date: now.addingTimeInterval(-7200)),
        .mock(gameId: "g2", gameTitle: "Zelda II: The Adventure of Link", systemName: "NES",
              date: now.addingTimeInterval(-120)),
        .mock(gameId: "g2", gameTitle: "Zelda II: The Adventure of Link", systemName: "NES",
              date: now.addingTimeInterval(-900)),
        .mock(gameId: "g3", gameTitle: "Mega Man 2",
              systemId: "com.provenance.snes", systemName: "SNES",
              date: now.addingTimeInterval(-300), isFavorite: true),
    ]
    NavigationView {
        AllSaveStatesBrowserView(previewItems: items, isLoading: false)
    }
}

#Preview("Empty state") {
    NavigationView {
        AllSaveStatesBrowserView(previewItems: [], isLoading: false)
    }
}

#Preview("Loading state") {
    NavigationView {
        AllSaveStatesBrowserView(previewItems: [], isLoading: true)
    }
}
#endif
#endif
