import SwiftUI
import Combine
import PVUIBase
import PVThemes
import PVLibrary
import PVFeatureFlags
import PVHelp
import RealmSwift
import PVRealm
import PVPrimitives
import PVLogging

#if canImport(PVWebServer)
import PVWebServer
#endif

#if os(tvOS) || os(iOS)

// MARK: - System Icon Loader

/// Shared icon loader for system icons used throughout the tvOS Media UI
@available(tvOS 16.0, iOS 17.0, *)
@MainActor
final class SystemIconLoader: ObservableObject {
    static let shared = SystemIconLoader()

    @Published private(set) var icons: [String: Image] = [:]
    private var loadedSystems: Set<String> = []
    private var isLoading = false

    private init() {}

    /// The correct bundle containing system icons (PVUIBase, not PVSwiftUI)
    private let iconBundle: Bundle = PVUIBase.BundleLoader.myBundle

    /// Load icons for the given systems
    func loadIcons(for systems: [PVSystem]) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var newIcons: [String: Image] = [:]

        for system in systems {
            // Skip if already loaded
            guard !loadedSystems.contains(system.identifier) else { continue }

            let shortName = system.identifier.components(separatedBy: ".").last?.lowercased() ?? ""

            // Try multiple naming patterns used in the app
            let namesToTry = [
                shortName,
                system.iconName,
                "prov_\(shortName)_icon",
                "\(shortName)_icon",
                system.shortName.lowercased()
            ]

            var foundIcon = false
            for name in namesToTry {
                // Try UIImage approach with PVUIBase bundle (where icons actually live)
                if let uiImage = UIImage(named: name, in: iconBundle, compatibleWith: nil) {
                    newIcons[system.identifier] = Image(uiImage: uiImage).renderingMode(.template)
                    loadedSystems.insert(system.identifier)
                    foundIcon = true
                    break
                }
            }

            // If UIImage failed, use SwiftUI Image with explicit bundle
            if !foundIcon {
                // Use first valid name pattern with SwiftUI Image
                let imageName = shortName.isEmpty ? system.iconName : shortName
                newIcons[system.identifier] = Image(imageName, bundle: iconBundle).renderingMode(.template)
                loadedSystems.insert(system.identifier)
            }
        }

        // Merge new icons with existing
        if !newIcons.isEmpty {
            for (key, value) in newIcons {
                icons[key] = value
            }
        }
    }

    /// Get icon for a specific system
    func icon(for systemIdentifier: String) -> Image? {
        return icons[systemIdentifier]
    }
}

@available(tvOS 16.0, iOS 17.0, *)
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
    @State private var settingsCanPop: Bool = false

    @ObservedObject private var syncStatusManager = SceneCoordinator.shared.syncStatusManager

    init() {}

    /// Sidebar collapsed width for content padding
    private let sidebarCollapsedWidth: CGFloat = 80

    @Namespace private var mainNamespace
    @Namespace private var sidebarNamespace
    #if os(tvOS)
    @Environment(\.resetFocus) private var resetFocus
    #else
    /// No-op focus reset on iOS where tvOS focus APIs are unavailable.
    private let resetFocus: (Namespace.ID) -> Void = { _ in }
    #endif

    private var resetFocusCallback: (Namespace.ID) -> Void {
        #if os(tvOS)
        return { namespace in
            resetFocus(in: namespace)
        }
        #else
        return resetFocus
        #endif
    }

    /// Convenience flag for modal rename alert
    private var isRenamePresented: Bool {
        gameActions.renameGame != nil
    }

    public var body: some View {
        TVMediaMainRootView(
            appState: appState,
            lastDestinationRaw: $lastDestinationRaw,
            lastSystemIdentifier: $lastSystemIdentifier,
            settingsCanPop: $settingsCanPop, focusCoordinator: focusCoordinator,
            router: router,
            libraryModel: libraryModel,
            gameActions: gameActions,
            sidebarCollapsedWidth: sidebarCollapsedWidth,
            mainNamespace: mainNamespace,
            sidebarNamespace: sidebarNamespace,
            resetFocus: resetFocusCallback,
            isRenamePresented: isRenamePresented,
            contentArea: { contentArea },
            overlays: { overlays },
            modalContent: { modal in modalContent(for: modal) },
            renameAlertContent: { renameAlertContent }
        )
#if os(iOS)
        // This shared view is compiled for both iOS and tvOS.
        // romDropTarget() is iOS-only (onDrop is unavailable on tvOS).
        .romDropTarget() // ROM drag & drop import (#2136)
#endif
    }

    // MARK: - Main Layout Sections

    private var renameAlertContent: some View {
        VStack(spacing: 10) {
            RetroButton(title: "Save", isPrimary: true) {
                Task {
                    let systemID = gameActions.renameGame?.systemIdentifier
                    await gameActions.commitRenameIfPossible()
                    if let systemID {
                        await libraryModel.refreshAfterGameRename(systemIdentifier: systemID)
                    } else {
                        libraryModel.refresh()
                    }
                }
            }
            RetroButton(title: "Cancel", isPrimary: false) {
                gameActions.clearRename()
            }
        }
    }

    private struct TVMediaMainRootView<ContentArea: View, Overlays: View, ModalContent: View, RenameAlertContent: View>: View {
        @ObservedObject var appState: AppState

        @Binding var lastDestinationRaw: String
        @Binding var lastSystemIdentifier: String
        @Binding var settingsCanPop: Bool

        @ObservedObject var focusCoordinator: TVMediaFocusCoordinator
        @ObservedObject var router: TVMediaRouter
        @ObservedObject var libraryModel: TVMediaLibraryModel
        @ObservedObject var gameActions: TVMediaGameActions

        #if os(iOS)
        @StateObject private var gamepadManager = GamepadManager.shared
        #endif

        @State private var showingImportsAlert = false
        @StateObject private var featureFlagsManager = PVFeatureFlagsManager.shared

        let sidebarCollapsedWidth: CGFloat
        let mainNamespace: Namespace.ID
        let sidebarNamespace: Namespace.ID
        let resetFocus: (Namespace.ID) -> Void
        let isRenamePresented: Bool
        let contentArea: () -> ContentArea
        let overlays: () -> Overlays
        let modalContent: (TVMediaModal) -> ModalContent
        let renameAlertContent: () -> RenameAlertContent

        var body: some View {
            layoutWithRenameFocus
        }

        private var baseLayout: some View {
            ZStack(alignment: .leading) {
                TVMediaBackground()
                    .ignoresSafeArea()

                contentSection
                sidebarSection
                overlays()
            }
        }

        private var layoutWithEnvironment: some View {
            baseLayout
                .environment(\.tvMediaFocusCoordinator, focusCoordinator)
        }

        private var layoutWithLifecycle: some View {
            layoutWithEnvironment
                .onAppear {
                    gameActions.appState = appState
                    focusCoordinator.closeSidebar()
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
                    focusCoordinator.closeSidebar()
                    focusCoordinator.clearEdgeRegistrations()
                }
                .onChange(of: focusCoordinator.isSidebarExpanded) { expanded in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if expanded {
                            resetFocus(sidebarNamespace)
                        } else {
                            resetFocus(mainNamespace)
                        }
                    }
                }
                .onChange(of: router.selectedSystemID) { newValue in
                    lastSystemIdentifier = newValue
                    libraryModel.selectSystem(identifier: newValue)
                }
                .onChange(of: gameActions.systemPickerGame) { newValue in
                    if let game = newValue {
                        router.activeModal = .systemPicker(game: game)
                    } else if case .systemPicker = router.activeModal {
                        router.dismissModal()
                    }
                }
                .onChange(of: gameActions.artworkSearchGame) { newValue in
                    if let game = newValue {
                        router.activeModal = .artworkSearch(game: game)
                    } else if case .artworkSearch = router.activeModal {
                        router.dismissModal()
                    }
                }
                .onChange(of: gameActions.imagePickerGame) { newValue in
                    if let game = newValue {
                        router.activeModal = .imagePicker(game: game)
                    } else if case .imagePicker = router.activeModal {
                        router.dismissModal()
                    }
                }
                #if os(iOS)
                .onReceive(gamepadManager.eventPublisher) { event in
                    guard gamepadManager.isControllerConnected else { return }
                    switch event {
                    case .menuToggle(let isPressed):
                        if isPressed {
                            focusCoordinator.toggleSidebar()
                        }
                    case .start(let isPressed):
                        if isPressed {
                            focusCoordinator.toggleSidebar()
                        }
                    case .buttonB(let isPressed):
                        if isPressed, focusCoordinator.isSidebarExpanded {
                            focusCoordinator.closeSidebar()
                        }
                    default:
                        break
                    }
                }
                #endif
        }

        private var layoutWithExitCommand: some View {
            layoutWithLifecycle
                .tvMediaOnExitCommand {
                    if isRenamePresented {
                        gameActions.clearRename()
                        return
                    }
                    if focusCoordinator.isAlertPresented || focusCoordinator.isModalPresented {
                        return
                    }
                    if router.handleBack() {
                        return
                    }
                    if router.destination == .settings, settingsCanPop {
                        NotificationCenter.default.post(name: .tvOSSettingsRequestPop, object: nil)
                        return
                    }
                    focusCoordinator.toggleSidebar()
                }
        }

        private var layoutWithModal: some View {
            layoutWithExitCommand
                #if os(tvOS)
                .fullScreenCover(item: $router.activeModal) { modal in
                    modalContent(modal)
                }
                #else
                .sheet(item: $router.activeModal) { modal in
                    modalContent(modal)
                }
                #endif
        }

        /// Dynamic selection items for the imports alert, conditionally including Free ROMs
        private var importsAlertItems: [RetroSelectionItem] {
            var items = [
                RetroSelectionItem(id: "importQueue", title: "Import Queue", subtitle: "View active and completed imports")
            ]
            if featureFlagsManager.featureStates[.inAppFreeROMs] ?? false {
                items.append(RetroSelectionItem(id: "freeROMs", title: "Free ROMs", subtitle: "Browse open-source and public domain ROMs"))
            }
            items.append(RetroSelectionItem(id: "romInstructions", title: "How to Add ROMs", subtitle: "Web server, AirDrop, and more"))
            return items
        }

        private var layoutWithImportsAlert: some View {
            layoutWithModal
                .retroSelectionAlert(
                    title: "IMPORTS",
                    message: "Choose an option",
                    items: importsAlertItems,
                    isPresented: $showingImportsAlert,
                    onSelect: { selectedId in
                        switch selectedId {
                        case "importQueue":
                            router.activeModal = .importQueue
                        case "freeROMs":
                            router.activeModal = .freeROMs
                        case "romInstructions":
                            router.activeModal = .romInstructions
                        default:
                            break
                        }
                    }
                )
        }

        private var layoutWithArtworkSourceAlert: some View {
            layoutWithImportsAlert
                #if !os(tvOS)
                .uiKitAlert(
                    "Choose Artwork Source",
                    message: "Select artwork from your photo library or search online sources",
                    isPresented: $gameActions.showArtworkSourceAlert,
                    buttons: {
                        UIAlertAction(title: "Search Online", style: .default) { _ in
                            Task { @MainActor in
                                gameActions.showArtworkSourceAlert = false
                                if let game = gameActions.gameForArtworkUpdate {
                                    gameActions.artworkSearchGame = game
                                }
                            }
                        }
                        UIAlertAction(title: "Select from Photos", style: .default) { _ in
                            Task { @MainActor in
                                gameActions.showArtworkSourceAlert = false
                                if let game = gameActions.gameForArtworkUpdate {
                                    gameActions.imagePickerGame = game
                                }
                            }
                        }
                        UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                            Task { @MainActor in
                                gameActions.showArtworkSourceAlert = false
                                gameActions.gameForArtworkUpdate = nil
                            }
                        }
                    }
                )
                #endif
        }

        private var layoutWithRenameAlert: some View {
            layoutWithArtworkSourceAlert
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
                    renameAlertContent()
                }
        }

        private var layoutWithAppearance: some View {
            layoutWithRenameAlert
                .preferredColorScheme(.dark)
                .ignoresSafeArea(.all)
                .hideHomeIndicator()
        }

        private var layoutWithRenameFocus: some View {
            layoutWithAppearance
                .onChange(of: gameActions.renameGame) { newValue in
                    focusCoordinator.isAlertPresented = (newValue != nil)
                    if newValue != nil {
                        resetFocus(mainNamespace)
                    }
                }
        }

        private var contentSection: some View {
            contentGroup
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, sidebarCollapsedWidth)
                .allowsHitTesting(!focusCoordinator.isAlertPresented && !isRenamePresented)
                .disabled(focusCoordinator.isAlertPresented || isRenamePresented)
                .animation(.easeInOut(duration: 0.25), value: router.destination)
                .tvMediaFocusSection()
                .tvMediaFocusScope(mainNamespace)
                .tvMediaPrefersDefaultFocus(!focusCoordinator.isSidebarExpanded, in: mainNamespace)
        }

        @ViewBuilder
        private var contentGroup: some View {
            if router.destination == .settings || router.destination == .saves {
                // Settings: always bypass TVMediaFocusAwareContent so that back-navigation
                // within the settings NavigationStack does NOT change view identity, which
                // would otherwise retrigger the focus engine and open the sidebar.
                contentArea()
            } else {
                TVMediaFocusAwareContent(focusCoordinator: focusCoordinator) { contentArea() }
            }
        }

        private var sidebarSection: some View {
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
                    showingImportsAlert = true
                }
            )
            .tvMediaFocusScope(sidebarNamespace)
            .tvMediaPrefersDefaultFocus(focusCoordinator.isSidebarExpanded, in: sidebarNamespace)
            .allowsHitTesting(!focusCoordinator.isAlertPresented && !isRenamePresented)
            .disabled(!focusCoordinator.isSidebarExpanded || isRenamePresented)
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
                    .id(system.identifier)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.02)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                } else {
                    TVMediaEmptyStateView(
                        title: "Select a System",
                        subtitle: "Choose a system to browse games.",
                        showControllerTip: true
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
                    saveStatesStore: saveStatesStore,
                    router: router
                )
            case .logs:
                TVMediaLogsView()
                    .tvMediaOnMoveCommand { direction in
                        if direction == .left {
                            focusCoordinator.openSidebar()
                        }
                    }
            case .settings:
                // Settings view handles its own sidebar commands via tvMediaFocusCoordinator environment
                #if os(tvOS)
                SettingsWrapperView(canPop: $settingsCanPop)
                    .onAppear {
                        focusCoordinator.closeSidebar()
                    }
                #else
                SettingsWrapperView()
                    .onAppear {
                        focusCoordinator.closeSidebar()
                    }
                #endif
            case .status:
                RetroStatusControlView()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .focusable()
                    .tvMediaOnMoveCommand { direction in
                        if direction == .left {
                            focusCoordinator.openSidebar()
                        }
                    }
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
        case .freeROMs:
            FreeROMsView(
                onROMDownloaded: { rom, tempURL in
                    appState.libraryUpdatesController?.handlePickedDocuments([tempURL])
                },
                onDismiss: {
                    router.dismissModal()
                }
            )
            #if os(tvOS)
            .onExitCommand {
                router.dismissModal()
            }
            #endif
        case .romInstructions:
            NavigationStack {
                TVMediaROMInstructionsView(onDismiss: { router.dismissModal() })
            }
        case .artworkSearch(let game):
            let actions = gameActions
            NavigationStack {
                ArtworkSearchView(
                    initialSearch: game.title,
                    initialSystem: game.system?.enumValue
                ) { selection in
                    Task { @MainActor in
                        guard let targetGame = actions.gameForArtworkUpdate else { return }
                        do {
                            let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                            if let uiImage = UIImage(data: data) {
                                self.saveArtwork(image: uiImage, forGame: targetGame)
                            }
                        } catch {
                            DLOG("Failed to download artwork: \(error.localizedDescription)")
                        }
                        router.dismissModal()
                        actions.artworkSearchGame = nil
                        actions.gameForArtworkUpdate = nil
                    }
                }
                .navigationTitle("Artwork Search")
            }
        case .imagePicker:
            #if !os(tvOS)
            let actions = gameActions
            ImagePicker(sourceType: .photoLibrary) { image in
                if let targetGame = actions.gameForArtworkUpdate {
                    self.saveArtwork(image: image, forGame: targetGame)
                }
                router.dismissModal()
                actions.imagePickerGame = nil
                actions.gameForArtworkUpdate = nil
            }
            #else
            EmptyView()
            #endif
        }
    }

    /// Persist a UIImage as custom artwork for the given game
    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        guard !game.isInvalidated else {
            DLOG("TVMediaMainView: Cannot save artwork - game is invalidated")
            return
        }

        let md5: String = game.md5Hash ?? ""
        guard !md5.isEmpty else {
            DLOG("TVMediaMainView: Cannot save artwork - game has no MD5 hash")
            return
        }

        let uniqueID = UUID().uuidString
        let key = "artwork_\(md5)_\(uniqueID)"

        do {
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            try RomDatabase.sharedInstance.writeTransaction {
                guard let liveGame = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: md5) else {
                    return
                }
                liveGame.customArtworkURL = key
            }
            DLOG("Artwork saved for \(game.title)")
        } catch {
            DLOG("Failed to set custom artwork: \(error.localizedDescription)")
        }
    }
}

