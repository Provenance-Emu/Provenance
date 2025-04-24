//
//  ConsoleGamesView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVRealm
import PVSettings
import Combine
import RealmSwift

struct ConsoleGamesFilterModeFlags: OptionSet {
    let rawValue: Int

    static let played = ConsoleGamesFilterModeFlags(rawValue: 1 << 0)
    static let neverPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 1)
    static let recentlyImported = ConsoleGamesFilterModeFlags(rawValue: 1 << 2)
    static let recentlyPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 3)
}

struct ConsoleGamesView: SwiftUI.View {

    @StateObject internal var gamesViewModel: ConsoleGamesViewModel
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedRealmObject var console: PVSystem
    weak var rootDelegate: PVRootDelegate?
    var showGameInfo: (String) -> Void

    let gamesForSystemPredicate: NSPredicate

    @ObservedObject private var themeManager = ThemeManager.shared

    @State internal var gameLibraryItemsPerRow: Int = 4
    @Default(.gameLibraryScale) internal var gameLibraryScale

    /// GameContextMenuDelegate
    @State internal var showImagePicker = false
    @State internal var selectedImage: UIImage?
    @State internal var gameToUpdateCover: PVGame?
    @State internal var showingRenameAlert = false
    @State internal var gameToRename: PVGame?
    @State internal var newGameTitle = ""
    @FocusState internal var renameTitleFieldIsFocused: Bool
    @State internal var systemMoveState: SystemMoveState?
    @State internal var continuesManagementState: ContinuesManagementState?
    
    @Default(.showRecentSaveStates) internal var showRecentSaveStates
    @Default(.showFavorites) internal var showFavorites
    @Default(.showRecentGames) internal var showRecentGames
    @Default(.showSearchbar) internal var showSearchbar

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var gamepadHandler: Any?
    @State private var lastFocusedSection: HomeSectionType?

    @State private var gamepadCancellable: AnyCancellable?

    @State private var navigationTimer: Timer?
    @State private var initialDelay: TimeInterval = 0.5
    @State private var repeatDelay: TimeInterval = 0.15

    /// Note: these CANNOT be in a @StateObject
    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "systemIdentifier == %@"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games

    @ObservedResults(
        PVSaveState.self,
        filter: NSPredicate(format: "game.systemIdentifier == %@"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates

    @ObservedResults(
        PVRecentGame.self,
        filter: NSPredicate(format: "game.systemIdentifier == %@")
    ) var recentlyPlayedGames

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "isFavorite == true AND systemIdentifier == %@")
    ) var favorites

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "systemIdentifier == %@ AND playCount > 0"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed

    @State var isShowingSaveStates = false
    @State internal var showArtworkSearch = false

    @State internal var showArtworkSourceAlert = false

    @State private var searchText = ""

    @State private var isSearching = false

    @State private var scrollOffset: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var isSearchBarVisible: Bool = true

    private var sectionHeight: CGFloat {
        // Use compact size class to determine if we're in portrait on iPhone
        let baseHeight: CGFloat = horizontalSizeClass == .compact ? 150 : 75
        return verticalSizeClass == .compact ? baseHeight / 2 : baseHeight
    }

