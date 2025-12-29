import SwiftUI
import PVUIBase
import PVThemes
import PVLibrary
import RealmSwift
import PVRealm

#if os(tvOS)

@available(tvOS 16.0, *)
struct TVMediaMainView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appDelegate: PVAppDelegate

    @AppStorage("TVMediaUI.lastDestination") private var lastDestinationRaw: String = TVMediaDestination.home.rawValue
    @AppStorage("TVMediaUI.lastSystemIdentifier") private var lastSystemIdentifier: String = ""

    @StateObject private var focusCoordinator = TVMediaFocusCoordinator()
    @StateObject private var router = TVMediaRouter()
    @StateObject private var libraryModel = TVMediaLibraryModel()
    @StateObject private var saveStatesStore = RetroSaveStatesStore.shared
    @StateObject private var gameActions = TVMediaGameActions()

    @ObservedObject private var syncStatusManager = SceneCoordinator.shared.syncStatusManager

    init() {}

    /// Sidebar collapsed width for content padding
    private let sidebarCollapsedWidth: CGFloat = 80

    @Namespace private var mainNamespace
    @Namespace private var sidebarNamespace
    @Environment(\.resetFocus) private var resetFocus

    /// Convenience flag for modal rename alert
    private var isRenamePresented: Bool {
        gameActions.renameGame != nil
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            TVMediaBackground()
                .ignoresSafeArea()

            // Content area - wrapped in focusable container for empty pages
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, sidebarCollapsedWidth)
                .allowsHitTesting(!focusCoordinator.isAlertPresented && !isRenamePresented)
                .disabled(focusCoordinator.isAlertPresented || isRenamePresented)
                .animation(.easeInOut(duration: 0.25), value: router.destination)
                .focusSection()
                .focusScope(mainNamespace)
                .prefersDefaultFocus(!focusCoordinator.isSidebarExpanded, in: mainNamespace)

            // Sidebar
            TVMediaSidebarRail(
                destination: $router.destination,
                focusCoordinator: focusCoordinator,
                router: router,
                onSelectSettings: {
                    router.navigate(to: .settings)
                },
                onSelectStatus: {
                    router.navigate(to: .status)
                },
                onSelectImports: {
                    router.activeModal = .importStatus
                }
            )
            .focusScope(sidebarNamespace)
            .prefersDefaultFocus(focusCoordinator.isSidebarExpanded, in: sidebarNamespace)
            .allowsHitTesting(!focusCoordinator.isAlertPresented && !isRenamePresented)
            .disabled(!focusCoordinator.isSidebarExpanded || isRenamePresented)

            overlays
        }
        .environment(\.tvMediaFocusCoordinator, focusCoordinator)
        .onAppear {
            gameActions.appState = appState
            router.destination = TVMediaDestination(rawValue: lastDestinationRaw) ?? .home
            router.selectedSystemID = lastSystemIdentifier
            libraryModel.startObservingLibraryChanges()
            libraryModel.refresh()
            if !lastSystemIdentifier.isEmpty {
                libraryModel.selectSystem(identifier: lastSystemIdentifier)
            }
        }
        .onChange(of: router.destination) { newValue in
            lastDestinationRaw = newValue.rawValue
            // Close sidebar when navigating
            focusCoordinator.closeSidebar()
        }
        .onChange(of: focusCoordinator.isSidebarExpanded) { expanded in
            // Reset focus to the appropriate namespace when sidebar state changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if expanded {
                    resetFocus(in: sidebarNamespace)
                } else {
                    resetFocus(in: mainNamespace)
                }
            }
        }
        .onChange(of: router.selectedSystemID) { newValue in
            lastSystemIdentifier = newValue
            libraryModel.selectSystem(identifier: newValue)
        }
        .onChange(of: gameActions.systemPickerGame) { newValue in
            // Present the Move to System picker when requested from context menu
            if let game = newValue {
                router.activeModal = .systemPicker(game: game)
            } else if case .systemPicker = router.activeModal {
                router.dismissModal()
            }
        }
        .onExitCommand {
            // Menu/Back button: close rename/alerts first, then sidebar
            if isRenamePresented {
                gameActions.clearRename()
                return
            }
            if focusCoordinator.isAlertPresented || focusCoordinator.isModalPresented {
                return
            }
            focusCoordinator.toggleSidebar()
        }
        .sheet(item: $router.activeModal) { modal in
            modalContent(for: modal)
        }
        .retroAlert(
            "Rename Game",
            message: "Enter a new name for \(gameActions.renameGame?.title ?? "")",
            isPresented: Binding(
                get: { gameActions.renameGame != nil },
                set: { if !$0 { gameActions.clearRename() } }
            ),
            textFieldBinding: Binding<String?>(
                get: { gameActions.renameText },
                set: { gameActions.renameText = $0 ?? "" }
            ),
            textFieldConfiguration: { textField in
                textField.placeholder = "Game name"
                textField.clearButtonMode = .whileEditing
                textField.autocapitalizationType = .words
            }
        ) {
            VStack(spacing: 10) {
                RetroButton(title: "Save", isPrimary: true) {
                    Task { await gameActions.commitRenameIfPossible() }
                }
                RetroButton(title: "Cancel", isPrimary: false) {
                    gameActions.clearRename()
                }
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.all)
        .hideHomeIndicator()
        .onChange(of: gameActions.renameGame) { newValue in
            // Treat rename alert as a blocking alert for focus and hit testing
            focusCoordinator.isAlertPresented = (newValue != nil)
            // When showing, push focus to sidebar off
            if newValue != nil {
                resetFocus(in: mainNamespace)
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch router.destination {
            case .home:
                TVMediaHomeView(
                    model: libraryModel,
                    saveStatesStore: saveStatesStore,
                    gameActions: gameActions,
                    router: router
                )
            case .system:
                TVMediaSystemsView(
                    model: libraryModel,
                    router: router
                )
                .transition(.opacity)
            case .systemGames:
                if let system = libraryModel.selectedSystem {
                    TVMediaSystemGamesView(
                        system: system,
                        model: libraryModel,
                        saveStatesStore: saveStatesStore,
                        gameActions: gameActions,
                        router: router
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                } else {
                    TVMediaEmptyStateView(
                        title: "Select a System",
                        subtitle: "Choose a system to browse games."
                    )
                }
            case .search:
                TVMediaSearchView(
                    model: libraryModel,
                    gameActions: gameActions
                )
            case .favorites:
                TVMediaFavoritesView(
                    model: libraryModel,
                    gameActions: gameActions
                )
            case .saves:
                TVMediaSavesView(
                    model: libraryModel,
                    saveStatesStore: saveStatesStore
                )
            case .settings:
                // Settings view handles its own sidebar commands via tvMediaFocusCoordinator environment
                SettingsWrapperView()
                    .onAppear {
                        focusCoordinator.closeSidebar()
                    }
            case .status:
                RetroStatusControlView()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var overlays: some View {
        // Import status toaster - bottom right
        if let gameImporter = appState.gameImporter,
           let updatesController = appState.libraryUpdatesController {
            TVMediaImportStatusToaster(
                gameImporter: gameImporter,
                updatesController: updatesController,
                onTap: {
                    router.activeModal = .importQueue
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 40)
            .padding(.bottom, 40)
        }

        if syncStatusManager.isVisible {
            GameSyncStatusView(
                gameTitle: syncStatusManager.gameTitle,
                statusMessage: syncStatusManager.statusMessage,
                isComplete: syncStatusManager.isComplete,
                hasError: syncStatusManager.hasError,
                onCancel: syncStatusManager.onCancel
            )
            .transition(.opacity)
            .animation(.easeInOut, value: syncStatusManager.isVisible)
        }

        // Alert overlay with focus capture
        TVMediaAlertOverlay(
            alertState: SceneCoordinator.shared.alertState,
            focusCoordinator: focusCoordinator
        )
    }

    @ViewBuilder
    private func modalContent(for modal: TVMediaModal) -> some View {
        switch modal {
        case .saveBrowser(let systemID, let systemName, let game):
            RetroSaveStatesBrowserView(
                systemID: systemID,
                systemName: systemName,
                gameFilter: game
            )
            .environmentObject(themeManager)
        case .systemPicker(let game):
            SystemPickerView(game: game, isPresented: Binding(
                get: { router.activeModal != nil },
                set: { if !$0 { router.dismissModal() } }
            ))
        case .renameGame:
            EmptyView()
        case .gameInfo:
            EmptyView()
        case .importQueue:
            if let gameImporter = appState.gameImporter,
               let updatesController = appState.libraryUpdatesController {
                TVMediaImportStatusSheet(
                    gameImporter: gameImporter,
                    updatesController: updatesController,
                    onDismiss: { router.dismissModal() }
                )
            } else {
                EmptyView()
            }
        case .importStatus:
            if let gameImporter = appState.gameImporter,
               let updatesController = appState.libraryUpdatesController {
                NavigationStack {
                    ImportStatusView(
                        updatesController: updatesController,
                        gameImporter: gameImporter,
                        delegate: nil,
                        dismissAction: { router.dismissModal() }
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
}

/// Alert overlay that properly captures focus on tvOS
@available(tvOS 16.0, *)
struct TVMediaAlertOverlay: View {
    @ObservedObject var alertState: RetroAlertState
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator

    @FocusState private var isAlertFocused: Bool

    var body: some View {
        Group {
            if alertState.isPresented {
                RetroAlertStateView(alertState: alertState)
                    .focusSection()
                    .focused($isAlertFocused)
            }
        }
        .onChange(of: alertState.isPresented) { presented in
            focusCoordinator.isAlertPresented = presented
            if presented {
                // Delay focus capture to allow view to appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isAlertFocused = true
                }
            }
        }
    }
}

// MARK: - Destination Enum

enum TVMediaDestination: String, CaseIterable {
    case home
    case system
    case systemGames
    case search
    case favorites
    case saves
    case settings
    case status

    var title: String {
        switch self {
        case .home: return "Home"
        case .system: return "Systems"
        case .systemGames: return "Games"
        case .search: return "Search"
        case .favorites: return "Favorites"
        case .saves: return "Save States"
        case .settings: return "Settings"
        case .status: return "Status"
        }
    }
}

// MARK: - Library Model

@MainActor
final class TVMediaLibraryModel: ObservableObject {
    @Published public private(set) var systems: [PVSystem] = []
    @Published public private(set) var gamesBySystemIdentifier: [String: [PVGame]] = [:]
    @Published public var selectedSystemIdentifier: String = ""
    @Published public private(set) var favoriteGamesList: [PVGame] = []

    /// Realm notifications for live updates
    private var gameToken: NotificationToken?
    private var saveStateToken: NotificationToken?
    private var recentGameToken: NotificationToken?

    /// Debounce to avoid hammering UI on rapid Realm writes
    private let refreshDebounceInterval: TimeInterval = 0.35
    private var scheduledRefresh: DispatchWorkItem?

    init() {}

    var selectedSystem: PVSystem? {
        systems.first(where: { $0.identifier == selectedSystemIdentifier })
    }

    func refresh() {
        Task {
            await loadSystems()
            await loadFavorites()
        }
    }

    func selectSystem(identifier: String) {
        selectedSystemIdentifier = identifier
        Task {
            await loadGamesForSystem(identifier: identifier)
        }
    }

    /// Begin observing Realm changes for games, save states, and recents
    func startObservingLibraryChanges() {
        guard gameToken == nil, saveStateToken == nil, recentGameToken == nil else { return }

        do {
            let realm = try Realm()

            let gamesResults = realm.objects(PVGame.self)
            gameToken = gamesResults.observe { [weak self] _ in
                self?.scheduleLibraryRefresh()
            }

            let saveStateResults = realm.objects(PVSaveState.self)
            saveStateToken = saveStateResults.observe { [weak self] _ in
                self?.scheduleLibraryRefresh()
            }

            let recentResults = realm.objects(PVRecentGame.self)
            recentGameToken = recentResults.observe { [weak self] _ in
                self?.scheduleLibraryRefresh()
            }
        } catch {
            // Safe to ignore; without Realm we just won't live-refresh
        }
    }

    deinit {
        gameToken?.invalidate()
        saveStateToken?.invalidate()
        recentGameToken?.invalidate()
        scheduledRefresh?.cancel()
    }

    private func loadSystems() async {
        let loaded: [PVSystem] = await Task.detached(priority: .userInitiated) {
            do {
                let realm = try Realm()
                let results = realm.objects(PVSystem.self)
                    .sorted(byKeyPath: "name", ascending: true)
                return Array(results).map { $0.freeze() }
            } catch {
                return []
            }
        }.value

        systems = loaded
        if selectedSystemIdentifier.isEmpty, let first = systems.first {
            selectedSystemIdentifier = first.identifier
        }
    }

    /// Debounced refresh for Realm notifications
    private func scheduleLibraryRefresh() {
        scheduledRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { await self?.refreshFromRealmChanges() }
        }
        scheduledRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + refreshDebounceInterval, execute: work)
    }

    @MainActor
    private func refreshFromRealmChanges() async {
        await loadSystems()
        await loadFavorites()

        // Reload games for already-known systems to keep shelves in sync
        let identifiers = systems.map { $0.identifier }
        for id in identifiers {
            await loadGamesForSystemAsync(identifier: id)
        }
    }

    func loadGamesForSystem(identifier: String) async {
        guard gamesBySystemIdentifier[identifier] == nil else { return }
        await loadGamesForSystemAsync(identifier: identifier)
    }

    /// Async method that always loads games (no guard)
    @MainActor
    func loadGamesForSystemAsync(identifier: String) async {
        let loaded: [PVGame] = await Task.detached(priority: .userInitiated) {
            do {
                let realm = try Realm()
                let results = realm.objects(PVGame.self)
                    .filter("systemIdentifier == %@", identifier)
                    .sorted(byKeyPath: "title", ascending: true)
                return Array(results).map { $0.freeze() }
            } catch {
                return []
            }
        }.value

        await MainActor.run {
            gamesBySystemIdentifier[identifier] = loaded
        }
    }

    func loadGamesIfNeeded(systemIdentifier: String) {
        guard gamesBySystemIdentifier[systemIdentifier] == nil else { return }
        Task {
            await loadGamesForSystem(identifier: systemIdentifier)
        }
    }

    private func loadFavorites() async {
        let loaded: [PVGame] = await Task.detached(priority: .userInitiated) {
            do {
                let realm = try Realm()
                let results = realm.objects(PVGame.self)
                    .filter("isFavorite == true")
                    .sorted(byKeyPath: "title", ascending: true)
                return Array(results.prefix(100)).map { $0.freeze() }
            } catch {
                return []
            }
        }.value

        favoriteGamesList = loaded
    }

    func favoriteGames(limit: Int = 40) -> [PVGame] {
        Array(favoriteGamesList.prefix(limit))
    }
}

// MARK: - Game Actions

final class TVMediaGameActions: ObservableObject, GameContextMenuDelegate {
    @MainActor var appState: AppState?
    @Published var saveBrowserContext: TVMediaSaveBrowserContext?
    @Published var systemPickerGame: PVGame?
    @Published var renameGame: PVGame?
    @Published var renameText: String? = nil

    private let retroModel = RetroGameLibraryViewModel()

    @MainActor
    func clearRename() {
        renameGame = nil
        renameText = nil
    }

    @MainActor
    func commitRenameIfPossible() async {
        guard let renameGame, let newName = renameText, !newName.isEmpty else {
            clearRename()
            return
        }
        await retroModel.renameGame(renameGame, to: newName)
        clearRename()
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        Task { @MainActor in
            renameGame = game.isFrozen ? game : game.freeze()
            renameText = renameGame?.title
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        Task { @MainActor in
            systemPickerGame = game.isFrozen ? game : game.freeze()
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        Task { @MainActor in
            let frozen = game.isFrozen ? game : game.freeze()
            saveBrowserContext = TVMediaSaveBrowserContext(
                systemID: frozen.systemIdentifier,
                systemName: frozen.system?.name ?? frozen.systemIdentifier,
                game: frozen
            )
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        Task { @MainActor in
            guard let appState else { return }
            retroModel.showGameInfo(gameId: gameId, appState: appState)
        }
    }
}

struct TVMediaSaveBrowserContext: Identifiable {
    let systemID: String
    let systemName: String
    let game: PVGame?
    var id: String { game?.id ?? systemID }
}

// MARK: - Empty State View

struct TVMediaEmptyStateView: View {
    let title: String
    let subtitle: String

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isFocused: Bool
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 24) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.retroPink.opacity(pulseOpacity), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "tray")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.6), Color.retroBlue.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 10)
            }

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: Color.retroPink.opacity(0.3), radius: 6)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            // Navigation hint with subtle styling
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("Swipe left or press Menu for navigation")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .focusable()
        .focused($isFocused)
        .onMoveCommand { direction in
            if direction == .left {
                focusCoordinator.openSidebar()
            }
        }
        .onAppear {
            isFocused = true
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.15
            }
        }
    }
}

// MARK: - Saves View (with empty state handling)

@available(tvOS 16.0, *)
struct TVMediaSavesView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var saveStatesStore: RetroSaveStatesStore

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isEmptyStateFocused: Bool
    @State private var allSaves: [RetroSaveStateItem] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                TVMediaTopBar(title: "Save States")

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if allSaves.isEmpty {
                    emptyState
                        .focusable()
                        .focused($isEmptyStateFocused)
                } else {
                    saveStatesGrid
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .onMoveCommand { direction in
            if direction == .left {
                focusCoordinator.openSidebar()
            }
        }
        .task {
            await loadAllSaves()
            if allSaves.isEmpty {
                isEmptyStateFocused = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("No Save States")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Play some games and create save states to see them here.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            // Navigation hint
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("Swipe left or press Menu for navigation")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }

    private var saveStatesGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 18)], spacing: 18) {
            ForEach(allSaves) { item in
                TVMediaSaveStateTileButton(item: item, store: saveStatesStore)
            }
        }
    }

    private func loadAllSaves() async {
        let saves = await saveStatesStore.loadAllRecent(limit: 100)
        await MainActor.run {
            allSaves = saves
            isLoading = false
        }
    }
}