/// Alert overlay that properly captures focus on tvOS
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaAlertOverlay: View {
    @ObservedObject var alertState: RetroAlertState
    @ObservedObject var focusCoordinator: TVMediaFocusCoordinator

    @FocusState private var isAlertFocused: Bool

    var body: some View {
        Group {
            if alertState.isPresented {
                RetroAlertStateView(alertState: alertState)
                    .tvMediaFocusSection()
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
    case logs
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
        case .logs: return "Logs"
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

    /// Refreshes the minimal data needed after renaming a game so visible lists update immediately.
    @MainActor
    func refreshAfterGameRename(systemIdentifier: String) async {
        await loadFavorites()
        await loadGamesForSystemAsync(identifier: systemIdentifier)
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

        // Only reload games for the selected system (visible) plus any already-loaded
        // systems (to keep existing shelves in sync). Avoid reloading every system on
        // each Realm write — with 50+ systems that causes O(n) sequential queries.
        // Build an ordered list: selected/visible system first so it appears
        // refreshed immediately, followed by any other cached systems.
        var identifiersToRefresh: [String] = []
        var seenIdentifiers = Set<String>()
        if !selectedSystemIdentifier.isEmpty {
            identifiersToRefresh.append(selectedSystemIdentifier)
            seenIdentifiers.insert(selectedSystemIdentifier)
        }
        for id in gamesBySystemIdentifier.keys {
            if !seenIdentifiers.contains(id) {
                identifiersToRefresh.append(id)
                seenIdentifiers.insert(id)
            }
        }
        // Run reloads concurrently instead of sequentially, but with a bounded level
        // of concurrency to avoid spawning too many Realm loads at once.
        let maxConcurrentGameLoads = 4
        let ids = identifiersToRefresh
        var index = 0

        while index < ids.count {
            let end = min(index + maxConcurrentGameLoads, ids.count)
            let slice = ids[index..<end]

            await withTaskGroup(of: Void.self) { group in
                for id in slice {
                    group.addTask { await self.loadGamesForSystemAsync(identifier: id) }
                }
            }

            index = end
        }
    }

    func loadGamesForSystem(identifier: String) async {
        guard gamesBySystemIdentifier[identifier] == nil else { return }
        await loadGamesForSystemAsync(identifier: identifier)
    }

    /// Async method that always loads games (no guard).
    /// Thread-safety: marked @MainActor so all mutations to `gamesBySystemIdentifier`
    /// are serialised on the main actor. Realm reads run in a detached task to avoid
    /// blocking the main thread; results are frozen before crossing actor boundaries.
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

        // Already on MainActor — direct assignment is safe.
        gamesBySystemIdentifier[identifier] = loaded
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
    @Published var artworkSearchGame: PVGame?
    @Published var imagePickerGame: PVGame?
    @Published var showArtworkSourceAlert = false
    /// Tracks the game for artwork operations (set before alert or sheet)
    @Published var gameForArtworkUpdate: PVGame?

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

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        Task { @MainActor in
            let frozen = game.isFrozen ? game : game.freeze()
            gameForArtworkUpdate = frozen
            artworkSearchGame = frozen
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        Task { @MainActor in
            let frozen = game.isFrozen ? game : game.freeze()
            gameForArtworkUpdate = frozen
            imagePickerGame = frozen
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        Task { @MainActor in
            let frozen = game.isFrozen ? game : game.freeze()
            gameForArtworkUpdate = frozen
            #if os(tvOS)
            /// tvOS has no photo picker -- go directly to online search
            artworkSearchGame = frozen
            #else
            showArtworkSourceAlert = true
            #endif
        }
    }
}

struct TVMediaSaveBrowserContext: Identifiable {
    let systemID: String
    let systemName: String
    let game: PVGame?
    var id: String { game?.id ?? systemID }
}

private struct TVMediaWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func tvMediaTrackWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(TVMediaTrackWidthModifier(onChange: onChange))
    }
}

private struct TVMediaTrackWidthModifier: ViewModifier {
    /// Width callback for parent layout decisions.
    let onChange: (CGFloat) -> Void
    @State private var lastReportedWidth: CGFloat?
    private let widthEpsilon: CGFloat = 0.5

    private func reportWidthIfNeeded(_ width: CGFloat) {
        guard width > 0 else { return }
        if let lastReportedWidth, abs(lastReportedWidth - width) < widthEpsilon {
            return
        }
        self.lastReportedWidth = width
        onChange(width)
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, tvOS 18.0, *) {
            content.background(
                Color.clear
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        reportWidthIfNeeded(width)
                    }
            )
        } else {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TVMediaWidthPreferenceKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(TVMediaWidthPreferenceKey.self) { width in
                    reportWidthIfNeeded(width)
                }
        }
    }
}

private func tvMediaAdaptiveColumnsPerRow(
    availableWidth: CGFloat,
    minItemWidth: CGFloat,
    maxItemWidth: CGFloat,
    spacing: CGFloat
) -> Int {
    guard availableWidth > 0, minItemWidth > 0 else { return 1 }

    var columns = max(1, Int((availableWidth + spacing) / (minItemWidth + spacing)))
    while columns > 1 {
        let itemWidth = (availableWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
        if itemWidth <= maxItemWidth { break }
        columns -= 1
    }
    return max(columns, 1)
}

// MARK: - Logs View

@available(tvOS 16.0, iOS 16.0, *)
struct TVMediaLogsView: View {
    @State private var isFullscreen = false
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    var body: some View {
        Group {
            if isFullscreen {
                RetroLogView(isFullscreen: $isFullscreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 40)
            } else {
                RetroLogView(isFullscreen: $isFullscreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .tvMediaFocusSection()
                    .tvMediaOnMoveCommand { direction in
                        if direction == .left {
                            focusCoordinator.openSidebar()
                        }
                    }
            }
        }
        .onAppear {
            focusCoordinator.closeSidebar()
        }
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            switch event {
            case .menuToggle(let isPressed), .start(let isPressed):
                if isPressed {
                    focusCoordinator.toggleSidebar()
                }
            case .buttonB(let isPressed):
                if isPressed {
                    focusCoordinator.openSidebar()
                }
            default:
                break
            }
        }
        #endif
    }
}

// MARK: - Empty State View
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaEmptyStateView: View {
    let title: String
    let subtitle: String
    /// When true a compact controller-tip row is shown below the subtitle.
    var showControllerTip: Bool = false

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isFocused: Bool
    @State private var pulseOpacity: Double = 0.3

    private var focusID: String { "emptyState.\(title)" }

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

            if showControllerTip {
                TVControllerTipBanner()
                    .padding(.top, 8)
            }

            // Navigation hint with subtle styling
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("tv_media.hint.swipe_navigation", bundle: .module)
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, showControllerTip ? 8 : 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .focusable()
        .focused($isFocused)
        .tvMediaOnMoveCommand { direction in
            if direction == .left, isFocused {
                focusCoordinator.openSidebar()
            }
        }
        .onAppear {
            isFocused = true
            focusCoordinator.registerLeftEdgeItem(focusID)
            focusCoordinator.contentItemFocused(id: focusID, isAtLeftEdge: true)
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.15
            }
        }
        .onChange(of: isFocused) { focused in
            if focused {
                focusCoordinator.contentItemFocused(id: focusID, isAtLeftEdge: true)
            }
        }
        .onDisappear {
            focusCoordinator.unregisterLeftEdgeItem(focusID)
        }
    }
}

