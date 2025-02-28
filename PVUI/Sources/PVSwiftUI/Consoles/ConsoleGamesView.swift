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
            VStack(spacing: 0) {
                displayOptionsView()
                    .allowsHitTesting(true)
                    .contentShape(Rectangle())
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 20) {
                            continueSection()
                                .id("section_continues")
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
                .padding(.bottom, 4)
                
                /// Position BiosesView above the tab bar
                if !console.bioses.isEmpty {
                    BiosesView(console: console)
                        .padding(.horizontal, 0)
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
            .alert("Rename Game", isPresented: $showingRenameAlert) {
                renameAlertView()
            } message: {
                Text("Enter a new name for \(gameToRename?.title ?? "")")
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
                        ContinuesMagementView(viewModel: viewModel)
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
                        ContinuesMagementView(viewModel: viewModel)
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
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in
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
        .ignoresSafeArea(.all)
    }
    
    // MARK: - Helper Methods
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
    
    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: itemsPerRow)
        return ScrollViewReader { proxy in
            LazyVGrid(columns: columns, spacing: 10) {
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
        // Implement context menu showing logic here
        // This would show the same menu as the long-press context menu
        if let game = RomDatabase.sharedInstance.realm.objects(PVGame.self).filter("id == %@", gameId).first {
            GameContextMenu(
                game: game,
                rootDelegate: rootDelegate,
                contextMenuDelegate: self
            )
        }
    }
    
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
        .padding(.top, 16)
        .padding(.bottom, 16)
        .allowsHitTesting(true)
        .contentShape(Rectangle())
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
                    Text("\(console.name) Games")
                        .font(.title2)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    
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
#endif