@available(tvOS 16.0, *)
private struct TVMediaSaveStateTileButton: View {
    let item: RetroSaveStateItem
    @ObservedObject var store: RetroSaveStatesStore

    @FocusState private var isFocused: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        Button {
            Task { await store.openSaveState(id: item.id) }
        } label: {
            TVMediaSaveStateTile(
                title: item.gameTitle,
                subtitle: item.date,
                thumbnail: thumbnail,
                isFocused: isFocused,
                coreName: item.coreName.isEmpty ? nil : item.coreName
            )
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .focused($isFocused)
        .contextMenu {
            Button(role: .destructive) {
                Task { await deleteSaveState() }
            } label: {
                Label("Delete Save State", systemImage: "trash")
            }
        }
        .task {
            thumbnail = await store.thumbnail(for: item, targetSize: CGSize(width: 280, height: 180))
        }
    }

    private func deleteSaveState() async {
        await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: item.id) else { return }
            do {
                try RomDatabase.sharedInstance.delete(saveState: saveState)
            } catch {
                SceneCoordinator.shared.alertState.show(
                    title: "Delete Failed",
                    message: error.localizedDescription,
                    type: .error
                )
            }
        }
    }
}

// MARK: - Home View

@available(tvOS 16.0, *)
struct TVMediaHomeView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var saveStatesStore: RetroSaveStatesStore
    @ObservedObject var gameActions: TVMediaGameActions
    @ObservedObject var router: TVMediaRouter

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isEmptyStateFocused: Bool
    @State private var isLoading = true

    /// Check if we have any games at all
    private var hasAnyGames: Bool {
        model.gamesBySystemIdentifier.values.contains { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                TVMediaTopBar(title: "Home")

                if isLoading && model.gamesBySystemIdentifier.isEmpty {
                    // Show loading state
                    loadingView
                } else if !hasAnyGames {
                    // Empty library state
                    emptyLibraryView
                        .focusable()
                        .focused($isEmptyStateFocused)
                } else {
                    // Favorites section
                    let favorites = model.favoriteGames(limit: 40)
                    if !favorites.isEmpty {
                        TVMediaShelf(title: "Favorites", items: favorites, gameActions: gameActions)
                    }

                    // System shelves - iterate all systems, only show if they have games
                    ForEach(model.systems, id: \.identifier) { system in
                        let games = model.gamesBySystemIdentifier[system.identifier] ?? []

                        if !games.isEmpty {
                            TVMediaSystemShelfRow(
                                system: system,
                                games: games,
                                gameActions: gameActions,
                                onViewAll: {
                                    focusCoordinator.closeSidebar()
                                    router.navigateToSystem(system.identifier)
                                },
                                ensureLoaded: {
                                    model.loadGamesIfNeeded(systemIdentifier: system.identifier)
                                }
                            )
                            .task {
                                _ = await saveStatesStore.loadRecent(forSystemID: system.identifier, limit: 6)
                            }

                            if let recent = saveStatesStore.recentBySystem[system.identifier], !recent.isEmpty {
                                TVMediaSaveStatesShelfRow(
                                    title: "\(system.shortName) · SAVES",
                                    items: recent,
                                    store: saveStatesStore
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .task {
            await loadAllGames()
        }
        .onAppear {
            if !hasAnyGames && !isLoading {
                isEmptyStateFocused = true
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("LOADING LIBRARY")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 28) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.retroPink.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.7), Color.retroBlue.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 12)
            }

            VStack(spacing: 12) {
                Text("NO GAMES YET")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 8)

                Text("Add ROMs via Files app, AirDrop, or Web Server")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Sync status hint
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 14))
                    Text("iCloud sync may be in progress")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.retroBlue.opacity(0.7))

                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.circle")
                        .font(.caption)
                    Text("Swipe left or press Menu for navigation")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func loadAllGames() async {
        isLoading = true
        for system in model.systems {
            await model.loadGamesForSystemAsync(identifier: system.identifier)
        }
        isLoading = false

        // Focus empty state if still no games
        if !hasAnyGames {
            isEmptyStateFocused = true
        }
    }
}

// MARK: - Systems View

@available(tvOS 16.0, *)
struct TVMediaSystemsView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var router: TVMediaRouter

    @State private var icons: [String: Image] = [:]
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

    /// Number of columns for calculating left edge
    private let columnsPerRow: Int = 4

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 420), spacing: 28)
    ]

    /// Only show systems that have games
    private var systemsWithGames: [PVSystem] {
        model.systems.filter { system in
            let gameCount = model.gamesBySystemIdentifier[system.identifier]?.count ?? system.games.count
            return gameCount > 0
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                TVMediaTopBar(title: "Systems")

                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(Array(systemsWithGames.enumerated()), id: \.element.identifier) { index, system in
                        let isAtLeftEdge = index % columnsPerRow == 0
                        TVMediaSystemCard(
                            system: system,
                            icon: icons[system.identifier],
                            gameCount: model.gamesBySystemIdentifier[system.identifier]?.count ?? system.games.count,
                            isAtLeftEdge: isAtLeftEdge,
                            focusCoordinator: focusCoordinator
                        ) {
                            focusCoordinator.closeSidebar()
                            router.navigateToSystem(system.identifier)
                        }
                        .task {
                            model.loadGamesIfNeeded(systemIdentifier: system.identifier)
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .task {
            await loadIcons()
        }
    }

    private func loadIcons() async {
        guard icons.isEmpty else { return }
        var newIcons: [String: Image] = [:]
        for system in model.systems {
            // Try the short name first (like "snes", "nes")
            let shortName = system.identifier.components(separatedBy: ".").last?.lowercased() ?? ""

            // Try multiple naming patterns used in the app
            let namesToTry = [
                shortName,
                "prov_\(shortName)_icon",
                "\(shortName)_icon",
                system.shortName.lowercased()
            ]

            for name in namesToTry {
                if let uiImage = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) {
                    newIcons[system.identifier] = Image(uiImage: uiImage).renderingMode(.template)
                    break
                }
            }
        }
        await MainActor.run {
            icons = newIcons
        }
    }
}

@available(tvOS 16.0, *)
struct TVMediaSystemCard: View {
    let system: PVSystem
    let icon: Image?
    let gameCount: Int
    let isAtLeftEdge: Bool
    var focusCoordinator: TVMediaFocusCoordinator?
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var glowIntensity: Double = 0

    init(
        system: PVSystem,
        icon: Image?,
        gameCount: Int,
        isAtLeftEdge: Bool = false,
        focusCoordinator: TVMediaFocusCoordinator? = nil,
        action: @escaping () -> Void
    ) {
        self.system = system
        self.icon = icon
        self.gameCount = gameCount
        self.isAtLeftEdge = isAtLeftEdge
        self.focusCoordinator = focusCoordinator
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow layer
                if isFocused {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.2), Color.retroBlue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 12)
                        .opacity(glowIntensity)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 20) {
                        // System icon container
                        ZStack {
                            // Focus glow
                            if isFocused {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.retroPink.opacity(0.35), .clear],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 50
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 6)
                            }

                            if let icon {
                                icon
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: isFocused ?
                                                [.white, Color.retroBlue.opacity(0.85)] :
                                                [.white.opacity(0.7), .white.opacity(0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: isFocused ? Color.retroPink.opacity(0.7) : .clear, radius: 12)
                            } else {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 38, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: isFocused ?
                                                [.white, Color.retroBlue.opacity(0.8)] :
                                                [.white.opacity(0.4), .white.opacity(0.3)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: isFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 10)
                            }
                        }
                        .frame(width: 80, height: 80)

                        VStack(alignment: .leading, spacing: 10) {
                            // System name with premium typography
                            Text(system.name.uppercased())
                                .font(.system(size: 17, weight: .bold, design: .default))
                                .tracking(0.8)
                                .foregroundStyle(isFocused ? .white : .white.opacity(0.85))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: false, vertical: true)
                                .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)

                            // Game count with subtle styling
                            HStack(spacing: 6) {
                                Text("\(gameCount)")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isFocused ? Color.retroBlue : .white.opacity(0.6))
                                Text("GAMES")
                                    .font(.system(size: 11, weight: .medium, design: .default))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }

                        Spacer(minLength: 0)

                        // Chevron indicator
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(
                                isFocused ?
                                    AnyShapeStyle(LinearGradient(
                                        colors: [Color.retroBlue.opacity(0.9), Color.retroPink.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )) :
                                    AnyShapeStyle(Color.white.opacity(0.2))
                            )
                            .shadow(color: isFocused ? Color.retroBlue.opacity(0.5) : .clear, radius: 6)
                    }

                    // Metadata row
                    if !system.manufacturer.isEmpty || system.releaseYear > 0 {
                        Text(systemMetadataFull(system).uppercased())
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1)
                            .padding(.top, 12)
                            .padding(.leading, 100) // Align with text
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .overlay(cardBorder)
            }
        }
        .buttonStyle(TVMediaSystemCardButtonStyle(isFocused: isFocused))
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
            withAnimation(.easeOut(duration: focused ? 0.3 : 0.15)) {
                glowIntensity = focused ? 0.8 : 0
            }
        }
        .onMoveCommand { direction in
            // Open sidebar when at left edge and swiping left
            if direction == .left && isAtLeftEdge && isFocused {
                focusCoordinator?.openSidebar()
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isFocused ?
                    LinearGradient(
                        colors: [
                            Color.retroPink.opacity(0.06),
                            Color.retroBlue.opacity(0.04),
                            Color.retroPink.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), Color.white.opacity(0.01)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                isFocused ?
                    LinearGradient(
                        colors: [
                            Color.retroPink.opacity(0.9),
                            Color.retroBlue.opacity(0.7),
                            Color.retroPink.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                lineWidth: isFocused ? 2 : 1
            )
    }

    private func systemMetadataFull(_ system: PVSystem) -> String {
        var parts: [String] = []
        if !system.manufacturer.isEmpty { parts.append(system.manufacturer) }
        if system.releaseYear > 0 { parts.append(String(system.releaseYear)) }
        if !system.shortName.isEmpty && system.shortName != system.name {
            parts.append(system.shortName)
        }
        return parts.joined(separator: " • ")
    }
}

/// System card button style
@available(tvOS 16.0, *)
struct TVMediaSystemCardButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: isFocused ? Color.retroPink.opacity(0.35) : .clear, radius: 20, x: 0, y: 6)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Flat button style - no background, scale on focus
@available(tvOS 16.0, *)
struct TVMediaFlatButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isFocused)
    }
}