// MARK: - Empty Library Action Buttons

/// Focusable action buttons for the empty library state
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaEmptyLibraryActionButtons: View {
    let onSettings: () -> Void
    let onImportStatus: () -> Void

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

    private enum ButtonID: Hashable {
        case settings
        case importStatus
        case helpWiki
    }

    @FocusState private var focusedButton: ButtonID?

    private var isAnyButtonFocused: Bool {
        focusedButton != nil
    }

    var body: some View {
        HStack(spacing: 24) {
            actionButton(
                id: .settings,
                icon: "gearshape",
                title: "SETTINGS",
                accentColor: Color.retroPink,
                action: onSettings
            )

            actionButton(
                id: .importStatus,
                icon: "tray.and.arrow.down",
                title: "IMPORT STATUS",
                accentColor: Color.retroBlue,
                action: onImportStatus
            )

            NavigationLink(destination: WikiHelpView()) {
                HStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: focusedButton == .helpWiki ? .semibold : .regular))
                    Text("tv_media.help_wiki", bundle: .module)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(1)
                }
                .foregroundStyle(focusedButton == .helpWiki ? .white : .white.opacity(0.8))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.retroPurple.opacity(focusedButton == .helpWiki ? 0.35 : 0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    Color.retroPurple.opacity(focusedButton == .helpWiki ? 0.8 : 0.4),
                                    lineWidth: focusedButton == .helpWiki ? 2 : 1
                                )
                        )
                )
                .shadow(color: focusedButton == .helpWiki ? Color.retroPurple.opacity(0.5) : .clear, radius: 12, x: 0, y: 4)
                .scaleEffect(focusedButton == .helpWiki ? 1.05 : 1.0)
                .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: focusedButton == .helpWiki)
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
            .focused($focusedButton, equals: .helpWiki)
        }
        .tvMediaOnMoveCommand { direction in
            if direction == .left, focusedButton == .settings {
                focusCoordinator.openSidebar()
            }
        }
        .onAppear {
            let focusID = "emptyLibraryButtons"
            focusCoordinator.registerLeftEdgeItem(focusID)
            focusCoordinator.contentItemFocused(id: focusID, isAtLeftEdge: true)
        }
        .onChange(of: focusedButton) { newValue in
            if newValue != nil {
                let isAtLeftEdge = newValue == .settings
                focusCoordinator.contentItemFocused(id: "emptyLibraryButtons", isAtLeftEdge: isAtLeftEdge)
            }
        }
        .onDisappear {
            focusCoordinator.unregisterLeftEdgeItem("emptyLibraryButtons")
        }
    }

    @ViewBuilder
    private func actionButton(
        id: ButtonID,
        icon: String,
        title: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedButton == id

        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isFocused ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1)
            }
            .foregroundStyle(isFocused ? .white : .white.opacity(0.8))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(isFocused ? 0.35 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                accentColor.opacity(isFocused ? 0.8 : 0.4),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .shadow(color: isFocused ? accentColor.opacity(0.5) : .clear, radius: 12, x: 0, y: 4)
            .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($focusedButton, equals: id)
    }
}

// MARK: - Visible Section Preference Key

/// Represents a section's visibility info for tracking scroll position
@available(tvOS 16.0, iOS 17.0, *)
struct VisibleSectionInfo: Equatable {
    let id: String
    let minY: CGFloat
}

/// Preference key for tracking which section is currently visible
@available(tvOS 16.0, iOS 17.0, *)
struct VisibleSectionPreferenceKey: PreferenceKey {
    static var defaultValue: [VisibleSectionInfo] = []