    init(
        console: PVSystem,
        viewModel: PVRootViewModel,
        rootDelegate: PVRootDelegate? = nil,
        showGameInfo: @escaping (String) -> Void
    ) {
        _gamesViewModel = StateObject(wrappedValue: ConsoleGamesViewModel(console: console))
        self.console = console
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
        self.showGameInfo = showGameInfo
        self.gamesForSystemPredicate = NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])

        _games = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: viewModel.sortGamesAscending)
        )
        _recentSaveStates = ObservedResults(
            PVSaveState.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: viewModel.sortGamesAscending)
        )
        _recentlyPlayedGames = ObservedResults(
            PVRecentGame.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier)
        )
        _favorites = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "isFavorite == true AND systemIdentifier == %@", console.identifier)
        )
        _mostPlayed = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "systemIdentifier == %@ AND playCount > 0", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: viewModel.sortGamesAscending)
        )
    }

    var body: some SwiftUI.View {
        GeometryReader { geometry in
            ZStack {
                // RetroWave background
                RetroTheme.retroBackground
                
                // Grid overlay
                RetroGrid(lineColor: themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    .opacity(0.2)
                
                VStack(spacing: 0) {
                    displayOptionsView()
                        .allowsHitTesting(true)
                
                // Status Message View
                StatusMessageView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // Import Progress View (legacy - can be removed once StatusMessageView is fully tested)
                ImportProgressView(
                    gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                    updatesController: AppState.shared.libraryUpdatesController!,
                    onTap: {
                        withAnimation {
                            gamesViewModel.showImportStatusView = true
                        }
                    }
                )
                .padding(.horizontal, 8)
                .padding(.top, 4)

                ScrollViewWithOffset(
                    offsetChanged: { offset in
                        // Detect scroll direction and distance
                        let scrollingDown = offset < previousScrollOffset
                        let scrollDistance = abs(offset - previousScrollOffset)

                        // Only respond to significant scroll movements
                        if scrollDistance > 5 {
                            // Hide search bar when scrolling down, show when scrolling up
                            if scrollingDown && offset < -10 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSearchBarVisible = false
                                }
                            } else if !scrollingDown {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSearchBarVisible = true
                                }
                            }
                        }

                        scrollOffset = offset
                        previousScrollOffset = offset
                    }
                ) {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 0) {
                            // Add search bar with visibility control
                            if games.count > 8 && showSearchbar {
                                PVSearchBar(text: $searchText)
                                    .opacity(isSearchBarVisible ? 1 : 0)
                                    .frame(height: isSearchBarVisible ? nil : 0)
                                    .animation(.easeInOut(duration: 0.3), value: isSearchBarVisible)
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                            }
                            
                            continueSection()
                                .id("section_continues")
                                .padding(.horizontal, 10)
                            favoritesSection()
                                .id("section_favorites")
                                .padding(.horizontal, 10)
                            recentlyPlayedSection()
                                .id("section_recent")
                                .padding(.horizontal, 10)
                            gamesSection()
                                .id("section_allgames")
                                .padding(.horizontal, 10)
                        }
                        /// Add padding at bottom to account for BiosesView if needed
                        .padding(.bottom, !console.bioses.isEmpty ? 120 : 44)
                        .onChange(of: gamesViewModel.focusedSection) { newSection in
                            if let section = newSection {
                                withAnimation {
                                    let sectionId = sectionToId(section)
                                    proxy.scrollTo(sectionId, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .overlay(
                    Group {
                        if !searchText.isEmpty {
                            VStack {
                                searchResultsView()
                            }
                            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                        }
                    }
                )
                .padding(.bottom, 4)

                /// Position BiosesView above the tab bar
                if !console.bioses.isEmpty {
                    BiosesView(console: console)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 66) // Account for tab bar height
                } else {
                    // Empty paddview view
                    HStack {
                        Text("")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 44) // Account for tab bar height
                }
            }
            .sheet(isPresented: $showImagePicker) {
#if !os(tvOS)
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let game = gameToUpdateCover {
                        saveArtwork(image: image, forGame: game)
                    }
                    showImagePicker = false
                    gameToUpdateCover = nil
                }
#endif
            }
            }
            .sheet(isPresented: $showArtworkSearch) {
                ArtworkSearchView(
                    initialSearch: gameToUpdateCover?.title ?? "",
                    initialSystem: console.enumValue
                ) { selection in
                    if let game = gameToUpdateCover {
                        Task {
                            do {
                                // Load image data from URL
                                let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                                if let uiImage = UIImage(data: data) {
                                    await MainActor.run {
                                        saveArtwork(image: uiImage, forGame: game)
                                        showArtworkSearch = false
                                        gameToUpdateCover = nil
                                    }
                                }
                            } catch {
                                DLOG("Failed to load artwork image: \(error)")
                            }
                        }
                    }
                }
            }
            .uiKitAlert(
                "Rename Game",
                message: "Enter a new name for \(gameToRename?.title ?? "")",
                isPresented: $showingRenameAlert,
                textValue: newGameTitleBinding,
                preferredContentSize: CGSize(width: 300, height: 200),
                textField: { textField in
                    textField.placeholder = "Game name"
                    textField.clearButtonMode = .whileEditing
                    textField.autocapitalizationType = .words
                }
            ) {
                [
                    UIAlertAction(title: "Save", style: .default) { _ in
                        if let game = gameToRename, !newGameTitle.isEmpty {
                            Task {
                                await renameGame(game, to: newGameTitle)
                                gameToRename = nil
                                newGameTitle = ""
                                showingRenameAlert = false
                            }
                        }
                    },
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        gameToRename = nil
                        newGameTitle = ""
                        showingRenameAlert = false
                    }
                ]
            }
            .sheet(item: $systemMoveState) { state in
                SystemPickerView(
                    game: state.game,
                    isPresented: Binding(
                        get: { state.isPresenting },
                        set: { newValue in
                            if !newValue {
                                systemMoveState = nil
                            }
                        }
                    )
                )
            }
            // Import Status View
            .fullScreenCover(isPresented: Binding<Bool>(
                get: { gamesViewModel.showImportStatusView },
                set: { gamesViewModel.showImportStatusView = $0 }
            )) {
                ImportStatusView(
                    updatesController: AppState.shared.libraryUpdatesController!,
                    gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                    dismissAction: {
                        withAnimation {
                            gamesViewModel.showImportStatusView = false
                        }
                    }
                )
            }
            .sheet(item: $continuesManagementState) { state in
                let game = state.game.warmUp()
                let realm = game.realm?.thaw() ?? RomDatabase.sharedInstance.realm.thaw()
                /// Create the Realm driver
                if let driver = try? RealmSaveStateDriver(realm: realm) {

                    /// Create view model
                    let viewModel = ContinuesMagementViewModel(
                        driver: driver,
                        gameTitle: game.title,
                        systemTitle: game.system?.name ?? "",
                        numberOfSaves: game.saveStates.count,
                        onLoadSave: { saveID in
                            continuesManagementState = nil
                            Task.detached {
                                Task { @MainActor in
                                    await rootDelegate?.root_openSaveState(saveID)
                                }
                            }
                        })

                    /// Create and configure the view
                    if #available(iOS 16.4, tvOS 16.4, *) {
                        ContinuesManagementView(viewModel: viewModel)
                            .onAppear {
                                /// Set the game ID filter
                                driver.gameId = game.id

                                let game = game.freeze()
                                Task { @MainActor in
                                    let image: UIImage? = await game.fetchArtworkFromCache()
                                    viewModel.gameUIImage = image
                                }
                            }
                            .presentationBackground(content: {Color.clear})
                    } else {
                        ContinuesManagementView(viewModel: viewModel)
                            .onAppear {
                                /// Set the game ID filter
                                driver.gameId = game.id

                                let game = game.freeze()
                                Task { @MainActor in
                                    let image: UIImage? = await game.fetchArtworkFromCache()
                                    viewModel.gameUIImage = image
                                }
                            }
                    }
                } else {
                    Text("Error: Could not load save states")
                }
            }
            .uiKitAlert(
                "Select Disc",
                message: "Choose which disc to load",
                isPresented: Binding(
                    get: { gamesViewModel.discSelectionAlert != nil },
                    set: { if !$0 { gamesViewModel.discSelectionAlert = nil } }
                ),
                preferredContentSize: CGSize(width: 500, height: 300),
                buttons: {
                    if let alert = gamesViewModel.discSelectionAlert, let game = alert.game  {
                        let actions = alert.discs.map { (disc: DiscSelectionAlert.Disc) -> UIAlertAction in
                            UIAlertAction(title: disc.fileName, style: .default) { _ in
                                gamesViewModel.discSelectionAlert = nil
                                Task {
                                    await rootDelegate?.root_loadPath(disc.path, forGame: game, sender: nil, core: nil, saveState: nil)
                                }
                            }
                        }

                        actions + [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                            gamesViewModel.discSelectionAlert = nil
                        }]
                    } else {
                        [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                            gamesViewModel.discSelectionAlert = nil
                        }]
                    }
                }
            )
            .uiKitAlert(
                "Choose Artwork Source",
                message: "Select artwork from your photo library or search online sources",
                isPresented: $showArtworkSourceAlert,
                buttons: {
                    UIAlertAction(title: "Select from Photos", style: .default) { _ in
                        showArtworkSourceAlert = false
                        showImagePicker = true
                    }
                    UIAlertAction(title: "Search Online", style: .default) { [game = gameToUpdateCover] _ in
                        showArtworkSourceAlert = false
                        gameToUpdateCover = game  // Preserve the game reference
                        showArtworkSearch = true
                    }
                    UIAlertAction(title:  NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                        showArtworkSourceAlert = false
                    }
                }
            )
            .task {
                // Rescan specific system directory
                let systemPath = Paths.biosesPath.appendingPathComponent(console.identifier)
                await BIOSWatcher.shared.rescanDirectory(systemPath)
            }
        }
        .modifier(ConditionalSearchModifier(
            isEnabled: games.count > 8,
            searchText: $searchText
        ))
        .ignoresSafeArea(.all)
    }
    
    private var hasRecentSaveStates: Bool {
        !recentSaveStates.filter("game.systemIdentifier == %@", console.identifier).isEmpty
    }

    private var hasFavorites: Bool {
        !favorites.filter("systemIdentifier == %@", console.identifier).isEmpty
    }

    private var hasRecentlyPlayedGames: Bool {
        !recentlyPlayedGames.isEmpty
    }

    private func loadGame(_ game: PVGame) {
        Task.detached { @MainActor in
            await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
        }
    }

    var itemsPerRow: Int {
        let roundedScale = Int(gameLibraryScale.rounded())
        // If games is less than count, just use the games to fill the row.
        // also don't go below 0
        let count: Int
        if AppState.shared.isSimulator {
            count = max(0,roundedScale )
        } else {
            // TODO: Fill space on iOS or certain layouts only, or a max width?
            let fillSpace = false
            if fillSpace {
                count = min(max(1, roundedScale), games.count)
            } else {
                count = max(1, roundedScale)
            }
        }
        return count
    }

    @ViewBuilder
    private func showGamesGrid(_ games: [PVGame]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: itemsPerRow)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games.filter{!$0.isInvalidated}, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    sectionContext: .allGames,
                    isFocused: Binding(
                        get: { !game.isInvalidated &&
                            gamesViewModel.focusedSection == .allGames &&
                            gamesViewModel.focusedItemInSection == game.id },
                        set: { if $0 && !game.isInvalidated { gamesViewModel.focusedItemInSection = game.id} }
                    )
                ) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                }
                .id(game.id)
                .focusableIfAvailable()
            }
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: itemsPerRow)
        return ScrollViewReader { proxy in
            LazyVGrid(columns: columns, spacing: 10) {
                // Custom styling for grid items
                ForEach(games.filter{!$0.isInvalidated}, id: \.self) { game in
                    GameItemView(
                        game: game,
                        constrainHeight: false,
                        viewType: .cell,
                        sectionContext: .allGames,
                        isFocused: Binding(
                            get: {
                                !game.isInvalidated &&
                                gamesViewModel.focusedSection == .allGames &&
                                gamesViewModel.focusedItemInSection == game.id
                            },
                            set: {
                                if $0 && !game.isInvalidated {
                                    gamesViewModel.focusedSection = .allGames
                                    gamesViewModel.focusedItemInSection = game.id
                                }
                            }
                        )
                    ) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                    }
                    .id(game.id)
                    .focusableIfAvailable()
                    .contextMenu {
                        GameContextMenu(
                            game: game,
                            rootDelegate: rootDelegate,
                            contextMenuDelegate: self
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func showGamesList(_ games: [PVGame]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(games.filter{!$0.isInvalidated}, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: true,
                    viewType: .row,
                    sectionContext: .allGames,
                    isFocused: Binding(
                        get: {
                            !game.isInvalidated &&
                            gamesViewModel.focusedSection == .allGames &&
                            gamesViewModel.focusedItemInSection == game.id
                        },
                        set: { if $0 && !game.isInvalidated { gamesViewModel.focusedItemInSection = game.id} }
                    )
                ) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                }
                .id(game.id)
                .focusableIfAvailable()
                GamesDividerView()
            }
        }
    }

    @ViewBuilder
    private func showGamesList(_ games: Results<PVGame>) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    viewType: .row,
                    sectionContext: .allGames,
                    isFocused: Binding(
                        get: {
                            !game.isInvalidated &&
                            gamesViewModel.focusedSection == .allGames &&
                            gamesViewModel.focusedItemInSection == game.id },
                        set: { if $0 && !game.isInvalidated { gamesViewModel.focusedItemInSection = game.id} }
                    ))
                {
                    loadGame(game)
                }
                .focusableIfAvailable()
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
            }
        }
    }

    private func adjustZoomLevel(for magnification: Float) {
        gameLibraryItemsPerRow = calculatedZoomLevel(for: magnification)
    }

    private func calculatedZoomLevel(for magnification: Float) -> Int {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let defaultZoomLevel = isIPad ? 8 : 4

        // Handle invalid magnification values
        guard !magnification.isNaN && !magnification.isInfinite else {
            return defaultZoomLevel
        }

        // Calculate the target zoom level based on magnification
        let targetZoomLevel = Float(defaultZoomLevel) / magnification

        // Round to the nearest even number
        let roundedZoomLevel = round(targetZoomLevel / 2) * 2

        // Clamp the value between 2 and 16
        let clampedZoomLevel = max(2, min(16, roundedZoomLevel))

        return Int(clampedZoomLevel)
    }