/// Card button style without the default tvOS focus overlay
/// We handle focus styling ourselves with our RetroWave effects
@available(tvOS 16.0, *)
struct TVMediaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

/// View All card that appears at the end of horizontal shelves
@available(tvOS 16.0, *)
struct TVMediaViewAllCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    @FocusState private var isFocused: Bool

    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 220

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Arrow icon
                ZStack {
                    if isFocused {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.retroPink.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                    }

                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(
                            isFocused ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [.white, Color.retroBlue.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )) :
                                AnyShapeStyle(Color.white.opacity(0.5))
                        )
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 10)
                }

                VStack(spacing: 6) {
                    Text(title.uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .tracking(1)
                        .foregroundStyle(isFocused ? .white : .white.opacity(0.8))

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isFocused ?
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.1), Color.retroBlue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isFocused ?
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.8), Color.retroBlue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(color: isFocused ? Color.retroPink.opacity(0.4) : .clear, radius: 15, x: 0, y: 5)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - System Games View

@available(tvOS 16.0, *)
struct TVMediaSystemGamesView: View {
    let system: PVSystem
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var saveStatesStore: RetroSaveStatesStore
    @ObservedObject var gameActions: TVMediaGameActions
    @ObservedObject var router: TVMediaRouter

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @State private var recentGames: [PVGame] = []
    @State private var isLoading: Bool = true