    static func reduce(value: inout [VisibleSectionInfo], nextValue: () -> [VisibleSectionInfo]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Scroll Index Rail

/// A vertical rail showing system icons/abbreviations for quick navigation
/// Also shows current scroll position indicator
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaScrollIndexRail: View {
    let systems: [PVSystem]
    let hasFavorites: Bool
    /// Currently visible/focused section in the main content
    @Binding var currentSection: String?
    let onSelectSystem: (String) -> Void
    let onSelectFavorites: () -> Void
    let onSelectTop: () -> Void

    private enum IndexItem: Hashable {
        case top
        case favorites
        case system(String)
    }

    @FocusState private var focusedItem: IndexItem?
    @State private var isExpanded = false

    /// Check if an item is the current section (for position indicator)
    private func isCurrentSection(_ item: IndexItem) -> Bool {
        guard let current = currentSection else { return false }
        switch item {
        case .top:
            return current == "home_top"
        case .favorites:
            return current == "favorites"
        case .system(let id):
            return current == "system_\(id)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    // Top button
                    indexButton(
                        item: .top,
                        icon: Image(systemName: "chevron.up"),
                        label: "TOP",
                        action: onSelectTop
                    )

                    // Favorites
                    if hasFavorites {
                        indexButton(
                            item: .favorites,
                            icon: Image(systemName: "heart.fill"),
                            label: "FAVS",
                            action: onSelectFavorites
                        )
                    }

                    // Divider
                    if hasFavorites {
                        Rectangle()
                            .fill(Color.retroPink.opacity(0.3))
                            .frame(width: isExpanded ? 60 : 28, height: 1)
                            .padding(.vertical, 4)
                    }

                    // Systems
                    ForEach(systems, id: \.identifier) { system in
                        let abbrev = systemAbbreviation(system)
                        systemIndexButton(
                            system: system,
                            abbreviation: abbrev,
                            action: { onSelectSystem(system.identifier) }
                        )
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(width: isExpanded ? 90 : 48)
        .background(railBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onChange(of: focusedItem) { newValue in
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded = newValue != nil
            }
        }
        .tvMediaFocusSection()
    }

    @ViewBuilder
    private func indexButton(
        item: IndexItem,
        icon: Image,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedItem == item
        let isCurrent = isCurrentSection(item)

        Button(action: action) {
            HStack(spacing: 6) {
                // Position indicator dot
                if isCurrent && !isFocused {
                    Circle()
                        .fill(Color.retroBlue)
                        .frame(width: 4, height: 4)
                }

                icon
                    .font(.system(size: 12, weight: isFocused || isCurrent ? .bold : .medium))
                    .foregroundStyle(isFocused ? .white : (isCurrent ? Color.retroBlue : .white.opacity(0.7)))

                if isExpanded {
                    Text(label)
                        .font(.system(size: 10, weight: isFocused || isCurrent ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(isFocused ? .white : (isCurrent ? Color.retroBlue : .white.opacity(0.6)))
                        .lineLimit(1)
                }
            }
            .frame(width: isExpanded ? 80 : 38, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFocused ? Color.retroPink.opacity(0.4) : (isCurrent ? Color.retroBlue.opacity(0.15) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.retroPink.opacity(0.8) : (isCurrent ? Color.retroBlue.opacity(0.5) : Color.clear),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($focusedItem, equals: item)
        .animation(Animation.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .animation(Animation.easeOut(duration: 0.2), value: isCurrent)
    }

    @ViewBuilder
    private func systemIndexButton(
        system: PVSystem,
        abbreviation: String,
        action: @escaping () -> Void
    ) -> some View {
        let item = IndexItem.system(system.identifier)
        let isFocused = focusedItem == item
        let isCurrent = isCurrentSection(item)

        Button(action: action) {
            HStack(spacing: 6) {
                // Position indicator dot
                if isCurrent && !isFocused {
                    Circle()
                        .fill(Color.retroBlue)
                        .frame(width: 4, height: 4)
                }

                if isExpanded {
                    // Expanded mode: show full short name
                    Text(system.shortName.isEmpty ? system.name : system.shortName)
                        .font(.system(size: 11, weight: isFocused || isCurrent ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(isFocused ? .white : (isCurrent ? Color.retroBlue : .white.opacity(0.7)))
                        .lineLimit(1)
                } else {
                    // Compact mode: show abbreviation
                    Text(abbreviation)
                        .font(.system(size: 10, weight: isFocused || isCurrent ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(isFocused ? .white : (isCurrent ? Color.retroBlue : .white.opacity(0.7)))
                        .frame(width: 32)
                }
            }
            .frame(width: isExpanded ? 80 : 38, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFocused ? Color.retroPink.opacity(0.4) : (isCurrent ? Color.retroBlue.opacity(0.15) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.retroPink.opacity(0.8) : (isCurrent ? Color.retroBlue.opacity(0.5) : Color.clear),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($focusedItem, equals: item)
        .animation(Animation.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .animation(Animation.easeOut(duration: 0.2), value: isCurrent)
    }

    /// Extract short identifier from system (e.g., "gba" from "com.provenance.gba")
    private func systemAbbreviation(_ system: PVSystem) -> String {
        // First try to get short form from identifier
        let idShort = system.identifier.components(separatedBy: ".").last?.uppercased() ?? ""
        if !idShort.isEmpty && idShort.count <= 5 {
            return idShort
        }
        // Fallback to shortName
        let short = system.shortName
        if !short.isEmpty && short.count <= 5 {
            return short.uppercased()
        }
        // Last resort: first 3 chars of name
        return String(system.name.prefix(3)).uppercased()
    }

    private var railBackground: some View {
        ZStack {
            // Dark base
            Color.black.opacity(0.75)

            // Subtle gradient
            LinearGradient(
                colors: [
                    Color.retroPink.opacity(0.05),
                    Color.retroBlue.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Left edge glow when expanded
            if isExpanded {
                HStack {
                    Rectangle()
                        .fill(Color.retroPink.opacity(0.2))
                        .frame(width: 1)
                        .blur(radius: 2)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Saves View (with empty state handling)

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSavesView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var saveStatesStore: RetroSaveStatesStore
    @ObservedObject var router: TVMediaRouter

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isEmptyStateFocused: Bool
    @FocusState private var focusedSaveID: String?
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif
    @State private var gridWidth: CGFloat = 0
    @State private var allSaves: [RetroSaveStateItem] = []
    @State private var filteredSaves: [RetroSaveStateItem] = []
    @State private var isLoading = true
    @State private var availableSystemIDs: [String] = []
    @State private var selectedSystems: Set<String> = []
    @State private var isAutoFiltered = false
    @State private var isFilterPickerPresented = false
    @FocusState private var isFilterButtonFocused: Bool

    private var displayTitle: String {
        if isAutoFiltered, let systemID = selectedSystems.first {
            let systemName = model.systems.first(where: { $0.identifier == systemID })?.shortName ?? systemID
            return "\(systemName) Saves"
        }
        return "Save States"
    }

    #if os(iOS)
    private var tvMediaSavesFocusedSaveBinding: FocusState<String?>.Binding? { $focusedSaveID }
    #else
    private var tvMediaSavesFocusedSaveBinding: FocusState<String?>.Binding? { nil }
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                headerView

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if filteredSaves.isEmpty {
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
        .task {
            await initializeFilters()
            await loadAllSaves()
            applyFilter()
            if filteredSaves.isEmpty {
                isEmptyStateFocused = true
            }
        }
        .onChange(of: selectedSystems) { _ in
            applyFilter()
        }
        .onChange(of: router.saveSystemFilter) { newFilter in
            // Reset to show all when navigating from sidebar (filter is empty)
            if newFilter.isEmpty && isAutoFiltered {
                selectedSystems = []
                isAutoFiltered = false
                applyFilter()
            } else if !newFilter.isEmpty {
                selectedSystems = newFilter
                isAutoFiltered = true
                applyFilter()
            }
        }
        .sheet(isPresented: $isFilterPickerPresented) {
            TVMediaSystemFilterPicker(
                availableSystemIDs: availableSystemIDs,
                selectedSystems: $selectedSystems,
                model: model,
                onDismiss: { isFilterPickerPresented = false }
            )
        }
    }

    private var headerView: some View {
        HStack(spacing: 18) {
            TVMediaTopBar(title: displayTitle)

            Spacer()

            if !isAutoFiltered && !availableSystemIDs.isEmpty {
                filterButton
            }
        }
    }

    private var filterButton: some View {
        let hasFilter = !selectedSystems.isEmpty
        let accentColor = hasFilter ? Color.retroBlue : .white.opacity(0.6)

        return Button {
            isFilterPickerPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                Text(filterButtonLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(isFilterButtonFocused ? .white : accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFilterButtonFocused ? accentColor : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isFilterButtonFocused ? accentColor : (hasFilter ? Color.retroBlue.opacity(0.5) : Color.white.opacity(0.1)),
                        lineWidth: isFilterButtonFocused ? 2 : 1
                    )
            )
            .scaleEffect(isFilterButtonFocused ? 1.03 : 1.0)
            .animation(Animation.spring(response: 0.2, dampingFraction: 0.7), value: isFilterButtonFocused)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($isFilterButtonFocused)
    }

    private var filterButtonLabel: String {
        if selectedSystems.isEmpty {
            return "All Systems"
        } else if selectedSystems.count == 1, let systemID = selectedSystems.first {
            return model.systems.first(where: { $0.identifier == systemID })?.shortName ?? "1 System"
        } else {
            return "\(selectedSystems.count) Systems"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text(selectedSystems.isEmpty ? "No Save States" : "No Saves for Selection")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(selectedSystems.isEmpty ?
                 "Play some games and create save states to see them here." :
                 "No save states found for the selected systems.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            if !selectedSystems.isEmpty && !isAutoFiltered {
                Button {
                    selectedSystems = []
                } label: {
                    Text("tv_media.filter.clear", bundle: .module)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Color.retroBlue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.retroBlue.opacity(0.6), lineWidth: 1.5)
                        )
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                .padding(.top, 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("tv_media.hint.swipe_navigation", bundle: .module)
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }

    private var saveStatesGrid: some View {
        let spacing: CGFloat = 18
        let tileWidth: CGFloat = 300
        let effectiveWidth = gridWidth > 0 ? gridWidth : max(1, UIScreen.main.bounds.width - 120)
        let columnsPerRow = max(1, Int((effectiveWidth + spacing) / (tileWidth + spacing)))

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth), spacing: spacing)],
            spacing: spacing
        ) {
            ForEach(filteredSaves.indices, id: \.self) { index in
                let item = filteredSaves[index]
                let isAtLeftEdge = (index % columnsPerRow) == 0
                TVMediaSaveStateTileButton(
                    item: item,
                    store: saveStatesStore,
                    isAtLeftEdge: isAtLeftEdge,
                    focusCoordinator: focusCoordinator,
                    focusedSaveID: tvMediaSavesFocusedSaveBinding,
                    onDeleteCompleted: { deletedID in
                        allSaves.removeAll { $0.id == deletedID }
                        filteredSaves.removeAll { $0.id == deletedID }
                        Task {
                            await loadAllSaves()
                            applyFilter()
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tvMediaFocusSection()
        .tvMediaTrackWidth { gridWidth = $0 }
        .onAppear {
            if focusedSaveID == nil, let first = filteredSaves.first {
                focusedSaveID = first.id
            }
        }
        .onChange(of: filteredSaves) { _ in
            if focusedSaveID == nil, let first = filteredSaves.first {
                focusedSaveID = first.id
            }
        }
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected, !filteredSaves.isEmpty else { return }
            switch event {
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveSaveFocus(horizontal: value > 0 ? 1 : -1, vertical: 0, columnsPerRow: columnsPerRow)
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveSaveFocus(horizontal: 0, vertical: value < 0 ? 1 : -1, columnsPerRow: columnsPerRow)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                if let id = focusedSaveID,
                   let item = filteredSaves.first(where: { $0.id == id }) {
                    Task { await saveStatesStore.openSaveState(id: item.id) }
                }
            case .buttonB(let isPressed):
                guard isPressed else { return }
                focusCoordinator.openSidebar()
            case .menuToggle(let isPressed):
                if isPressed {
                    focusCoordinator.toggleSidebar()
                }
            default:
                break
            }
        }
        #endif
        .onChange(of: gridWidth) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
        .onChange(of: focusCoordinator.focusedContentID) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
    }

    private func syncFocusedEdgeState(columnsPerRow: Int) {
        guard let focusedID = focusCoordinator.focusedContentID else { return }
        guard let index = filteredSaves.firstIndex(where: { $0.id == focusedID }) else { return }
        let isAtLeftEdge = (index % max(columnsPerRow, 1)) == 0
        focusCoordinator.contentItemFocused(id: focusedID, isAtLeftEdge: isAtLeftEdge)
    }

    #if os(iOS)
    private func moveSaveFocus(horizontal: Int, vertical: Int, columnsPerRow: Int) {
        guard !filteredSaves.isEmpty else { return }
        let ids = filteredSaves.map(\.id)
        let currentID = focusedSaveID ?? ids[0]
        guard let currentIndex = ids.firstIndex(of: currentID) else { return }
        let currentCol = currentIndex % columnsPerRow
        let currentRow = currentIndex / columnsPerRow
        var newRow = currentRow + vertical
        var newCol = currentCol + horizontal
        if horizontal < 0, currentCol == 0 {
            if currentRow == 0 {
                focusCoordinator.openSidebar()
                return
            }
            newRow = currentRow - 1
            newCol = columnsPerRow - 1
        }
        let newIndex = (newRow * columnsPerRow) + newCol
        guard newIndex >= 0, newIndex < ids.count else { return }
        focusedSaveID = ids[newIndex]
        let isAtLeftEdge = (newIndex % columnsPerRow) == 0
        focusCoordinator.contentItemFocused(id: ids[newIndex], isAtLeftEdge: isAtLeftEdge)
    }
    #endif

    private func initializeFilters() async {
        availableSystemIDs = await saveStatesStore.systemIDsWithSaves()

        let routerFilter = router.saveSystemFilter
        if !routerFilter.isEmpty {
            selectedSystems = routerFilter
            isAutoFiltered = true
        }
    }

    private func loadAllSaves() async {
        let saves = await saveStatesStore.loadAllRecent(limit: 200)
        await MainActor.run {
            allSaves = saves
            isLoading = false
        }
    }

    private func applyFilter() {
        if selectedSystems.isEmpty {
            filteredSaves = allSaves
        } else {
            filteredSaves = allSaves.filter { selectedSystems.contains($0.systemId) }
        }
    }
}

/// Multi-select system filter picker for saves
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemFilterPicker: View {
    let availableSystemIDs: [String]
    @Binding var selectedSystems: Set<String>
    @ObservedObject var model: TVMediaLibraryModel
    let onDismiss: () -> Void

    @FocusState private var focusedSystemID: String?
    @Namespace private var pickerNamespace

    var body: some View {
        ZStack {
            TVMediaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 60)
                    .padding(.top, 50)
                    .padding(.bottom, 24)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableSystemIDs, id: \.self) { systemID in
                            systemRow(for: systemID)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 60)
                }
                .tvMediaFocusSection()
            }
        }
        .tvMediaFocusScope(pickerNamespace)
        .tvMediaOnExitCommand {
            onDismiss()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("tv_media.filter.by_system", bundle: .module)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 8)

                Text("tv_media.filter.select_systems", bundle: .module)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: 16) {
                TVMediaFilterHeaderButton(
                    title: "SELECT ALL",
                    accentColor: Color.retroBlue,
                    action: { selectedSystems = Set(availableSystemIDs) }
                )

                TVMediaFilterHeaderButton(
                    title: "CLEAR",
                    accentColor: .white.opacity(0.5),
                    action: { selectedSystems = [] }
                )

                TVMediaFilterHeaderButton(
                    title: "DONE",
                    icon: "checkmark",
                    accentColor: Color.retroPink,
                    isPrimary: true,
                    action: onDismiss
                )
            }
        }
    }

    @ViewBuilder
    private func systemRow(for systemID: String) -> some View {
        let isSelected = selectedSystems.contains(systemID)
        let isFocused = focusedSystemID == systemID
        let system = model.systems.first(where: { $0.identifier == systemID })
        let systemName = system?.name ?? systemID
        let shortName = system?.shortName ?? ""

        Button {
            if isSelected {
                selectedSystems.remove(systemID)
            } else {
                selectedSystems.insert(systemID)
            }
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.retroBlue.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 32, height: 32)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.retroBlue)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.retroBlue : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    if !shortName.isEmpty && shortName != systemName {
                        Text(shortName.uppercased())
                            .font(.system(size: 12, weight: .medium))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.retroBlue)
                        .shadow(color: Color.retroBlue.opacity(0.5), radius: 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isFocused ?
                            (isSelected ? Color.retroBlue.opacity(0.08) : Color.white.opacity(0.06)) :
                            (isSelected ? Color.retroBlue.opacity(0.04) : Color.white.opacity(0.02))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isFocused ?
                            (isSelected ?
                                LinearGradient(colors: [Color.retroBlue.opacity(0.8), Color.retroPink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ) :
                            LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvMediaFocusable()
        .tvOSDisableFocusEffect()
        .focused($focusedSystemID, equals: systemID)
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

/// A consistent header button for filter overlays
@available(tvOS 16.0, iOS 17.0, *)
private struct TVMediaFilterHeaderButton: View {
    let title: String
    var icon: String? = nil
    var accentColor: Color = .white
    var isPrimary: Bool = false
    let action: () -> Void

    @FocusState private var isFocused: Bool

    private let buttonWidth: CGFloat = 140

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(isFocused ? .white : accentColor)
            .frame(width: buttonWidth, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isFocused ? accentColor : accentColor.opacity(isPrimary ? 0.7 : 0.4),
                        lineWidth: isPrimary ? 2 : 1.5
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(Animation.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvMediaFocusable()
        .tvOSDisableFocusEffect()
        .focused($isFocused)
    }
}

@available(tvOS 16.0, iOS 17.0, *)
private struct TVMediaSaveStateTileButton: View {
    let item: RetroSaveStateItem
    @ObservedObject var store: RetroSaveStatesStore
    let isAtLeftEdge: Bool
    var focusCoordinator: TVMediaFocusCoordinator?
    var focusedSaveID: FocusState<String?>.Binding?
    let onDeleteCompleted: (String) -> Void

    @FocusState private var isFocusedInternal: Bool
    @State private var thumbnail: UIImage?

    private var isFocused: Bool {
        if let focusedSaveID {
            return focusedSaveID.wrappedValue == item.id
        }
        return isFocusedInternal
    }

    init(
        item: RetroSaveStateItem,
        store: RetroSaveStatesStore,
        isAtLeftEdge: Bool = false,
        focusCoordinator: TVMediaFocusCoordinator? = nil,
        focusedSaveID: FocusState<String?>.Binding? = nil,
        onDeleteCompleted: @escaping (String) -> Void = { _ in }
    ) {
        self.item = item
        self.store = store
        self.isAtLeftEdge = isAtLeftEdge
        self.focusCoordinator = focusCoordinator
        self.focusedSaveID = focusedSaveID
        self.onDeleteCompleted = onDeleteCompleted
    }

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
        .tvMediaFocusable()
        .tvOSDisableFocusEffect()
        .focused($isFocusedInternal)
        .tvMediaOnMoveCommand { direction in
            if direction == .left, isFocused, isAtLeftEdge {
                focusCoordinator?.openSidebar()
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await deleteSaveState() }
            } label: {
                Label("Delete Save State", systemImage: "trash")
            }
        }
        .task(id: item.id, priority: TaskPriority.utility) {
            // Load thumbnail with utility priority to avoid blocking scroll performance
            thumbnail = await store.thumbnail(for: item, targetSize: CGSize(width: 280, height: 180))
        }
        .onChange(of: isFocused) { focused in
            if focused {
                focusCoordinator?.contentItemFocused(id: item.id, isAtLeftEdge: isAtLeftEdge)
            }
        }
        .onAppear {
            if isAtLeftEdge {
                focusCoordinator?.registerLeftEdgeItem(item.id)
            }
        }
        .onDisappear {
            focusCoordinator?.unregisterLeftEdgeItem(item.id)
        }
    }

    private func deleteSaveState() async {
        let deletedID = item.id
        let systemID = item.systemId
        await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: item.id) else { return }
            do {
                try RomDatabase.sharedInstance.delete(saveState: saveState)
                store.removeFromCache(id: deletedID, systemID: systemID)
                onDeleteCompleted(deletedID)
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

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaHomeView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var saveStatesStore: RetroSaveStatesStore
    @ObservedObject var gameActions: TVMediaGameActions
    @ObservedObject var router: TVMediaRouter

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @State private var isLoading = true
    @State private var currentSection: String? = "home_top"
    @State private var recentSaveLoadsRequested: Set<String> = []
#if canImport(PVWebServer)
    @State private var webServerURL: String?
#endif

    /// Check if we have any games at all
    private var hasAnyGames: Bool {
        if LaunchArgument.forceEmptyLibrary.isEnabled { return false }
        return model.gamesBySystemIdentifier.values.contains { !$0.isEmpty }
    }

    /// Systems that have games for the scroll index
    private var systemsWithGames: [PVSystem] {
        model.systems.filter { system in
            let games = model.gamesBySystemIdentifier[system.identifier] ?? []
            return !games.isEmpty
        }
    }

    var body: some View {
        let favorites = model.favoriteGames(limit: 40)
        let hasFavorites = !favorites.isEmpty
        let visibleSystems = systemsWithGames

        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        TVMediaTopBar(title: "Home")
                            .id("home_top")
                            .onAppear { currentSection = "home_top" }

                        if isLoading && model.gamesBySystemIdentifier.isEmpty {
                            // Show loading state
                            loadingView
                        } else if !hasAnyGames {
                            // Empty library state
                            emptyLibraryView
                                .tvMediaFocusSection()
                        } else {
                            // Favorites section
                            if hasFavorites {
                                TVMediaShelf(title: "Favorites", items: favorites, gameActions: gameActions)
                                    .id("favorites")
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: VisibleSectionPreferenceKey.self,
                                                value: [VisibleSectionInfo(id: "favorites", minY: geo.frame(in: .named("tvMediaHomeScroll")).minY)]
                                            )
                                        }
                                    )
                            }

                            // System shelves - iterate all systems, only show if they have games
                            ForEach(model.systems, id: \.identifier) { system in
                                let games = model.gamesBySystemIdentifier[system.identifier] ?? []
                                let sectionID = "system_\(system.identifier)"

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
                                    .id(sectionID)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: VisibleSectionPreferenceKey.self,
                                                value: [VisibleSectionInfo(id: sectionID, minY: geo.frame(in: .named("tvMediaHomeScroll")).minY)]
                                            )
                                        }
                                    )
                                    .task {
                                        await loadRecentSavesIfNeeded(for: system.identifier)
                                    }

                                    if let recent = saveStatesStore.recentBySystem[system.identifier], !recent.isEmpty {
                                        TVMediaSaveStatesShelfRow(
                                            title: "\(system.shortName) · SAVES",
                                            items: recent,
                                            store: saveStatesStore,
                                            onViewAll: {
                                                router.navigateToSaves(filterBySystem: system.identifier)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .coordinateSpace(name: "tvMediaHomeScroll")
                .onPreferenceChange(VisibleSectionPreferenceKey.self) { sections in
                    // Find the section closest to the top of the screen (but still visible)
                    // A section is "current" if its top is near or above the top of the visible area
                    let threshold: CGFloat = 250 // Adjust based on header height
                    let nextSectionID: String?
                    if let topSection = sections
                        .filter({ $0.minY < threshold })
                        .max(by: { $0.minY < $1.minY }) {
                        nextSectionID = topSection.id
                    } else if let firstVisible = sections.min(by: { $0.minY < $1.minY }) {
                        nextSectionID = firstVisible.id
                    } else {
                        nextSectionID = nil
                    }

                    if currentSection != nextSectionID {
                        currentSection = nextSectionID
                    }
                }

                // Scroll index rail - only show when there are multiple systems
                if visibleSystems.count > 2 && !isLoading {
                    TVMediaScrollIndexRail(
                        systems: visibleSystems,
                        hasFavorites: hasFavorites,
                        currentSection: $currentSection,
                        onSelectSystem: { systemID in
                            currentSection = "system_\(systemID)"
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("system_\(systemID)", anchor: .top)
                            }
                        },
                        onSelectFavorites: {
                            currentSection = "favorites"
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("favorites", anchor: .top)
                            }
                        },
                        onSelectTop: {
                            currentSection = "home_top"
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("home_top", anchor: .top)
                            }
                        }
                    )
                    .padding(.trailing, 20)
                }
            }
        }
        .task {
            await loadAllGames()
        }
#if canImport(PVWebServer)
        .onAppear {
            refreshWebServerURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebServerStatusChanged"))) { _ in
            refreshWebServerURL()
        }
#endif
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("tv_media.library.loading", bundle: .module)
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
                Text("tv_media.library.no_games", bundle: .module)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .shadow(color: Color.retroPink.opacity(0.4), radius: 8)

                Text("tv_media.library.add_roms_hint", bundle: .module)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
#if canImport(PVWebServer)

                if let webServerURL {
                    Text(webServerURL)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.retroBlue)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 600)
                        .padding(.top, 2)
                }
#endif
            }

            // Action buttons for first-time users
            TVMediaEmptyLibraryActionButtons(
                onSettings: { router.navigate(to: .settings) },
                onImportStatus: { router.activeModal = .importStatus }
            )
            .padding(.top, 8)

            // Sync status hint
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 14))
                    Text("tv_media.library.icloud_in_progress", bundle: .module)
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

            // Controller guide — hardware controller is required for most games
            Divider()
                .background(Color.retroBlue.opacity(0.2))
                .padding(.vertical, 8)

            TVControllerGuideSection()
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func loadAllGames() async {
        isLoading = true
        defer { isLoading = false }
        // Load systems with a small concurrency cap to reduce startup time
        // without overwhelming Realm or the device on setups with many systems.
        let maxConcurrentLoads = 4

        await withTaskGroup(of: Void.self) { group in
            var systemsIterator = model.systems.makeIterator()

            // Prime the task group with up to `maxConcurrentLoads` systems.
            var started = 0
            while started < maxConcurrentLoads, let system = systemsIterator.next() {
                let id = system.identifier
                started += 1
                group.addTask { await model.loadGamesForSystemAsync(identifier: id) }
            }

            // For any remaining systems, wait for a task to finish before
            // scheduling a new one to keep concurrency bounded.
            while let system = systemsIterator.next() {
                _ = await group.next()
                let id = system.identifier
                group.addTask { await model.loadGamesForSystemAsync(identifier: id) }
            }

            // Drain any remaining tasks.
            while await group.next() != nil {}
        }

        // Auto-expand sidebar if no games to guide first-time users
        if !hasAnyGames {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusCoordinator.openSidebar()
            }
        }
    }

    private func loadRecentSavesIfNeeded(for systemID: String) async {
        let shouldLoad = await MainActor.run { recentSaveLoadsRequested.insert(systemID).inserted }
        guard shouldLoad else { return }
        _ = await saveStatesStore.loadRecent(forSystemID: systemID, limit: 6)
    }

#if canImport(PVWebServer)
    private func refreshWebServerURL() {
        Task { @MainActor in
            guard await PVWebServerManager.shared.isRunning else {
                webServerURL = nil
                return
            }
            webServerURL = await PVWebServerManager.shared.serverURL?.absoluteString
        }
    }
#endif
}

// MARK: - Systems View

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemsView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var router: TVMediaRouter

    @ObservedObject private var iconLoader = SystemIconLoader.shared
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var focusedSystemID: String?
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    /// Number of columns for calculating left edge
    @State private var columnsPerRow: Int = 4
    @State private var gridWidth: CGFloat = 0
    private let gridSpacing: CGFloat = 20

    private var minCardWidth: CGFloat {
        #if os(iOS)
        return 200
        #else
        return 340
        #endif
    }

    private var maxCardWidth: CGFloat {
        #if os(iOS)
        return 260
        #else
        return 420
        #endif
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minCardWidth, maximum: maxCardWidth), spacing: gridSpacing)]
    }

    /// Only show systems that have games.
    /// Uses the pre-loaded snapshot from `model.gamesBySystemIdentifier` to avoid
    /// triggering live Realm queries (`system.games.count`) on the main thread.
    private var systemsWithGames: [PVSystem] {
        model.systems.filter { system in
            guard let cached = model.gamesBySystemIdentifier[system.identifier] else {
                // Not yet loaded — exclude until games are available. A `.task`
                // modifier on this view eagerly triggers loading for all systems,
                // so this guard handles the brief window before loading completes.
                return false
            }
            return !cached.isEmpty
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    TVMediaTopBar(title: "Systems")

                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(systemsWithGames.indices, id: \.self) { index in
                            let system = systemsWithGames[index]
                            let isAtLeftEdge = index % columnsPerRow == 0
                            TVMediaSystemCard(
                                system: system,
                                icon: iconLoader.icon(for: system.identifier),
                                gameCount: model.gamesBySystemIdentifier[system.identifier]?.count ?? 0,
                                isAtLeftEdge: isAtLeftEdge,
                                focusCoordinator: focusCoordinator,
                                focusedSystemID: $focusedSystemID
                            ) {
                                focusCoordinator.closeSidebar()
                                router.navigateToSystem(system.identifier)
                            }
                            .id(system.identifier)
                            .task {
                                model.loadGamesIfNeeded(systemIdentifier: system.identifier)
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
                .tvMediaTrackWidth { width in
                    gridWidth = width
                    let availableWidth = max(width - 120, UIScreen.main.bounds.width - 120)
                    columnsPerRow = max(1, tvMediaAdaptiveColumnsPerRow(
                        availableWidth: availableWidth,
                        minItemWidth: minCardWidth,
                        maxItemWidth: maxCardWidth,
                        spacing: gridSpacing
                    ))
                }
            }
            .onChange(of: focusedSystemID) { newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        // Re-fire icon loading whenever the set of visible systems changes so
        // that icons for systems loaded after first appearance are requested.
        // Use [String] directly (not .joined()) to avoid hash collisions between
        // different arrays that produce the same concatenated string.
        .task(id: systemsWithGames.map(\.identifier)) {
            await iconLoader.loadIcons(for: systemsWithGames)
        }
        .task(id: model.systems.map(\.identifier)) {
            // Trigger a load for any system not yet in the cache so that
            // `systemsWithGames` can populate and show all systems, even
            // on first appearance before shelf rows have lazy-loaded them.
            // Using the full identifiers list (not just count) ensures the task
            // re-fires when systems are replaced or reordered even if count stays the same.
            for system in model.systems {
                model.loadGamesIfNeeded(systemIdentifier: system.identifier)
            }
        }
        .onAppear {
            if focusedSystemID == nil {
                focusedSystemID = systemsWithGames.first?.identifier
            }
        }
        .onChange(of: systemsWithGames.count) { _ in
            // Assign initial focus once the first systems appear in the cache
            // (on first load `systemsWithGames` may be empty during `.onAppear`).
            if focusedSystemID == nil {
                focusedSystemID = systemsWithGames.first?.identifier
            }
        }
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            switch event {
            case .menuToggle(let isPressed):
                if isPressed {
                    focusCoordinator.toggleSidebar()
                }
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: value > 0 ? 1 : -1, vertical: 0)
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: 0, vertical: value < 0 ? 1 : -1)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                if let id = focusedSystemID,
                   let system = systemsWithGames.first(where: { $0.identifier == id }) {
                    focusCoordinator.closeSidebar()
                    router.navigateToSystem(system.identifier)
                }
            case .buttonB(let isPressed):
                guard isPressed else { return }
                focusCoordinator.openSidebar()
            default:
                break
            }
        }
        #endif
    }

    private func moveFocus(horizontal: Int, vertical: Int) {
        let systems = systemsWithGames
        guard !systems.isEmpty else { return }
        let ids = systems.map { $0.identifier }
        let currentID = focusedSystemID ?? ids[0]
        guard let currentIndex = ids.firstIndex(of: currentID) else { return }
        let currentCol = currentIndex % columnsPerRow
        let currentRow = currentIndex / columnsPerRow
        var newRow = currentRow + vertical
        var newCol = currentCol + horizontal
        if horizontal < 0, currentCol == 0 {
            if currentRow == 0 {
                focusCoordinator.openSidebar()
                return
            }
            newRow = currentRow - 1
            newCol = columnsPerRow - 1
        }
        let newIndex = (newRow * columnsPerRow) + newCol
        guard newIndex >= 0, newIndex < ids.count else { return }
        focusedSystemID = ids[newIndex]
    }
}

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemCard: View {
    let system: PVSystem
    let icon: Image?
    let gameCount: Int
    let isAtLeftEdge: Bool
    var focusCoordinator: TVMediaFocusCoordinator?
    let focusedSystemID: FocusState<String?>.Binding
    let action: () -> Void

    private var isFocused: Bool {
        focusedSystemID.wrappedValue == system.identifier
    }

    @State private var glowIntensity: Double = 0

    init(
        system: PVSystem,
        icon: Image?,
        gameCount: Int,
        isAtLeftEdge: Bool = false,
        focusCoordinator: TVMediaFocusCoordinator? = nil,
        focusedSystemID: FocusState<String?>.Binding,
        action: @escaping () -> Void
    ) {
        self.system = system
        self.icon = icon
        self.gameCount = gameCount
        self.isAtLeftEdge = isAtLeftEdge
        self.focusCoordinator = focusCoordinator
        self.focusedSystemID = focusedSystemID
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
                                Text(verbatim: "\(gameCount)")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isFocused ? Color.retroBlue : .white.opacity(0.6))
                                Text("tv_media.games", bundle: .module)
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
        .tvMediaFocusable()
        .focused(focusedSystemID, equals: system.identifier)
        .onChange(of: isFocused) { focused in
            withAnimation(.easeOut(duration: focused ? 0.3 : 0.15)) {
                glowIntensity = focused ? 0.8 : 0
            }
        }
        .tvMediaOnMoveCommand { direction in
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
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemCardButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: isFocused ? Color.retroPink.opacity(0.35) : .clear, radius: 20, x: 0, y: 6)
            .animation(Animation.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)
            .animation(Animation.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Flat button style - no background, scale on focus
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaFlatButtonStyle: ButtonStyle {
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(Animation.spring(response: 0.22, dampingFraction: 0.85), value: isFocused)
    }
}

/// View All card that appears at the end of horizontal shelves
@available(tvOS 16.0, iOS 17.0, *)
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
        .tvOSDisableFocusEffect()
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

/// View All card for save states shelf
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSaveStatesViewAllCard: View {
    let count: Int
    let action: () -> Void

    @FocusState private var isFocused: Bool

    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 190

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    if isFocused {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.retroBlue.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                    }

                    Image(systemName: "rectangle.stack.badge.play")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(
                            isFocused ?
                                AnyShapeStyle(LinearGradient(
                                    colors: [.white, Color.retroBlue.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )) :
                                AnyShapeStyle(Color.white.opacity(0.5))
                        )
                        .shadow(color: isFocused ? Color.retroBlue.opacity(0.6) : .clear, radius: 8)
                }

                VStack(spacing: 4) {
                    Text("tv_media.saves.view_all", bundle: .module)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(1)
                        .foregroundStyle(isFocused ? .white : .white.opacity(0.8))

                    Text("tv_media.saves.count \(count)", bundle: .module)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isFocused ?
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.12), Color.retroPink.opacity(0.06)],
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
                                colors: [Color.retroBlue.opacity(0.8), Color.retroPink.opacity(0.5)],
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
            .shadow(color: isFocused ? Color.retroBlue.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - System Games View

@available(tvOS 16.0, iOS 17.0, *)
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
                            TVMediaSaveStatesShelfRow(
                                title: "Recent Saves",
                                items: recentSaves,
                                store: saveStatesStore,
                                onViewAll: {
                                    router.navigateToSaves(filterBySystem: system.identifier)
                                }
                            )
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

                                Text(verbatim: "ALL \(system.shortName.uppercased()) GAMES")
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .tracking(1.2)
                                    .foregroundStyle(.white.opacity(0.95))

                                Spacer()

                                let gameCount = model.gamesBySystemIdentifier[system.identifier]?.count ?? 0
                                Text(verbatim: "\(gameCount) GAMES")
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
            .tvMediaOnMoveCommand { direction in
                if direction == .up {
                    // When at top of games grid and pressing up, scroll to header
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(headerID, anchor: .top)
                    }
                }
                if direction == .left, focusCoordinator.shouldNavigateToSidebar() {
                    focusCoordinator.openSidebar()
                }
            }
        }
        .task {
            isLoading = true
            defer { isLoading = false }
            await loadContent()
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

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemHeader: View {
    let system: PVSystem

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // TVMediaSystemIconView isolates the icon-load observer so only this
            // container redraws when the icon arrives, not the whole header row.
            TVMediaSystemIconView(
                systemIdentifier: system.identifier,
                size: 52,
                placeholder: "gamecontroller.fill"
            )
            .foregroundStyle(.white.opacity(0.85))
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
            await SystemIconLoader.shared.loadIcons(for: [system])
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
}

// MARK: - All Games Grid

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaAllGamesGrid: View {
    let games: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var focusedGameID: String?
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    @State private var gridWidth: CGFloat = 0

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)
    ]

    var body: some View {
        let spacing: CGFloat = 20
        let minItemWidth: CGFloat = 260
        let maxItemWidth: CGFloat = 300
        let effectiveWidth = gridWidth > 0 ? gridWidth : max(1, UIScreen.main.bounds.width - 120)
        let columnsPerRow = tvMediaAdaptiveColumnsPerRow(
            availableWidth: effectiveWidth,
            minItemWidth: minItemWidth,
            maxItemWidth: maxItemWidth,
            spacing: spacing
        )

        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(games.indices, id: \.self) { index in
                let game = games[index]
                // First column in each row is at left edge
                let isAtLeftEdge = index % columnsPerRow == 0
                TVMediaGameTileView(
                    game: game,
                    titleFont: .headline.weight(.semibold),
                    onPlay: { sceneCoordinator.launchGame(game) },
                    contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                    isAtLeftEdge: isAtLeftEdge,
                    focusCoordinator: focusCoordinator,
                    focusedGameID: $focusedGameID
                )
            }
        }
        .tvMediaTrackWidth { gridWidth = $0 }
        .onChange(of: gridWidth) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
        .onChange(of: focusCoordinator.focusedContentID) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
        .onAppear {
            if focusedGameID == nil {
                focusedGameID = games.first?.id
            }
        }
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            switch event {
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: value > 0 ? 1 : -1, vertical: 0, columnsPerRow: columnsPerRow)
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: 0, vertical: value < 0 ? 1 : -1, columnsPerRow: columnsPerRow)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                if let id = focusedGameID,
                   let game = games.first(where: { $0.id == id }) {
                    sceneCoordinator.launchGame(game)
                }
            case .buttonB(let isPressed):
                guard isPressed else { return }
                focusCoordinator.openSidebar()
            case .menuToggle(let isPressed):
                if isPressed {
                    focusCoordinator.toggleSidebar()
                }
            default:
                break
            }
        }
        #endif
    }

    private func syncFocusedEdgeState(columnsPerRow: Int) {
        guard let focusedID = focusCoordinator.focusedContentID else { return }
        guard let index = games.firstIndex(where: { $0.id == focusedID }) else { return }
        let isAtLeftEdge = (index % max(columnsPerRow, 1)) == 0
        focusCoordinator.contentItemFocused(id: focusedID, isAtLeftEdge: isAtLeftEdge)
    }

    private func moveFocus(horizontal: Int, vertical: Int, columnsPerRow: Int) {
        guard !games.isEmpty else { return }
        let ids = games.map { $0.id }
        let currentID = focusedGameID ?? ids[0]
        guard let currentIndex = ids.firstIndex(of: currentID) else { return }
        let currentCol = currentIndex % columnsPerRow
        let currentRow = currentIndex / columnsPerRow
        var newRow = currentRow + vertical
        var newCol = currentCol + horizontal
        if horizontal < 0, currentCol == 0 {
            if currentRow == 0 {
                focusCoordinator.openSidebar()
                return
            }
            newRow = currentRow - 1
            newCol = columnsPerRow - 1
        }
        let newIndex = (newRow * columnsPerRow) + newCol
        guard newIndex >= 0, newIndex < ids.count else { return }
        focusedGameID = ids[newIndex]
    }
}

// MARK: - Search View

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSearchView: View {
    @ObservedObject var model: TVMediaLibraryModel
    @ObservedObject var gameActions: TVMediaGameActions

    @State private var text: String = ""
    @State private var results: [PVGame] = []
    @State private var isSearching: Bool = false
    @State private var showRecentSearches: Bool = false
    @State private var didRestoreLastSearch: Bool = false
    /// Debounce timer — prevents a Realm search on every keystroke.
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    @AppStorage("TVMediaSearch.lastSearch") private var lastSearch: String = ""
    @AppStorage("TVMediaSearch.recentSearches") private var recentSearchesData: Data = Data()

    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var focusedRecentIndex: Int?
    @FocusState private var isRecentButtonFocused: Bool

    private let maxRecentSearches = 8
    private let searchDebounceInterval: Duration = .milliseconds(300)

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    private func saveRecentSearches(_ searches: [String]) {
        recentSearchesData = (try? JSONEncoder().encode(searches)) ?? Data()
    }

    private func addToRecentSearches(_ query: String) {
        guard !query.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == query.lowercased() }
        searches.insert(query, at: 0)
        if searches.count > maxRecentSearches {
            searches = Array(searches.prefix(maxRecentSearches))
        }
        saveRecentSearches(searches)
    }

    private func removeFromRecentSearches(_ query: String) {
        var searches = recentSearches
        searches.removeAll { $0 == query }
        saveRecentSearches(searches)
    }

    private func clearRecentSearches() {
        saveRecentSearches([])
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                TVMediaTopBar(title: "Search")

                searchField

                if !recentSearches.isEmpty && (text.isEmpty || showRecentSearches) {
                    recentSearchesSection
                }

                if isSearching {
                    searchingIndicator
                } else if text.isEmpty && recentSearches.isEmpty {
                    searchPlaceholder
                } else if !text.isEmpty && results.isEmpty {
                    noResultsView
                } else if !results.isEmpty {
                    TVMediaSearchResultsGrid(results: results, gameActions: gameActions)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .onAppear {
            if !didRestoreLastSearch && !lastSearch.isEmpty {
                didRestoreLastSearch = true
                text = lastSearch
                Task { await performSearch() }
            }
        }
        .onDisappear {
            // Cancel any pending debounce task so it doesn't fire after navigation.
            searchDebounceTask?.cancel()
            searchDebounceTask = nil
        }
    }

    private var searchField: some View {
        HStack(spacing: 16) {
            // Animated search icon with glow
            ZStack {
                if isSearchFieldFocused || !text.isEmpty {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.retroPink.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 4)
                }

            Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        isSearchFieldFocused || !text.isEmpty ?
                            AnyShapeStyle(LinearGradient(
                                colors: [Color.retroPink, Color.retroBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )) :
                            AnyShapeStyle(Color.white.opacity(0.5))
                    )
                    .shadow(color: isSearchFieldFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 8)
            }
            .frame(width: 40)

            TextField("Search games…", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(.white)
                .font(.system(size: 24, weight: .medium))
                .focused($isSearchFieldFocused)
                .onChange(of: text) { _ in
                    // Debounce: cancel any pending search and schedule a new one
                    // after a short delay so we don't query Realm on every keystroke.
                    searchDebounceTask?.cancel()
                    searchDebounceTask = Task {
                        try? await Task.sleep(for: searchDebounceInterval)
                        guard !Task.isCancelled else { return }
                        await performSearch()
                    }
                }
                .onSubmit {
                    // Cancel any pending debounced task and perform search immediately.
                    searchDebounceTask?.cancel()
                    searchDebounceTask = nil
                    if !text.isEmpty {
                        addToRecentSearches(text)
                        lastSearch = text
                        Task { await performSearch() }
                    }
                }

            // Recent searches toggle button
            if !recentSearches.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRecentSearches.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                        Text("tv_media.search.recent", bundle: .module)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(isRecentButtonFocused ? .white : (showRecentSearches ? Color.retroBlue : .white.opacity(0.6)))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isRecentButtonFocused ?
                                    (showRecentSearches ? Color.retroBlue.opacity(0.25) : Color.white.opacity(0.1)) :
                                    (showRecentSearches ? Color.retroBlue.opacity(0.15) : Color.white.opacity(0.05))
                            )
                    )
                    .overlay(
                        Group {
                            if isRecentButtonFocused {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.retroPink.opacity(0.8), Color.retroBlue.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        showRecentSearches ? Color.retroBlue.opacity(0.6) : Color.white.opacity(0.1),
                                        lineWidth: 1.5
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                .focused($isRecentButtonFocused)
                .scaleEffect(isRecentButtonFocused ? 1.05 : 1.0)
                .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isRecentButtonFocused)
            }

            // Clear button
            if !text.isEmpty {
                Button {
                    text = ""
                    results = []
                    lastSearch = ""
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.retroPink.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.retroPink)
                    }
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(searchFieldBackground)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isSearchFieldFocused)
    }

    private var searchFieldBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isSearchFieldFocused ? 0.08 : 0.04),
                        Color.white.opacity(isSearchFieldFocused ? 0.04 : 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSearchFieldFocused ?
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.8), Color.retroBlue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isSearchFieldFocused ? 2 : 1
                    )
            )
            .shadow(color: isSearchFieldFocused ? Color.retroPink.opacity(0.3) : .clear, radius: 20, x: 0, y: 5)
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.retroBlue.opacity(0.5))
                        .frame(width: 3, height: 20)
                        .blur(radius: 3)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.9), Color.retroPink.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 18)
                }

                Text("tv_media.search.recent_searches", bundle: .module)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Clear all button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        clearRecentSearches()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                        Text("tv_media.search.clear_all", bundle: .module)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Color.retroPink.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
        .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.retroPink.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
            }

            // Recent search chips
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(recentSearches.enumerated()), id: \.element) { index, query in
                        recentSearchChip(query: query, index: index)
                    }
                }
                .padding(.vertical, 8)
            }
            .tvMediaFocusSection()
        }
        .transition(.opacity.combined(with: .move(edge: Edge.top)))
    }

    @ViewBuilder
    private func recentSearchChip(query: String, index: Int) -> some View {
        let isFocused = focusedRecentIndex == index

        Button {
            text = query
            lastSearch = query
            Task { await performSearch() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isFocused ? Color.retroBlue : .white.opacity(0.5))

                Text(query)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isFocused ? .white : .white.opacity(0.85))
                    .lineLimit(1)

                // Delete button (visible on focus)
                if isFocused {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            removeFromRecentSearches(query)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.retroPink)
                            .padding(4)
                            .background(Circle().fill(Color.retroPink.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isFocused ?
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.15), Color.retroPink.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.04), Color.white.opacity(0.02)],
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
                                colors: [Color.retroBlue.opacity(0.8), Color.retroPink.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(color: isFocused ? Color.retroBlue.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($focusedRecentIndex, equals: index)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }

    private var searchingIndicator: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.3), Color.retroBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60, height: 60)
                    .blur(radius: 4)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.retroPink))
                    .scaleEffect(1.5)
            }

            Text("tv_media.search.searching", bundle: .module)
                .font(.system(size: 14, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.retroPink, Color.retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.retroPink.opacity(0.5), radius: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var searchPlaceholder: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.retroPink.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

            Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.5), Color.retroBlue.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 10)
            }

            VStack(spacing: 8) {
                Text("tv_media.search.prompt", bundle: .module)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 6)

                Text("tv_media.search.type_hint", bundle: .module)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Navigation hint
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("tv_media.hint.swipe_navigation", bundle: .module)
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.retroPink.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

            Image(systemName: "questionmark.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.6), Color.retroBlue.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 8)
            }

            VStack(spacing: 8) {
                Text("tv_media.search.no_results", bundle: .module)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .tracking(1.5)
                    .foregroundStyle(.white)

                Text("No games found for \"\(text)\"")
                    .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }

            // Suggestion to try different search
            if !recentSearches.isEmpty {
                Text("tv_media.search.try_recent", bundle: .module)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.retroBlue.opacity(0.7))
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
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
            // Save last search for restoration (history is only added on explicit submit)
            if !query.isEmpty {
                lastSearch = query
            }
        }
    }
}