#if !os(tvOS)
    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                adjustZoomLevel(for: Float(value))
            }
            .onEnded { _ in
                // TODO: What to do here?
            }
    }
#endif


    private func setupGamepadHandling() {
        // Cancel existing handler if it exists
        gamepadCancellable?.cancel()

        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                // Only handle events if this console view is currently selected
                guard !viewModel.isMenuVisible,
                      viewModel.selectedConsole?.identifier == console.identifier
                else { return }

                DLOG("Gamepad event: \(event)")
                // DLOG("Selected console: \(String(describing: viewModel.selectedConsole))")
                DLOG("Current console: \(console.identifier)")

                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        handleButtonPress()
                    }
                case .verticalNavigation(let value, let isPressed):
                    if isPressed {
                        handleVerticalNavigation(value)
                    }
                case .horizontalNavigation(let value, let isPressed):
                    if isPressed {
                        handleHorizontalNavigation(value)
                    }
                default:
                    break
                }
            }
    }

    private func showOptionsMenu(for gameId: String) {
        let realm = try! Realm()
        // Implement context menu showing logic here
        // This would show the same menu as the long-press context menu
        if let game = realm.objects(PVGame.self).filter("id == %@", gameId).first {
            GameContextMenu(
                game: game,
                rootDelegate: rootDelegate,
                contextMenuDelegate: self
            )
        }
    }

    @ViewBuilder
    private func makeGameMoreInfoView(for game: PVGame) -> some View {
        do {
            let driver = try RealmGameLibraryDriver()
            let viewModel = PagedGameMoreInfoViewModel(
                driver: driver,
                initialGameId: game.md5Hash,
                playGameCallback: { [weak rootDelegate] md5 in
                    await rootDelegate?.root_loadGame(byMD5Hash: md5)
                }
            )
            return AnyView(PagedGameMoreInfoView(viewModel: viewModel))
        } catch {
            return AnyView(Text("Failed to initialize game info view: \(error.localizedDescription)"))
        }
    }

    private func renameGame(_ game: PVGame, to newName: String) async {
        guard !newName.isEmpty else { return }

        // Get a reference to the Realm
        let realm = try? await Realm()

        // Update the game title
        try? realm?.write {
            game.thaw()?.title = newName
        }

        // Reset state
        gameToRename = nil
        newGameTitle = ""
        showingRenameAlert = false
    }

    // Create a computed binding that wraps the String as String?
    private var newGameTitleBinding: Binding<String?> {
        Binding<String?>(
            get: { self.newGameTitle },
            set: { self.newGameTitle = $0 ?? "" }
        )
    }

    /// Function to filter games based on search text
    private func filteredSearchResults() -> [PVGame] {
        guard !searchText.isEmpty else { return [] }

        let searchTextLowercased = searchText.lowercased()
        /// Only search games for this console
        return Array(games.filter { game in
            game.title.lowercased().contains(searchTextLowercased)
        })
    }

    @ViewBuilder
    private func searchResultsView() -> some View {
        VStack(alignment: .leading) {
            Text("Search Results")
                .font(.title2)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                let results = filteredSearchResults()
                if results.isEmpty {
                    Text("NO GAMES FOUND")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
                        .padding()
                } else {
                    ForEach(results, id: \.self) { game in
                        GameItemView(
                            game: game,
                            constrainHeight: true,
                            viewType: .row,
                            sectionContext: .allGames,
                            isFocused: Binding(
                                get: {
                                    !game.isInvalidated &&
                                    gamesViewModel.focusedSection == .allGames &&
                                    gamesViewModel.focusedItemInSection == game.id
                                },
                                set: {
                                    if $0 && !game.isInvalidated {
                                        gamesViewModel.focusedSection = .allGames
                                        gamesViewModel.focusedItemInSection = game.id
                                    }
                                }
                            )
                        ) {
                            Task.detached { @MainActor in
                                await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                            }
                        }
                        .id(game.id)
                        .focusableIfAvailable()
                        .contextMenu {
                            GameContextMenu(
                                game: game,
                                rootDelegate: rootDelegate,
                                contextMenuDelegate: self
                            )
                        }
                        GamesDividerView()
                    }
                }
            }
        }
    }
}