    private let headerID = "systemHeader"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    // Header - always visible and focusable
                    TVMediaSystemHeader(system: system)
                        .id(headerID)

                    if isLoading {
                        ProgressView("Loading...")
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        // Recently played shelf
                        if !recentGames.isEmpty {
                            TVMediaShelf(title: "Recently Played", items: recentGames, gameActions: gameActions)
                        }

                        // Recent saves shelf
                        if let recentSaves = saveStatesStore.recentBySystem[system.identifier], !recentSaves.isEmpty {
                            TVMediaSaveStatesShelfRow(title: "Recent Saves", items: recentSaves, store: saveStatesStore)
                        }

                        // All Games section with proper title
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                // Accent bar
                                ZStack {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.retroPink.opacity(0.5))
                                        .frame(width: 4, height: 28)
                                        .blur(radius: 4)

                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.retroPink, Color.retroBlue],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 3, height: 26)
                                }

                                Text("ALL \(system.shortName.uppercased()) GAMES")
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.95))

                                Spacer()

                                let gameCount = model.gamesBySystemIdentifier[system.identifier]?.count ?? 0
                                Text("\(gameCount) GAMES")
                                    .font(.system(size: 13, weight: .medium, design: .default))
                                    .tracking(0.8)
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            TVMediaAllGamesGrid(
                                games: model.gamesBySystemIdentifier[system.identifier] ?? [],
                                gameActions: gameActions
                            )
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
            }
            .onMoveCommand { direction in
                if direction == .up {
                    // When at top of games grid and pressing up, scroll to header
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(headerID, anchor: .top)
                    }
                }
                // Left-edge handling is done by individual game tiles
            }
        }
        .task {
            isLoading = true
            await loadContent()
            isLoading = false
        }
    }

    private func loadContent() async {
        model.loadGamesIfNeeded(systemIdentifier: system.identifier)
        _ = await saveStatesStore.loadRecent(forSystemID: system.identifier, limit: 10)

        let recents: [PVGame] = await Task.detached(priority: .userInitiated) {
            do {
                let realm = try Realm()
                let results = realm.objects(PVGame.self)
                    .filter("systemIdentifier == %@ AND lastPlayed != nil", system.identifier)
                    .sorted(byKeyPath: #keyPath(PVGame.lastPlayed), ascending: false)
                return Array(results.prefix(24)).map { $0.freeze() }
            } catch {
                return []
            }
        }.value

        await MainActor.run {
            recentGames = recents
        }
    }
}