// MARK: - Favorites View

@available(tvOS 16.0, iOS 17.0, *)
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

            Text("tv_media.favorites.no_favorites", bundle: .module)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("tv_media.favorites.mark_hint", bundle: .module)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            // Navigation hint
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.circle")
                    .font(.caption)
                Text("tv_media.hint.swipe_navigation", bundle: .module)
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

// MARK: - System Icon View

/// Isolated view that observes SystemIconLoader only for a single system.
/// Keeping the observation here prevents a shared `@ObservedObject iconLoader`
/// on shelf/header views from triggering full-shelf redraws every time any
/// system icon loads.
@available(tvOS 16.0, iOS 17.0, *)
private struct TVMediaSystemIconView: View {
    let systemIdentifier: String
    let size: CGFloat
    /// Fallback SF Symbol shown while the icon is loading.
    var placeholder: String = "gamecontroller"
    @ObservedObject private var iconLoader = SystemIconLoader.shared

    init(systemIdentifier: String, size: CGFloat = 30, placeholder: String = "gamecontroller") {
        self.systemIdentifier = systemIdentifier
        self.size = size
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let icon = iconLoader.icon(for: systemIdentifier) {
                icon.resizable().scaledToFit()
            } else {
                Image(systemName: placeholder)
                    .font(.system(size: size * 0.55, weight: .light))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shelf Components

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaShelf: View {
    let title: String
    let items: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator
    @Namespace private var shelfNamespace

    private var itemSpacing: CGFloat {
        #if os(iOS)
        return 18
        #else
        return 26
        #endif
    }

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
                LazyHStack(spacing: itemSpacing) {
                    ForEach(items.indices, id: \.self) { index in
                        let game = items[index]
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
            .tvMediaFocusSection()
        }
    }
}

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSystemShelfRow: View {
    let system: PVSystem
    let games: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions
    let onViewAll: () -> Void
    let ensureLoaded: () -> Void

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

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

                // System icon with subtle glow — rendered by TVMediaSystemIconView
                // to isolate icon-load redraws from the parent shelf.
                TVMediaSystemIconView(systemIdentifier: system.identifier, size: 30)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), Color.retroBlue.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 6)

                Text(system.name.uppercased())
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: Color.retroPink.opacity(0.2), radius: 4)