// MARK: - View Components
extension ConsoleGamesView {

    @ViewBuilder
    private func displayOptionsView() -> some View {
        GamesDisplayOptionsView(
            sortAscending: viewModel.sortGamesAscending,
            isGrid: viewModel.viewGamesAsGrid,
            toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
            toggleSortAction: { viewModel.sortGamesAscending.toggle() },
            toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() }
        )
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPurple, RetroTheme.retroPink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: RetroTheme.retroPurple.opacity(0.4), radius: 3, x: 0, y: 0)
        .padding(.horizontal, 8)
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func continueSection() -> some View {
        Group {
            if showRecentSaveStates && !recentSaveStates.isEmpty {
                HomeContinueSection(
                    rootDelegate: rootDelegate,
                    consoleIdentifier: console.identifier,
                    parentFocusedSection: Binding(
                        get: { gamesViewModel.focusedSection },
                        set: { gamesViewModel.focusedSection = $0 }
                    ),
                    parentFocusedItem: Binding(
                        get: { gamesViewModel.focusedItemInSection },
                        set: { gamesViewModel.focusedItemInSection = $0 }
                    )
                )
                //.padding(.horizontal, 8)
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func favoritesSection() -> some View {
        Group {
            if showFavorites && !favorites.isEmpty {
                HomeSection(title: "Favorites") {
                    ForEach(favorites, id: \.self) { game in
                        gameItem(game, section: .favorites)
                    }
                }
                .frame(height: sectionHeight)
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func recentlyPlayedSection() -> some View {
        Group {
            if showRecentGames && !recentlyPlayedGames.isEmpty {
                HomeSection(title: "Recently Played") {
                    ForEach(recentlyPlayedGames, id: \.self) { recentGame in
                        if let game = recentGame.game {
                            gameItem(game, section: .recentlyPlayedGames)
                        }
                    }
                }
                .frame(height: sectionHeight)
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func gamesSection() -> some View {
        Group {
            if games.filter{!$0.isInvalidated}.isEmpty && AppState.shared.isSimulator {
                let fakeGames = PVGame.mockGenerate(systemID: console.identifier)
                if viewModel.viewGamesAsGrid {
                    showGamesGrid(fakeGames)
                } else {
                    showGamesList(fakeGames)
                }
            } else {
                VStack(alignment: .leading) {
                    
                    titleBar()
                    
                    if viewModel.viewGamesAsGrid {
                        showGamesGrid(games)
                    } else {
                        showGamesList(games)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func titleBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(console.name)
                    .font(.headline)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .shadow(color: .retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
                HStack {
                    Text(console.manufacturer)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    
                    if console.releaseYear > 1970 {
                        Text("\(console.releaseYear)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                            .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    }
                }
            }
            
            Spacer()
            
            Text("\(console.games.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.retroPurple.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.retroBlue, lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.retroBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
        )
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func gameItem(_ game: PVGame, section: HomeSectionType) -> some View {
        if !game.isInvalidated {

            GameItemView(
                game: game,
                constrainHeight: true,
                viewType: .cell,
                sectionContext: section,
                isFocused: Binding(
                    get: {
                        !game.isInvalidated &&
                        gamesViewModel.focusedSection == section &&
                        gamesViewModel.focusedItemInSection == game.id
                    },
                    set: {
                        if $0 && !game.isInvalidated {
                            gamesViewModel.focusedSection = section
                            gamesViewModel.focusedItemInSection = game.id
                        }
                    }
                )
            ) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
            .id(game.id)
            .focusableIfAvailable()
            .contextMenu {
                GameContextMenu(
                    game: game,
                    rootDelegate: rootDelegate,
                    contextMenuDelegate: self
                )
            }
        }
    }

    @ViewBuilder
    private func saveStateItem(_ saveState: PVSaveState) -> some View {
        if !saveState.isInvalidated && !saveState.game.isInvalidated {
            GameItemView(
                game: saveState.game,
                constrainHeight: true,
                viewType: .cell,
                sectionContext: .recentSaveStates,
                isFocused: Binding(
                    get: {
                        !saveState.isInvalidated &&
                        gamesViewModel.focusedSection == .recentSaveStates &&
                        gamesViewModel.focusedItemInSection == saveState.id
                    },
                    set: {
                        if $0 && !saveState.isInvalidated {
                            gamesViewModel.focusedSection = .recentSaveStates
                            gamesViewModel.focusedItemInSection = saveState.id
                        }
                    }
                )
            ) {
                Task.detached { @MainActor in
                    guard !saveState.isInvalidated, !saveState.game.isInvalidated else { return }
                    await rootDelegate?.root_load(saveState.game, sender: self, core: saveState.core, saveState: saveState)
                }
            }
            .id(saveState.id)
            .focusableIfAvailable()
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView_Previews: PreviewProvider {
    static let console: PVSystem = ._rlmDefaultValue()
    static let viewModel: PVRootViewModel = .init()

    static var previews: some SwiftUI.View {
        ConsoleGamesView(console: console,
                         viewModel: viewModel,
                         rootDelegate: nil,
                         showGameInfo: {_ in})
    }
}

private struct ConditionalSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var searchText: String

    func body(content: Content) -> some View {
        if isEnabled {
            #if !os(tvOS)
            content
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search games")
            #else
            content
                .searchable(text: $searchText, placement: .automatic, prompt: "Search games")
            #endif
        } else {
            content
                .searchable(text: .constant(""), prompt: "")
        }
    }
}
#endif