@available(tvOS 16.0, *)
struct TVMediaSystemHeader: View {
    let system: PVSystem

    @State private var icon: Image?

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(14)
                } else {
                    Image(systemName: "gamecontroller.fill")
                        .font(.largeTitle.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text(system.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text(systemMetadataLine(system))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .task {
            await loadIcon()
        }
    }

    private func systemMetadataLine(_ system: PVSystem) -> String {
        var parts: [String] = []
        if !system.manufacturer.isEmpty { parts.append(system.manufacturer) }
        if system.releaseYear > 0 { parts.append(String(system.releaseYear)) }
        if system.bit > 0 { parts.append("\(system.bit)-bit") }
        if system.usesCDs { parts.append("CD") }
        if system.portableSystem { parts.append("Portable") }
        if system.supportsRumble { parts.append("Rumble") }
        return parts.joined(separator: " • ")
    }

    private func loadIcon() async {
        guard icon == nil else { return }
        let name = system.identifier.components(separatedBy: ".").last?.lowercased() ?? "prov_snes_icon"
        if let uiImage = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) {
            icon = Image(uiImage: uiImage).renderingMode(.template)
        }
    }
}

// MARK: - All Games Grid

@available(tvOS 16.0, *)
struct TVMediaAllGamesGrid: View {
    let games: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

    /// Number of columns for calculating left edge items
    private let columnsPerRow: Int = 5

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                // First column in each row is at left edge
                let isAtLeftEdge = index % columnsPerRow == 0
                TVMediaGameTileView(
                    game: game,
                    titleFont: .headline.weight(.semibold),
                    onPlay: { sceneCoordinator.launchGame(game) },
                    contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                    isAtLeftEdge: isAtLeftEdge,
                    focusCoordinator: focusCoordinator
                )
            }
        }
    }
}

// MARK: - Search View