                Spacer()

                // Game count indicator
                Text(verbatim: "\(games.count) GAMES")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Horizontal scroll with games + View All card at the end
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    let gamesArray = Array(games.prefix(30))
                    ForEach(gamesArray.indices, id: \.self) { index in
                        let game = gamesArray[index]
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
            .tvMediaFocusSection()
        }
        .onAppear(perform: ensureLoaded)
        .task {
            // Trigger icon loading so TVMediaSystemIconView can display it.
            await SystemIconLoader.shared.loadIcons(for: [system])
        }
    }
}

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSaveStatesShelfRow: View {
    let title: String
    let items: [RetroSaveStateItem]
    @ObservedObject var store: RetroSaveStatesStore
    var onViewAll: (() -> Void)? = nil

    @FocusState private var focusedSaveID: String?
    @State private var thumbs: [String: UIImage] = [:]
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

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

                    if let onViewAll {
                        TVMediaSaveStatesViewAllCard(
                            count: items.count,
                            action: onViewAll
                        )
                    }
                }
                .padding(.vertical, 12)
            }
            // Use focusSection to ensure this shelf catches vertical focus navigation
            .tvMediaFocusSection()
        }
        .onChange(of: focusedSaveID) { newValue in
            guard let id = newValue else { return }
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            focusCoordinator.contentItemFocused(id: id, isAtLeftEdge: index == 0)
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
        .tvMediaFocusable()
        .tvOSDisableFocusEffect()
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
                store.removeFromCache(id: item.id, systemID: item.systemId)
            } catch {
                SceneCoordinator.shared.alertState.show(
                    title: "Delete Failed",
                    message: error.localizedDescription,
                    type: .error
                )
            }
        }
        _ = await store.reloadRecent(forSystemID: item.systemId, limit: 6)
    }
}