@available(tvOS 16.0, *)
struct TVMediaSearchView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var gameActions: TVMediaGameActions

    @State private var text: String = ""
    @State private var results: [PVGame] = []
    @State private var isSearching: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                TVMediaTopBar(title: "Search")

                searchField

                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if text.isEmpty {
                    searchPlaceholder
                } else if results.isEmpty {
                    noResultsView
                } else {
                    TVMediaSearchResultsGrid(results: results, gameActions: gameActions)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
    }

    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(text.isEmpty ? .white.opacity(0.5) : .white)

            TextField("Search games…", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(.white)
                .font(.title3)
                .onChange(of: text) { _ in
                    Task { await performSearch() }
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var searchPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))

            Text("Type to search your library")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))

            Text("No results for \"\(text)\"")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func performSearch() async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await MainActor.run {
                results = []
                isSearching = false
            }
            return
        }

        await MainActor.run { isSearching = true }

        let games: [PVGame] = await Task.detached(priority: .userInitiated) {
            do {
                let realm = try Realm()
                let matched = realm.objects(PVGame.self)
                    .filter("title CONTAINS[c] %@", query)
                    .sorted(byKeyPath: "title", ascending: true)
                return Array(matched.prefix(120)).map { $0.freeze() }
            } catch {
                return []
            }
        }.value

        await MainActor.run {
            results = games
            isSearching = false
        }
    }
}

// MARK: - Favorites View

@available(tvOS 16.0, *)
struct TVMediaFavoritesView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var gameActions: TVMediaGameActions

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isEmptyStateFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                TVMediaTopBar(title: "Favorites")

                let favorites = model.favoriteGames(limit: 240)
                if favorites.isEmpty {
                    emptyState
                        .focusable()
                        .focused($isEmptyStateFocused)
                } else {
                    TVMediaSearchResultsGrid(results: favorites, gameActions: gameActions)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .onMoveCommand { direction in
            if direction == .left {
                focusCoordinator.openSidebar()
            }
        }
        .onAppear {
            // Focus empty state if no favorites
            if model.favoriteGames(limit: 1).isEmpty {
                isEmptyStateFocused = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("No Favorites")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("Mark games as favorites to see them here.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            // Navigation hint
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("Swipe left or press Menu for navigation")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }
}

// MARK: - Top Bar

struct TVMediaTopBar: View {
    let title: String

    var body: some View {
        HStack(spacing: 18) {
            // Premium neon accent bar with glow
            ZStack {
                // Glow layer
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.6), Color.retroBlue.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: 40)
                    .blur(radius: 8)

                // Main bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroPink, Color.retroBlue.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 36)
            }

            // Title with premium typography
            Text(title.uppercased())
                .font(.system(size: 38, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.retroPink.opacity(0.4), radius: 10)
                .shadow(color: Color.retroBlue.opacity(0.2), radius: 20)

            Spacer()
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Shelf Components

@available(tvOS 16.0, *)
struct TVMediaShelf: View {
    let title: String
    let items: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @Namespace private var shelfNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Premium shelf header
            HStack(spacing: 12) {
                // Neon accent bar with glow
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.retroPink.opacity(0.5))
                        .frame(width: 4, height: 26)
                        .blur(radius: 4)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.9), Color.retroBlue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: 24)
                }

                Text(title.uppercased())
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, game in
                        TVMediaGameTileView(
                            game: game,
                            titleFont: .callout.weight(.semibold),
                            onPlay: { sceneCoordinator.launchGame(game) },
                            contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                            isAtLeftEdge: index == 0,
                            focusCoordinator: focusCoordinator
                        )
                    }
                }
                .padding(.vertical, 14)
            }
            // Use focusSection to ensure this shelf catches vertical focus navigation
            .focusSection()
        }
    }
}

@available(tvOS 16.0, *)
struct TVMediaSystemShelfRow: View {
    let system: PVSystem
    let games: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions
    let onViewAll: () -> Void
    let ensureLoaded: () -> Void

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @State private var systemIcon: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header row (non-focusable label only)
            HStack(spacing: 14) {
                // Neon accent bar with glow
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.retroPink.opacity(0.5))
                        .frame(width: 4, height: 30)
                        .blur(radius: 4)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.9), Color.retroBlue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: 28)
                }

                // System icon with subtle glow
                if let icon = systemIcon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(0.9), Color.retroBlue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 30, height: 30)
                        .shadow(color: Color.retroPink.opacity(0.3), radius: 6)
                }

                Text(system.name.uppercased())
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: Color.retroPink.opacity(0.2), radius: 4)

                Spacer()

                // Game count indicator
                Text("\(games.count) GAMES")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Horizontal scroll with games + View All card at the end
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    let gamesArray = Array(games.prefix(30))
                    ForEach(Array(gamesArray.enumerated()), id: \.element.id) { index, game in
                        TVMediaGameTileView(
                            game: game,
                            titleFont: .callout.weight(.semibold),
                            onPlay: { sceneCoordinator.launchGame(game) },
                            contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                            isAtLeftEdge: index == 0,
                            focusCoordinator: focusCoordinator
                        )
                    }

                    // View All card at the end of the row - always focusable in the horizontal flow
                    TVMediaViewAllCard(
                        title: "View All",
                        subtitle: "\(games.count) games",
                        action: onViewAll
                    )
                }
                .padding(.vertical, 12)
            }
            // Use focusSection to ensure this shelf catches vertical focus navigation
            .focusSection()
        }
        .onAppear(perform: ensureLoaded)
        .task {
            await loadSystemIcon()
        }
    }

    private func loadSystemIcon() async {
        let shortName = system.identifier.components(separatedBy: ".").last?.lowercased() ?? ""
        let namesToTry = [shortName, "prov_\(shortName)_icon", "\(shortName)_icon", system.shortName.lowercased()]
        for name in namesToTry {
            if let uiImage = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) {
                await MainActor.run {
                    systemIcon = Image(uiImage: uiImage).renderingMode(.template)
                }
                return
            }
        }
    }
}

@available(tvOS 16.0, *)
struct TVMediaSaveStatesShelfRow: View {
    let title: String
    let items: [RetroSaveStateItem]
    @ObservedObject var store: RetroSaveStatesStore

    @FocusState private var focusedSaveID: String?
    @State private var thumbs: [String: UIImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with subtle save state accent
            HStack(spacing: 10) {
                // Smaller accent bar for saves (secondary content)
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroBlue.opacity(0.5), Color.retroPink.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 18)
                    .shadow(color: Color.retroBlue.opacity(0.25), radius: 3)

                Text(title.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.65))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(items) { item in
                        saveStateTile(for: item)
                    }
                }
                .padding(.vertical, 12)
            }
            // Use focusSection to ensure this shelf catches vertical focus navigation
            .focusSection()
        }
    }

    @ViewBuilder
    private func saveStateTile(for item: RetroSaveStateItem) -> some View {
        let isFocused = focusedSaveID == item.id

        Button {
            Task { await store.openSaveState(id: item.id) }
        } label: {
            TVMediaSaveStateTile(
                title: item.gameTitle,
                subtitle: item.date,
                thumbnail: thumbs[item.id],
                isFocused: isFocused,
                coreName: item.coreName.isEmpty ? nil : item.coreName
            )
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .focused($focusedSaveID, equals: item.id)
        .contextMenu {
            Button(role: .destructive) {
                Task { await deleteSaveState(item) }
            } label: {
                Label("Delete Save State", systemImage: "trash")
            }
        }
        .task {
            if thumbs[item.id] == nil {
                thumbs[item.id] = await store.thumbnail(for: item, targetSize: CGSize(width: 280, height: 180))
            }
        }
    }

    private func deleteSaveState(_ item: RetroSaveStateItem) async {
        await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: item.id) else { return }
            do {
                try RomDatabase.sharedInstance.delete(saveState: saveState)
            } catch {
                SceneCoordinator.shared.alertState.show(
                    title: "Delete Failed",
                    message: error.localizedDescription,
                    type: .error
                )
            }
        }
        _ = await store.loadRecent(forSystemID: item.systemId, limit: 6)
    }
}

// MARK: - Search Results Grid

@available(tvOS 16.0, *)
struct TVMediaSearchResultsGrid: View {
    let results: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

    private let columnsPerRow: Int = 5

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, game in
                let isAtLeftEdge = index % columnsPerRow == 0
                TVMediaGameTileView(
                    game: game,
                    titleFont: .callout.weight(.semibold),
                    onPlay: { sceneCoordinator.launchGame(game) },
                    contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                    isAtLeftEdge: isAtLeftEdge,
                    focusCoordinator: focusCoordinator
                )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Background

struct TVMediaBackground: View {
    var body: some View {
        ZStack {
            // Deep base - true black with subtle blue tint
            Color(red: 0.01, green: 0.01, blue: 0.03)

            // Radial gradient for depth
            RadialGradient(
                colors: [
                    Color(red: 0.03, green: 0.02, blue: 0.06),
                    Color(red: 0.01, green: 0.01, blue: 0.02)
                ],
                center: .topLeading,
                startRadius: 100,
                endRadius: 1200
            )
            .opacity(0.8)

            // Subtle horizon glow at bottom
            VStack {
                Spacer()
                ZStack {
                    // Pink horizon line
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.retroPink.opacity(0.04),
                            Color.retroPink.opacity(0.06),
                            Color.retroPink.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 300)

                    // Blue ambient glow
                    RadialGradient(
                        colors: [
                            Color.retroBlue.opacity(0.05),
                            Color.clear
                        ],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 600
                    )
                }
            }

            // Corner accent glows
            VStack {
                HStack {
                    RadialGradient(
                        colors: [Color.retroPink.opacity(0.015), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                    .frame(width: 500, height: 500)
                    Spacer()
                }
                Spacer()
            }

            // Subtle grid pattern
            TVMediaGridPattern()
                .opacity(0.03)

            // CRT scanline overlay
            TVMediaScanlines()
                .opacity(0.015)

            // Subtle vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.4)],
                center: .center,
                startRadius: 400,
                endRadius: 1200
            )
        }
    }
}

/// Subtle grid pattern for RetroWave aesthetic
struct TVMediaGridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 60

            // Vertical lines
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.retroBlue), lineWidth: 0.5)
                x += spacing
            }

            // Horizontal lines
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.retroBlue), lineWidth: 0.5)
                y += spacing
            }
        }
    }
}

/// Subtle scanline effect
struct TVMediaScanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.black), lineWidth: 1)
                y += 3
            }
        }
    }
}

/// SMPTE color bars for save states without thumbnails
@available(tvOS 16.0, *)
struct TVMediaSaveStateSMPTE: View {
    private let colors: [Color] = [
        Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 0.75, green: 0.75, blue: 0.0),
        Color(red: 0.0, green: 0.75, blue: 0.75),
        Color(red: 0.0, green: 0.75, blue: 0.0),
        Color(red: 0.75, green: 0.0, blue: 0.75),
        Color(red: 0.75, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.0, blue: 0.75)
    ]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<colors.count, id: \.self) { index in
                    colors[index]
                        .frame(width: geo.size.width / CGFloat(colors.count))
                }
            }
            .overlay(
                VStack(spacing: 0) {
                    ForEach(0..<Int(geo.size.height / 2.5), id: \.self) { _ in
                        Color.clear.frame(height: 1.5)
                        Color.black.opacity(0.12).frame(height: 1)
                    }
                }
            )
        }
    }
}

// MARK: - Save State Tile

@available(tvOS 16.0, *)
struct TVMediaSaveStateTile: View {
    let title: String
    let subtitle: Date
    let thumbnail: UIImage?
    let isFocused: Bool
    let coreName: String?

    private let tileWidth: CGFloat = 300
    private let tileHeight: CGFloat = 190

    init(title: String, subtitle: Date, thumbnail: UIImage?, isFocused: Bool, coreName: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.thumbnail = thumbnail
        self.isFocused = isFocused
        self.coreName = coreName
    }

    var body: some View {
        ZStack {
            // Outer glow when focused
            if isFocused {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.25), Color.retroBlue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 16)
            }

            ZStack(alignment: .bottomLeading) {
                // Thumbnail or placeholder
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        TVMediaSaveStateSMPTE()
                    }
                }
                .frame(width: tileWidth, height: tileHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Scanline overlay
                VStack(spacing: 0) {
                    ForEach(0..<Int(tileHeight / 3), id: \.self) { _ in
                        Color.clear.frame(height: 2)
                        Color.black.opacity(0.06).frame(height: 1)
                    }
                }
                .frame(width: tileWidth, height: tileHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Info overlay
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.8), radius: 4)
                        .shadow(color: isFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 6)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .medium))
                        Text(subtitle, style: .relative)
                            .font(.system(size: 12, weight: .medium, design: .default))

                        if let coreName = coreName, !coreName.isEmpty {
                            Text("•")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(coreName)
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .shadow(color: .black.opacity(0.6), radius: 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4), .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: tileWidth, height: tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(focusBorder)
        }
        .frame(width: tileWidth, height: tileHeight)
        .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 20, x: 0, y: 8)
        .shadow(color: isFocused ? Color.retroBlue.opacity(0.3) : .clear, radius: 30, x: 0, y: 12)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: isFocused ? [
                        Color.retroPink.opacity(0.9),
                        Color.retroBlue.opacity(0.7),
                        Color.retroPink.opacity(0.5)
                    ] : [.clear, .clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isFocused ? 3 : 0
            )
    }
}

// MARK: - Import Status Toaster

/// Compact import status toaster that appears in the bottom-right corner
@available(tvOS 16.0, *)
struct TVMediaImportStatusToaster: View {
    let gameImporter: any GameImporting
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    let onTap: () -> Void

    @StateObject private var viewModel: ImportProgressViewModel
    @FocusState private var isFocused: Bool
    @State private var isExpanded = false