// MARK: - Search Results Grid

@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSearchResultsGrid: View {
    let results: [PVGame]
    @ObservedObject var gameActions: TVMediaGameActions

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.tvMediaFocusCoordinator) private var focusCoordinator

    @FocusState private var focusedGameID: String?
    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    @State private var gridWidth: CGFloat = 0

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)
    ]

    var body: some View {
        let spacing: CGFloat = 20
        let minItemWidth: CGFloat = 260
        let maxItemWidth: CGFloat = 300
        let effectiveWidth = gridWidth > 0 ? gridWidth : max(1, UIScreen.main.bounds.width - 120)
        let columnsPerRow = tvMediaAdaptiveColumnsPerRow(
            availableWidth: effectiveWidth,
            minItemWidth: minItemWidth,
            maxItemWidth: maxItemWidth,
            spacing: spacing
        )

        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(results.indices, id: \.self) { index in
                let game = results[index]
                let isAtLeftEdge = index % columnsPerRow == 0
                TVMediaGameTileView(
                    game: game,
                    titleFont: .callout.weight(.semibold),
                    onPlay: { sceneCoordinator.launchGame(game) },
                    contextMenu: { AnyView(GameContextMenu(game: game, rootDelegate: nil, contextMenuDelegate: gameActions)) },
                    isAtLeftEdge: isAtLeftEdge,
                    focusCoordinator: focusCoordinator,
                    focusedGameID: $focusedGameID
                )
            }
        }
        .padding(.top, 8)
        .tvMediaTrackWidth { gridWidth = $0 }
        .onChange(of: gridWidth) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
        .onChange(of: focusCoordinator.focusedContentID) { _ in
            syncFocusedEdgeState(columnsPerRow: columnsPerRow)
        }
        .onAppear {
            if focusedGameID == nil, let first = results.first {
                focusedGameID = first.id
            }
        }
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            switch event {
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: value > 0 ? 1 : -1, vertical: 0, columnsPerRow: columnsPerRow)
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveFocus(horizontal: 0, vertical: value < 0 ? 1 : -1, columnsPerRow: columnsPerRow)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                if let id = focusedGameID,
                   let game = results.first(where: { $0.id == id }) {
                    sceneCoordinator.launchGame(game)
                }
            case .buttonB(let isPressed):
                guard isPressed else { return }
                focusCoordinator.openSidebar()
            case .menuToggle(let isPressed):
                if isPressed {
                    focusCoordinator.toggleSidebar()
                }
            default:
                break
            }
        }
        #endif
    }

    private func syncFocusedEdgeState(columnsPerRow: Int) {
        guard let focusedID = focusCoordinator.focusedContentID else { return }
        guard let index = results.firstIndex(where: { $0.id == focusedID }) else { return }
        let isAtLeftEdge = (index % max(columnsPerRow, 1)) == 0
        focusCoordinator.contentItemFocused(id: focusedID, isAtLeftEdge: isAtLeftEdge)
    }

    #if os(iOS)
    private func moveFocus(horizontal: Int, vertical: Int, columnsPerRow: Int) {
        guard !results.isEmpty else { return }
        let ids = results.map(\.id)
        let currentID = focusedGameID ?? ids[0]
        guard let currentIndex = ids.firstIndex(of: currentID) else { return }
        let currentCol = currentIndex % columnsPerRow
        let currentRow = currentIndex / columnsPerRow
        var newRow = currentRow + vertical
        var newCol = currentCol + horizontal
        if horizontal < 0, currentCol == 0 {
            if currentRow == 0 {
                focusCoordinator.openSidebar()
                return
            }
            newRow = currentRow - 1
            newCol = columnsPerRow - 1
        }
        let newIndex = (newRow * columnsPerRow) + newCol
        guard newIndex >= 0, newIndex < ids.count else { return }
        focusedGameID = ids[newIndex]
    }
    #endif
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