    init(gameImporter: any GameImporting, updatesController: PVGameLibraryUpdatesController, onTap: @escaping () -> Void) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onTap = onTap
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter, updatesController: updatesController))
    }

    var body: some View {
        Group {
            if viewModel.shouldShow {
                toasterContent
                    .focusable()
                    .focused($isFocused)
                    .onMoveCommand { _ in }
                    .onLongPressGesture(minimumDuration: 0.1) {
                        onTap()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.shouldShow)
            }
        }
    }

    private var toasterContent: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Header
            HStack(spacing: 12) {
                // Activity indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.retroBlue))
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    if !viewModel.importQueueItems.isEmpty {
                        Text("IMPORTING")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(Color.retroPink)
                    } else if viewModel.isSyncing {
                        Text("SYNCING")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(Color.retroBlue)
                    } else {
                        Text("PROCESSING")
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(Color.retroPink)
                    }

                    Text(statusText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Expand hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Progress bar
            if !viewModel.importQueueItems.isEmpty {
                importProgressBar
            } else if viewModel.isSyncing, let progress = viewModel.initialSyncProgress {
                syncProgressBar(progress: progress.overallProgress)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: 280)
        .background(toasterBackground)
        .overlay(focusBorder)
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }

    private var statusText: String {
        if !viewModel.importQueueItems.isEmpty {
            let count = viewModel.importQueueItems.count
            let processing = viewModel.importQueueItems.filter { $0.status == .processing }.count
            if processing > 0 {
                return "\(processing) of \(count) files"
            }
            return "\(count) files queued"
        } else if viewModel.isSyncing {
            return viewModel.iCloudStatusMessage.isEmpty ? "Checking iCloud..." : viewModel.iCloudStatusMessage
        } else if viewModel.isFileCopying {
            return "Copying files..."
        }
        return "Working..."
    }

    private var importProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                let processedCount = viewModel.importQueueItems.filter { $0.status == .success || $0.status.isFailure }.count
                let progress = viewModel.importQueueItems.isEmpty ? 0.0 : CGFloat(processedCount) / CGFloat(viewModel.importQueueItems.count)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroPink, Color.retroBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geo.size.width * progress), height: 4)
                    .shadow(color: Color.retroPink.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 4)
    }

    private func syncProgressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.retroBlue, Color.retroPink.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geo.size.width * CGFloat(progress)), height: 4)
                    .shadow(color: Color.retroBlue.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 4)
    }

    private var toasterBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.retroBlack.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.retroPink.opacity(0.4),
                                Color.retroBlue.opacity(0.3),
                                Color.retroPink.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.retroPink.opacity(0.2), radius: 12, x: 0, y: 4)
    }

    private var focusBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: isFocused ? [
                        Color.retroPink.opacity(0.9),
                        Color.retroBlue.opacity(0.7)
                    ] : [.clear, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isFocused ? 2.5 : 0
            )
    }
}

// MARK: - Import Status Sheet (Full Screen)

/// Full import queue management sheet with tvOS styling
@available(tvOS 16.0, *)
struct TVMediaImportStatusSheet: View {
    let gameImporter: any GameImporting
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    let onDismiss: () -> Void

    @StateObject private var viewModel: ImportProgressViewModel
    @FocusState private var focusedItemID: String?
    @Namespace private var sheetNamespace

    init(gameImporter: any GameImporting, updatesController: PVGameLibraryUpdatesController, onDismiss: @escaping () -> Void) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onDismiss = onDismiss
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter, updatesController: updatesController))
    }

    var body: some View {
        ZStack {
            // Background
            TVMediaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 60)
                    .padding(.top, 50)
                    .padding(.bottom, 30)

                // Content
                if viewModel.importQueueItems.isEmpty && !viewModel.isSyncing {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // iCloud sync status
                            if viewModel.isSyncing {
                                iCloudSyncCard
                            }

                            // Import queue items
                            ForEach(viewModel.importQueueItems) { item in
                                importItemRow(item)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 60)
                    }
                    .focusSection()
                }
            }
        }
        .focusScope(sheetNamespace)
        .onExitCommand {
            onDismiss()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("IMPORT QUEUE")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.retroBlue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.5), radius: 10)

                if !viewModel.importQueueItems.isEmpty {
                    Text("\(viewModel.importQueueItems.count) files in queue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            // Close button
            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("CLOSE")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(Color.retroPink)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroBlue.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(TVMediaCardButtonStyle())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.retroBlue.opacity(0.6))
                .shadow(color: Color.retroBlue.opacity(0.4), radius: 12)

            Text("NO PENDING IMPORTS")
                .font(.system(size: 22, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(.white)

            Text("All files have been processed")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var iCloudSyncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.retroBlue)
                    .shadow(color: Color.retroBlue.opacity(0.5), radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCLOUD SYNC")
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .tracking(1.5)
                        .foregroundStyle(.white)

                    Text(viewModel.iCloudStatusMessage.isEmpty ? "Syncing with iCloud..." : viewModel.iCloudStatusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.retroBlue))
            }

            if let progress = viewModel.initialSyncProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.retroBlue, Color.retroPink.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(progress.overallProgress)), height: 6)
                            .shadow(color: Color.retroBlue.opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.4), Color.retroPink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    @ViewBuilder
    private func importItemRow(_ item: ImportQueueItem) -> some View {
        let isFocused = focusedItemID == item.id.uuidString

        HStack(spacing: 18) {
            // Status icon
            statusIcon(for: item.status)
                .frame(width: 36, height: 36)

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(statusText(for: item.status))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor(for: item.status).opacity(0.9))

                    if let system = item.targetSystem() {
                        Text("→ \(system.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Action buttons for conflict resolution
            if case .conflict = item.status {
                Button("Select System") {
                    // Would present system picker
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.retroBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.retroBlue.opacity(0.6), lineWidth: 1.5)
                )
                .buttonStyle(TVMediaCardButtonStyle())
            }

            // Delete button
            Button {
                Task {
                    if let index = viewModel.importQueueItems.firstIndex(where: { $0.id == item.id }) {
                        await gameImporter.removeImports(at: IndexSet(integer: index))
                    }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.retroPink.opacity(0.7))
            }
            .buttonStyle(TVMediaCardButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isFocused ?
                                LinearGradient(
                                    colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .focusable()
        .focused($focusedItemID, equals: item.id.uuidString)
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }

    @ViewBuilder
    private func statusIcon(for status: ImportQueueItem.ImportStatus) -> some View {
        ZStack {
            Circle()
                .fill(statusColor(for: status).opacity(0.15))

            switch status {
            case .queued:
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            case .processing, .extracting:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: statusColor(for: status)))
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(statusColor(for: status))
            case .failure, .conflict:
                Image(systemName: status == .conflict ? "exclamationmark.triangle" : "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            case .partial:
                Image(systemName: "hourglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            }
        }
    }

    private func statusColor(for status: ImportQueueItem.ImportStatus) -> Color {
        switch status {
        case .queued: return .white.opacity(0.5)
        case .processing, .extracting: return Color.retroBlue
        case .success: return Color.retroGreen
        case .failure: return Color.retroPink
        case .conflict: return .orange
        case .partial: return .yellow
        }
    }

    private func statusText(for status: ImportQueueItem.ImportStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .processing: return "Processing..."
        case .extracting: return "Extracting..."
        case .success: return "Imported"
        case .failure(let error): return error.localizedDescription
        case .conflict: return "Needs system selection"
        case .partial(let expectedFiles): return "Waiting for \(expectedFiles.count) files"
        }
    }
}

#endif