/// SMPTE color bars for save states without thumbnails - optimized for performance
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaSaveStateSMPTE: View {
    private static let colors: [Color] = [
        Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 0.75, green: 0.75, blue: 0.0),
        Color(red: 0.0, green: 0.75, blue: 0.75),
        Color(red: 0.0, green: 0.75, blue: 0.0),
        Color(red: 0.75, green: 0.0, blue: 0.75),
        Color(red: 0.75, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.0, blue: 0.75)
    ]
    /// Precomputed stops avoid per-render allocation churn while scrolling.
    private static let gradientStops: [Gradient.Stop] = {
        Self.colors.enumerated().map { index, color in
            Gradient.Stop(
                color: color,
                location: CGFloat(index) / CGFloat(Self.colors.count - 1)
            )
        }
    }()

    var body: some View {
        LinearGradient(
            stops: Self.gradientStops,
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay(
            // Simplified scanline overlay using Canvas
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color.black.opacity(0.12)), lineWidth: 1)
                    y += 3.5
                }
            }
        )
    }
}

// MARK: - Save State Tile

@available(tvOS 16.0, iOS 17.0, *)
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
                // Thumbnail or placeholder - optimized rendering
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

                // Scanline overlay - optimized with Canvas for better performance
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(Color.black.opacity(0.06)), lineWidth: 1)
                        y += 3
                    }
                }
                .frame(width: tileWidth, height: tileHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false) // Don't interfere with touch events

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
            .compositingGroup()
        }
        .frame(width: tileWidth, height: tileHeight)
        .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 20, x: 0, y: 8)
        .shadow(color: isFocused ? Color.retroBlue.opacity(0.3) : .clear, radius: 30, x: 0, y: 12)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(Animation.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
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
@available(tvOS 16.0, iOS 17.0, *)
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
                    .tvMediaOnMoveCommand { _ in }
                    .onLongPressGesture(minimumDuration: 0.1) {
                        onTap()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity
                    ))
                    .animation(Animation.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.shouldShow)
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
                        Text("tv_media.status.importing", bundle: .module)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(Color.retroPink)
                    } else if viewModel.isSyncing {
                        Text("tv_media.status.syncing", bundle: .module)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(Color.retroBlue)
                    } else {
                        Text("tv_media.status.processing", bundle: .module)
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
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
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

// MARK: - ROM Instructions View

/// RetroWave-themed view showing how to add ROMs via various methods
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaROMInstructionsView: View {
    let onDismiss: () -> Void

    #if canImport(PVWebServer)
    @State private var webServerURL: String?
    #endif

    #if os(tvOS)
    @FocusState private var focusedCard: String?
    #endif

    private let wikiURL = "https://wiki.provenance-emu.com/"

    /// Platform-adaptive sizing for 10-foot vs handheld UI
    private var titleFontSize: CGFloat {
        #if os(tvOS)
        return 38
        #else
        return 24
        #endif
    }

    private var subtitleFontSize: CGFloat {
        #if os(tvOS)
        return 24
        #else
        return 16
        #endif
    }

    private var cardTitleFontSize: CGFloat {
        #if os(tvOS)
        return 28
        #else
        return 18
        #endif
    }

    private var cardSubtitleFontSize: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return 13
        #endif
    }

    private var cardDescriptionFontSize: CGFloat {
        #if os(tvOS)
        return 22
        #else
        return 15
        #endif
    }

    private var cardIconSize: CGFloat {
        #if os(tvOS)
        return 36
        #else
        return 24
        #endif
    }

    private var cardPadding: CGFloat {
        #if os(tvOS)
        return 30
        #else
        return 20
        #endif
    }

    private var sectionSpacing: CGFloat {
        #if os(tvOS)
        return 36
        #else
        return 28
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(tvOS)
        return 80
        #else
        return 40
        #endif
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.08)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: sectionSpacing) {
                    headerSection
                    webServerSection
                    #if os(iOS)
                    filesAppSection
                    #endif
                    airdropSection
                    cloudKitSection
                    wikiSection
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 30)
            }
        }
        #if os(tvOS)
        .onExitCommand { onDismiss() }
        #else
        .navigationTitle("HOW TO ADD ROMS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { onDismiss() }
            }
        }
        #endif
        #if canImport(PVWebServer)
        .onAppear { refreshWebServerURL() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebServerStatusChanged"))) { _ in
            refreshWebServerURL()
        }
        #endif
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: titleFontSize * 1.5))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroPink, .retroBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .retroPink.opacity(0.6), radius: 12)

            Text("tv_media.roms.adding", bundle: .module)
                .font(.system(size: titleFontSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .retroBlue.opacity(0.6), radius: 8)

            Text("tv_media.roms.several_ways", bundle: .module)
                .font(.system(size: subtitleFontSize))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private var webServerSection: some View {
        instructionCard(
            id: "webserver",
            icon: "network",
            title: "WEB SERVER",
            subtitle: "Recommended",
            description: "Upload ROMs from any device on your local network using the built-in web server.",
            accentColor: .retroPink
        ) {
            #if canImport(PVWebServer)
            if let url = webServerURL {
                Text(url)
                    .font(.system(size: cardDescriptionFontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.retroBlue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.retroBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
            } else {
                Text("tv_media.roms.start_web_server", bundle: .module)
                    .font(.system(size: cardSubtitleFontSize))
                    .foregroundStyle(.white.opacity(0.5))
                    .italic()
            }
            #endif
        }
    }

    #if os(iOS)
    private var filesAppSection: some View {
        instructionCard(
            id: "files",
            icon: "folder",
            title: "FILES APP",
            subtitle: "iOS",
            description: "Use the iOS Files app or iTunes File Sharing to copy ROMs directly into Provenance's documents folder.",
            accentColor: .retroBlue
        )
    }
    #endif

    private var airdropSection: some View {
        instructionCard(
            id: "airdrop",
            icon: "airplayaudio",
            title: "AIRDROP",
            subtitle: platformAirdropSubtitle,
            description: platformAirdropDescription,
            accentColor: .retroPurple
        )
    }

    private var cloudKitSection: some View {
        instructionCard(
            id: "icloud",
            icon: "icloud.and.arrow.down",
            title: "ICLOUD SYNC",
            subtitle: "All Devices",
            description: platformCloudKitDescription,
            accentColor: .cyan
        )
    }

    private var platformCloudKitDescription: String {
        #if os(tvOS)
        return "Add ROMs on one device and they automatically sync to all your Apple devices signed into the same iCloud account. iCloud sync is included free on Apple TV. On iOS, Provenance Plus is required."
        #else
        return "Add ROMs on one device and they automatically sync to all your Apple devices signed into the same iCloud account. Requires Provenance Plus on iOS. Included free on Apple TV."
        #endif
    }

    private var wikiSection: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.retroPink.opacity(0.3), .retroBlue.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(spacing: 16) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: cardIconSize))
                    .foregroundStyle(Color.retroBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("tv_media.roms.full_documentation", bundle: .module)
                        .font(.system(size: cardTitleFontSize, weight: .bold))
                        .foregroundStyle(.white)

                    Text(wikiURL)
                        .font(.system(size: cardSubtitleFontSize, design: .monospaced))
                        .foregroundStyle(Color.retroBlue.opacity(0.8))
                }

                Spacer()
            }
            .padding(.vertical, 12)
            #if os(tvOS)
            .focusable(true)
            #endif
        }
    }

    // MARK: - Helpers

    private var platformAirdropSubtitle: String {
        #if os(tvOS)
        if #available(tvOS 17.0, *) {
            return "tvOS 17+"
        }
        return "Not Available"
        #else
        return "iOS"
        #endif
    }

    private var platformAirdropDescription: String {
        #if os(tvOS)
        if #available(tvOS 17.0, *) {
            return "AirDrop ROM files from a nearby iPhone, iPad, or Mac directly to your Apple TV. Requires tvOS 17 or later."
        }
        return "AirDrop is not available on this version of tvOS. Use the web server or iCloud sync instead."
        #else
        return "AirDrop ROM files from a nearby Mac or iOS device. Provenance will automatically import them."
        #endif
    }

    /// Instruction card with tvOS focus support for scrolling
    @ViewBuilder
    private func instructionCard<Content: View>(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        description: String,
        accentColor: Color,
        @ViewBuilder extras: () -> Content = { EmptyView() }
    ) -> some View {
        #if os(tvOS)
        let isFocused = focusedCard == id
        #else
        let isFocused = false
        #endif

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: cardIconSize))
                    .foregroundStyle(accentColor)
                    .shadow(color: accentColor.opacity(0.5), radius: 6)
                    .frame(width: cardIconSize + 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: cardTitleFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(0.4), radius: 4)

                    Text(subtitle)
                        .font(.system(size: cardSubtitleFontSize, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.8))
                }

                Spacer()
            }

            Text(description)
                .font(.system(size: cardDescriptionFontSize))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(4)

            extras()
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(isFocused ? 0.7 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [accentColor.opacity(isFocused ? 0.8 : 0.4), accentColor.opacity(isFocused ? 0.4 : 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .shadow(color: isFocused ? accentColor.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        #if os(tvOS)
        .focusable(true)
        .focused($focusedCard, equals: id)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        #endif
    }

    #if canImport(PVWebServer)
    private func refreshWebServerURL() {
        Task { @MainActor in
            guard await PVWebServerManager.shared.isRunning else {
                webServerURL = nil
                return
            }
            webServerURL = await PVWebServerManager.shared.serverURL?.absoluteString
        }
    }
    #endif
}

// MARK: - Import Status Sheet (Full Screen)

/// Full import queue management sheet with tvOS styling
@available(tvOS 16.0, iOS 17.0, *)
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
                    .tvMediaFocusSection()
                }
            }
        }
        .tvMediaFocusScope(sheetNamespace)
        .tvMediaOnExitCommand {
            onDismiss()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("tv_media.import_queue.title", bundle: .module)
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
                    Text("tv_media.import_queue.files_in_queue \(viewModel.importQueueItems.count)", bundle: .module)
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
                    Text("tv_media.import_queue.close", bundle: .module)
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
            .tvOSDisableFocusEffect()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.retroBlue.opacity(0.6))
                .shadow(color: Color.retroBlue.opacity(0.4), radius: 12)

            Text("tv_media.import_queue.no_pending", bundle: .module)
                .font(.system(size: 22, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(.white)

            Text("tv_media.import_queue.all_processed", bundle: .module)
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
                    Text("tv_media.icloud_sync.title", bundle: .module)
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
                        Text(verbatim: "→ \(system.rawValue)")
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
                // Use a solid fill background to prevent iOS/tvOS 26 liquid glass from
                // clashing with the border. The strokeBorder is drawn as an overlay on
                // top so it remains visible regardless of any system glass treatment.
                .background(Color.retroBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.retroBlue.opacity(0.6), lineWidth: 1.5)
                )
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
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
            .tvOSDisableFocusEffect()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.06 : 0.03))
        )
        // Draw the border as an overlay so it renders above any iOS/tvOS 26 liquid glass
        // that may be applied to the background material. Only show the border when focused
        // to avoid double-border artifacts caused by glass interacting with a permanent stroke.
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
                            colors: [Color.clear, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: isFocused ? 2 : 0
                )
        )
        .focusable()
        .focused($focusedItemID, equals: item.id.uuidString)
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
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
