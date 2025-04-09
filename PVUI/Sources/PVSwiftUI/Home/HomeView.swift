//
//  HomeView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import Combine
import PVUIBase

@available(iOS 14, tvOS 14, *)
struct HomeView: SwiftUI.View {

    //    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!

    weak var rootDelegate: PVRootDelegate?
    @ObservedObject var viewModel: PVRootViewModel
    var showGameInfo: (String) -> Void

    @Default(.showRecentSaveStates) private var showRecentSaveStates
    @Default(.showRecentGames) private var showRecentGames
    @Default(.showFavorites) private var showFavorites
    
    // Import status view properties
    @State private var showImportStatusView = false

    @ObservedResults(
        PVSaveState.self,
        filter: NSPredicate(format: "game != nil && game.system != nil"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates

    @ObservedResults(
        PVRecentGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
    ) var recentlyPlayedGames

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "\(#keyPath(PVGame.isFavorite)) == %@", NSNumber(value: true)),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var favorites

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "playCount > 0"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed

    /// Sorted by systemIdentifier, then title
    @ObservedResults(
        PVGame.self,
        sortDescriptor: .init(keyPath: \PVGame.title, ascending: false)
    ) var allGames
    // RomDatabase.sharedInstance.allGamesSortedBySystemThenTitle

    @State private var gamepadCancellable: AnyCancellable?

    @State private var focusedSection: HomeSectionType?
    @State private var focusedItemInSection: String?

    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?

    @State private var isControllerConnected: Bool = false

    /// GameContextMenuDelegate
    @State internal var showImagePicker = false
    @State internal var showArtworkSearch = false
    @State internal var selectedImage: UIImage?
    @State internal var gameToUpdateCover: PVGame?
    @State internal var showingRenameAlert = false
    @State internal var gameToRename: PVGame?
    @State internal var newGameTitle = ""
    @FocusState internal var renameTitleFieldIsFocused: Bool
    @State internal var systemMoveState: SystemMoveState?
    @State internal var continuesManagementState: ContinuesManagementState?

    @State private var showArtworkSourceAlert = false

    @State private var discSelectionAlert: DiscSelectionAlert?

    @State private var searchText = ""

    @State private var scrollOffset: CGFloat = 0
    @State private var previousScrollOffset: CGFloat = 0
    @State private var isSearchBarVisible: Bool = true

    init(
        gameLibrary: PVGameLibrary<RealmDatabaseDriver>? = nil,
        delegate: PVRootDelegate? = nil,
        viewModel: PVRootViewModel,
        showGameInfo: @escaping (String) -> Void
    ) {
        //        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
        self.viewModel = viewModel
        self.showGameInfo = showGameInfo

        _allGames = ObservedResults(
            PVGame.self,
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: viewModel.sortGamesAscending)
        )
    }

    @ObservedObject private var themeManager = ThemeManager.shared

    private var availableSections: [HomeSectionType] {
        [
            (showRecentSaveStates && !recentSaveStates.isEmpty) ? .recentSaveStates : nil,
            (showRecentGames && !recentlyPlayedGames.isEmpty) ? .recentlyPlayedGames : nil,
            (showFavorites && !favorites.isEmpty) ? .favorites : nil,
            !mostPlayed.isEmpty ? .mostPlayed : nil,
            !allGames.isEmpty ? .allGames : nil
        ].compactMap { $0 }
    }

    var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            VStack(spacing: 0) {
                // Add search bar with visibility control
                if allGames.count > 8 {
                    PVSearchBar(text: $searchText)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .opacity(isSearchBarVisible ? 1 : 0)
                        .frame(height: isSearchBarVisible ? nil : 0)
                        .animation(.easeInOut(duration: 0.3), value: isSearchBarVisible)
                }
                
                // Import Progress View
                ImportProgressView(
                    gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                    updatesController: AppState.shared.libraryUpdatesController!,
                    onTap: {
                        withAnimation {
                            showImportStatusView = true
                        }
                    }
                )
//                .padding(.vertical, 6)
//                .padding(.horizontal, 8)
//                .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
//                .padding(.horizontal, 8)

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
                        LazyVStack {
                            continuesSection()
                                .id("section_continues")
                            favoritesSection()
                                .id("section_favorites")
                            recentlyPlayedSection()
                                .id("section_recent")
                            mostPlayedSection()
                            displayOptionsView()
                            if viewModel.viewGamesAsGrid {
                                showGamesGrid(allGames)
                                    .id("section_allgames")
                            } else {
                                showGamesList(allGames)
                                    .id("section_allgames")
                            }
                        }
                        .onChange(of: focusedItemInSection) { newValue in
                            if let id = newValue {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(id, anchor: .center)
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
            }
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
            .padding(.bottom, 64)
        }
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        .onAppear {
            adjustZoomLevel(for: gameLibraryScale)
            setupGamepadHandling()

            // Check initial controller connection state
            isControllerConnected = GamepadManager.shared.isControllerConnected

            if isControllerConnected {
                setInitialFocus()
            }
        }
        .onChange(of: GamepadManager.shared.isControllerConnected) { isConnected in
            isControllerConnected = isConnected
            if isConnected {
                setInitialFocus()
            }
        }
        .task {
            // Set initial focus
            if let firstSection = [
                showRecentSaveStates && !recentSaveStates.isEmpty ? HomeSectionType.recentSaveStates : nil,
                showRecentGames && !recentlyPlayedGames.isEmpty ? .recentlyPlayedGames : nil,
                showFavorites && !favorites.isEmpty ? .favorites : nil,
                !allGames.isEmpty ? .allGames : nil
            ].compactMap({ $0 }).first {
                focusedSection = firstSection
                focusedItemInSection = getFirstItemInSection(firstSection)
            }
        }
        .onDisappear {
            delayTask?.cancel()
            continuousNavigationTask?.cancel()
            gamepadCancellable?.cancel()
        }
        .onChange(of: focusedSection) { newValue in
            DLOG("Focus changed to section: \(String(describing: newValue))")
        }
        .onChange(of: focusedItemInSection) { newValue in
            DLOG("Focus changed to item: \(String(describing: newValue))")
        }
        /// GameContextMenuDelegate
        /// TODO: This is an ugly copy/paste from `ConsolesGameView.swift`
        // Import Status View
        .fullScreenCover(isPresented: $showImportStatusView) {
            ImportStatusView(
                updatesController: AppState.shared.libraryUpdatesController!,
                gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                dismissAction: {
                    withAnimation {
                        showImportStatusView = false
                    }
                }
            )
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
                initialSystem: gameToUpdateCover?.system?.enumValue ?? SystemIdentifier.Unknown
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
                    submitRename()
                    gameToRename = nil
                    newGameTitle = ""
                    showingRenameAlert = false
                },
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    showingRenameAlert = false
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
                get: { discSelectionAlert != nil },
                set: { if !$0 { discSelectionAlert = nil } }
            ),
            preferredContentSize: CGSize(width: 500, height: 300)
        ) {
            if let alert = discSelectionAlert, let game = alert.game {
                let actions = alert.discs.map { (disc: DiscSelectionAlert.Disc) -> UIAlertAction in
                    UIAlertAction(title: disc.fileName, style: .default) { _ in
                        Task {
                            await rootDelegate?.root_loadPath(disc.path, forGame: game, sender: nil, core: nil, saveState: nil)
                        }
                    }
                }

                actions + [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel)]
            } else {
                [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel)]
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
                    gameToUpdateCover = game
                    showArtworkSearch = true
                }
                UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                    showArtworkSourceAlert = false
                }
            }
        )
        /// END: GameContextMenuDelegate
    }

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard !viewModel.isMenuVisible else {
                    DLOG("🎮 HomeView: Ignoring input - menu visible")
                    return
                }

                DLOG("🎮 HomeView: Received event: \(event)")

                switch event {
                case .buttonPress(true):
                    DLOG("🎮 HomeView: Button press detected")
                    handleButtonPress()
                case .verticalNavigation(let value, true):
                    DLOG("🎮 HomeView: Vertical navigation: \(value)")
                    DLOG("🎮 HomeView: Current section: \(String(describing: focusedSection))")
                    DLOG("🎮 HomeView: Current item: \(String(describing: focusedItemInSection))")
                    DLOG("🎮 HomeView: Available sections: \(availableSections)")
                    handleVerticalNavigation(value)
                case .horizontalNavigation(let value, true):
                    DLOG("🎮 HomeView: Horizontal navigation: \(value)")
                    handleHorizontalNavigation(value)
                default:
                    break
                }
            }
    }

    @Default(.gameLibraryScale) internal var gameLibraryScale
    @State internal var gameLibraryItemsPerRow: Int = 4
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

    var itemsPerRow: Int {
        let roundedScale = Int(gameLibraryScale.rounded())
        // If games is less than count, just use the games to fill the row.
        // also don't go below 0
        let count: Int
        if AppState.shared.isSimulator {
            count = max(0,roundedScale )
        } else {
            count = min(max(0, roundedScale), allGames.count)
        }
        return count
    }


    private func handleMenuToggle() {
        // Implement menu toggle logic here
        DLOG("Menu toggle requested")
    }

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
        .padding(.horizontal, 12)
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
        .shadow(color: RetroTheme.retroPurple.opacity(0.7), radius: 3, x: 0, y: 0)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func showGamesList(_ games: Results<PVGame>) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
                if !game.isInvalidated {
                    GameItemView(
                        game: game,
                        constrainHeight: true,
                        viewType: .row,
                        sectionContext: .allGames,
                        isFocused: Binding(
                            get: {
                                !game.isInvalidated &&
                                focusedSection == .allGames &&
                                focusedItemInSection == game.id
                            },
                            set: {
                                if $0 {
                                    focusedSection = .allGames
                                    focusedItemInSection = game.id
                                }
                            }
                        )
                    ) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                    }
                    .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                }
            }
        }
    }

    @ViewBuilder
    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        var gameLibraryItemsPerRow: Int {
            let gamesPerRow = min(8, games.count)
            return gamesPerRow.isMultiple(of: 2) ? gamesPerRow : gamesPerRow + 1
        }

        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: itemsPerRow)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games, id: \.self) { game in
                gameGridItem(game)
            }
        }
        .padding(.horizontal, 10)
    }

    /// Creates a grid item view for a game with focus and context menu
    @ViewBuilder
    private func gameGridItem(_ game: PVGame) -> some View {
        GameItemView(
            game: game,
            constrainHeight: true,
            viewType: .cell,
            sectionContext: .allGames,
            isFocused: Binding(
                get: {
                    !game.isInvalidated &&
                    focusedSection == .allGames &&
                    focusedItemInSection == game.id
                },
                set: {
                    if $0 {
                        focusedSection = .allGames
                        focusedItemInSection = game.id
                    }
                }
            )
        ) {
            Task.detached { @MainActor in
                await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
            }
        }
        .focusableIfAvailable()
        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
    }

    // MARK: - GamepadNavigationDelegate

    func handleButtonPress() {
        guard let section = focusedSection,
              let itemId = focusedItemInSection else { return }

        switch section {
        case .recentSaveStates:
            if let saveState = recentSaveStates.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(saveState.game, sender: self, core: saveState.core, saveState: saveState)
                }
            }
        case .recentlyPlayedGames:
            if let game = recentlyPlayedGames.first(where: { $0.game?.id == itemId })?.game {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        case .favorites, .mostPlayed, .allGames:
            if let game = allGames.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        }
    }

    private func handleVerticalNavigation(_ yValue: Float) {
        DLOG("🎮 HomeView: Vertical navigation: \(yValue)")

        guard let currentSection = focusedSection else {
            DLOG("🎮 HomeView: No section focused, setting initial focus")
            setInitialFocus()
            return
        }

        // Handle navigation within current section first
        let items = getItemsForSection(currentSection)
        if let currentItem = focusedItemInSection,
           let currentIndex = items.firstIndex(of: currentItem) {

            if currentSection == .allGames {
                // Grid navigation
                let itemsPerRow = 4
                if yValue > 0 { // Moving up
                    let newIndex = currentIndex - itemsPerRow
                    if newIndex >= 0 {
                        focusedItemInSection = items[newIndex]
                        DLOG("🎮 HomeView: Moving up in grid to index: \(newIndex)")
                        return
                    }
                    // If we can't move up in the grid, try moving to previous section
                    if let prevSection = getPreviousSection(from: currentSection) {
                        focusedSection = prevSection
                        focusedItemInSection = getLastItemInSection(prevSection)
                        DLOG("🎮 HomeView: Moving to previous section: \(prevSection)")
                    }
                } else { // Moving down
                    let newIndex = currentIndex + itemsPerRow
                    if newIndex < items.count {
                        focusedItemInSection = items[newIndex]
                        DLOG("🎮 HomeView: Moving down in grid to index: \(newIndex)")
                    }
                }
            } else {
                // Linear navigation for non-grid sections
                handleVerticalNavigationWithinSection(currentSection, direction: yValue)
            }
        }
    }

    private func getPreviousSection(from currentSection: HomeSectionType) -> HomeSectionType? {
        let sections = availableSections
        guard let currentIndex = sections.firstIndex(of: currentSection),
              currentIndex > 0 else { return nil }
        return sections[currentIndex - 1]
    }

    private func getNextSection(from currentSection: HomeSectionType) -> HomeSectionType? {
        let sections = availableSections
        guard let currentIndex = sections.firstIndex(of: currentSection),
              currentIndex < sections.count - 1 else { return nil }
        return sections[currentIndex + 1]
    }

    private func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = focusedSection else { return }

        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return }

        let newIndex = xValue < 0 ?
        max(0, currentIndex - 1) :
        min(items.count - 1, currentIndex + 1)

        focusedItemInSection = items[newIndex]
    }

    private func isMovingToNewSection(currentSection: HomeSectionType, direction: Float) -> Bool {
        let sections = availableSections
        guard let currentIndex = sections.firstIndex(of: currentSection) else {
            DLOG("Current section not found in available sections")
            return false
        }

        if direction > 0 && currentIndex > 0 { // Moving up
            return true
        } else if direction < 0 && currentIndex < sections.count - 1 { // Moving down
            return true
        }

        return false
    }

    private func getNextSection(from currentSection: HomeSectionType, direction: Float) -> HomeSectionType? {
        let sections = availableSections
        guard let currentIndex = sections.firstIndex(of: currentSection) else { return nil }

        let newIndex = direction > 0 ?
        currentIndex - 1 : // Moving up
        currentIndex + 1   // Moving down

        guard newIndex >= 0 && newIndex < sections.count else { return nil }
        return sections[newIndex]
    }

    private func moveWithinSection(_ section: HomeSectionType, direction: Float) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }

        let newIndex = direction < 0 ?
        max(0, currentIndex - 1) :
        min(items.count - 1, currentIndex + 1)

        focusedItemInSection = items[newIndex]
        return true
    }

    private func moveBetweenSections(_ currentSection: HomeSectionType, direction: Float) -> Bool {
        if let nextSection = getNextSection(from: currentSection, direction: direction) {
            let newItem = direction < 0 ?
            getFirstItemInSection(nextSection) :
            getLastItemInSection(nextSection)

            focusedSection = nextSection
            focusedItemInSection = newItem
            return true
        }
        return false
    }

    private func isOnFirstItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == 0
    }

    private func isOnLastItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == items.count - 1
    }

    private func getLastItemInSection(_ section: HomeSectionType) -> String? {
        switch section {
        case .recentSaveStates:
            return recentSaveStates.last?.id
        case .recentlyPlayedGames:
            return recentlyPlayedGames.last?.game?.id
        case .favorites:
            return favorites.last?.id
        case .mostPlayed:
            return mostPlayed.last?.id
        case .allGames:
            return allGames.last?.id
        }
    }

    private func getItemsForSection(_ section: HomeSectionType) -> [String] {
        switch section {
        case .recentSaveStates:
            return recentSaveStates.map { $0.id }
        case .recentlyPlayedGames:
            return recentlyPlayedGames.compactMap { $0.game?.id }
        case .favorites:
            return favorites.map { $0.id }
        case .mostPlayed:
            return mostPlayed.map { $0.id }
        case .allGames:
            return allGames.map { $0.id }
        }
    }

    private func getFirstItemInSection(_ section: HomeSectionType) -> String? {
        switch section {
        case .recentSaveStates:
            return recentSaveStates.first?.id
        case .recentlyPlayedGames:
            return recentlyPlayedGames.first?.game?.id
        case .favorites:
            return favorites.first?.id
        case .mostPlayed:
            return mostPlayed.first?.id
        case .allGames:
            return allGames.first?.id
        }
    }

    private func showOptionsMenu(for gameId: String) {
        // Similar to ConsoleGamesView implementation
        // Show context menu for the focused game
    }

    @ViewBuilder
    private func continuesSection() -> some View {
        if showRecentSaveStates {
            HomeContinueSection(
                rootDelegate: rootDelegate,
                consoleIdentifier: nil,
                parentFocusedSection: Binding(
                    get: { self.focusedSection },
                    set: { self.focusedSection = $0 }
                ),
                parentFocusedItem: Binding(
                    get: { self.focusedItemInSection },
                    set: { self.focusedItemInSection = $0 }
                )
            )
        }
    }

    @ViewBuilder
    private func recentlyPlayedSection() -> some View {
        if showRecentGames {
            HomeSection(title: "Recently Played") {
                ForEach(recentlyPlayedGames.compactMap{$0.game}, id: \.self) { game in
                    GameItemView(
                        game: game,
                        constrainHeight: true,
                        viewType: .cell,
                        sectionContext: .recentlyPlayedGames,
                        isFocused: Binding(
                            get: {
                                !game.isInvalidated &&
                                focusedSection == .recentlyPlayedGames &&
                                focusedItemInSection == game.id
                            },
                            set: {
                                if $0 {
                                    focusedSection = .recentlyPlayedGames
                                    focusedItemInSection = game.id
                                }
                            }
                        )
                    ) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                    }
                    .focusableIfAvailable()
                    .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                }
            }
            HomeDividerView()
        }
    }

    @ViewBuilder
    private func favoritesSection() -> some View {
        if showFavorites {
            HomeSection(title: "Favorites") {
                ForEach(favorites, id: \.self) { favorite in
                    GameItemView(
                        game: favorite,
                        constrainHeight: true,
                        viewType: .cell,
                        sectionContext: .favorites,
                        isFocused: Binding(
                            get: {
                                !favorite.isInvalidated &&
                                focusedSection == .favorites &&
                                focusedItemInSection == favorite.id
                            },
                            set: {
                                if $0 {
                                    focusedSection = .favorites
                                    focusedItemInSection = favorite.id
                                }
                            }
                        )
                    ) {
                        Task.detached { @MainActor in
                            await rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)
                        }
                    }
                    .focusableIfAvailable()
                    .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                }
            }
            HomeDividerView()
        }
    }

    @ViewBuilder
    private func mostPlayedSection() -> some View {
        HomeSection(title: "Most Played") {
            ForEach(mostPlayed, id: \.self) { playedGame in
                GameItemView(
                    game: playedGame,
                    constrainHeight: true,
                    viewType: .cell,
                    sectionContext: .mostPlayed,
                    isFocused: Binding(
                        get: {
                            !playedGame.isInvalidated &&
                            focusedSection == .mostPlayed &&
                            focusedItemInSection == playedGame.id
                        },
                        set: {
                            if $0 {
                                focusedSection = .mostPlayed
                                focusedItemInSection = playedGame.id
                            }
                        }
                    )
                ) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(playedGame, sender: self, core: nil, saveState: nil)
                    }
                }
                .focusableIfAvailable()
                .contextMenu { GameContextMenu(game: playedGame, rootDelegate: rootDelegate, contextMenuDelegate: self) }
            }
        }
        HomeDividerView()
    }

    private func setInitialFocus() {
        if let firstSection = [
            showRecentSaveStates && !recentSaveStates.isEmpty ? HomeSectionType.recentSaveStates : nil,
            showRecentGames && !recentlyPlayedGames.isEmpty ? .recentlyPlayedGames : nil,
            showFavorites && !favorites.isEmpty ? .favorites : nil,
            !allGames.isEmpty ? .allGames : nil
        ].compactMap({ $0 }).first {
            focusedSection = firstSection
            focusedItemInSection = getFirstItemInSection(firstSection)
        }
    }

    private func handleVerticalNavigationWithinSection(_ section: HomeSectionType, direction: Float) {
        DLOG("Handling vertical navigation within section: \(section)")

        switch section {
        case .allGames:
            let games = Array(allGames)
            if let currentItem = focusedItemInSection,
               let currentIndex = games.firstIndex(where: { $0.id == currentItem }) {

                // Calculate items per row based on screen width or use default
                let itemsPerRow = 4 // We can make this dynamic later if needed

                if direction > 0 { // Moving up
                    let newIndex = currentIndex - itemsPerRow
                    if newIndex >= 0 {
                        focusedItemInSection = games[newIndex].id
                        DLOG("Moving up in grid to index: \(newIndex)")
                    } else {
                        // At top of grid, try to move to previous section
                        if let prevSection = getNextSection(from: section, direction: direction) {
                            focusedSection = prevSection
                            focusedItemInSection = getLastItemInSection(prevSection)
                            DLOG("Moving to previous section: \(prevSection)")
                        }
                    }
                } else { // Moving down
                    let newIndex = currentIndex + itemsPerRow
                    if newIndex < games.count {
                        focusedItemInSection = games[newIndex].id
                        DLOG("Moving down in grid to index: \(newIndex)")
                    } else {
                        // At bottom of grid, try to move to next section
                        if let nextSection = getNextSection(from: section, direction: direction) {
                            focusedSection = nextSection
                            focusedItemInSection = getFirstItemInSection(nextSection)
                            DLOG("Moving to next section: \(nextSection)")
                        }
                    }
                }
            }

        default:
            // For non-grid sections, handle linear navigation
            let items = getItemsForSection(section)
            if let currentItem = focusedItemInSection,
               let currentIndex = items.firstIndex(of: currentItem) {

                if direction > 0 { // Moving up
                    if currentIndex > 0 {
                        focusedItemInSection = items[currentIndex - 1]
                        DLOG("Moving up in section to index: \(currentIndex - 1)")
                    } else {
                        // At top of section, try to move to previous section
                        if let prevSection = getNextSection(from: section, direction: direction) {
                            focusedSection = prevSection
                            focusedItemInSection = getLastItemInSection(prevSection)
                            DLOG("Moving to previous section: \(prevSection)")
                        }
                    }
                } else { // Moving down
                    if currentIndex < items.count - 1 {
                        focusedItemInSection = items[currentIndex + 1]
                        DLOG("Moving down in section to index: \(currentIndex + 1)")
                    } else {
                        // At bottom of section, try to move to next section
                        if let nextSection = getNextSection(from: section, direction: direction) {
                            focusedSection = nextSection
                            focusedItemInSection = getFirstItemInSection(nextSection)
                            DLOG("Moving to next section: \(nextSection)")
                        }
                    }
                }
            }
        }
    }

    // Add this computed property to create the binding wrapper
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
        return Array(allGames.filter { game in
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
                                    focusedSection == .allGames &&
                                    focusedItemInSection == game.id
                                },
                                set: {
                                    if $0 {
                                        focusedSection = .allGames
                                        focusedItemInSection = game.id
                                    }
                                }
                            )
                        ) {
                            Task.detached { @MainActor in
                                await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                            }
                        }
                        .focusableIfAvailable()
                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                        GamesDividerView()
                    }
                }
            }
        }
    }
}
#endif

extension HomeView: GameContextMenuDelegate {

#if !os(tvOS)
    @ViewBuilder
    internal func imagePickerView() -> some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = gameToUpdateCover {
                saveArtwork(image: image, forGame: game)
            }
            gameToUpdateCover = nil
            showImagePicker = false
        }
    }
#endif

    @ViewBuilder
    internal func renameAlertView() -> some View {
        Group {
            TextField("New name", text: $newGameTitle)
                .onSubmit { submitRename() }
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) { showingRenameAlert = false }
            Button("OK") { submitRename() }
        }
    }

    // MARK: - Rename Methods
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        gameToRename = game.freeze()
        newGameTitle = game.title
        showingRenameAlert = true
    }

    private func submitRename() {
        if !newGameTitle.isEmpty, let frozenGame = gameToRename, newGameTitle != frozenGame.title {
            do {
                guard let thawedGame = frozenGame.thaw() else {
                    throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to thaw game object"])
                }
                RomDatabase.sharedInstance.renameGame(thawedGame, toTitle: newGameTitle)
                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if newGameTitle.isEmpty {
            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        showingRenameAlert = false
        gameToRename = nil
    }

    // MARK: - Image Picker Methods

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID = UUID().uuidString
        let md5: String = game.md5 ?? ""
        let key = "artwork_\(md5)_\(uniqueID)"
        DLOG("Generated key for image: \(key)")

        do {
            DLOG("Attempting to write image to disk")
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            DLOG("Image successfully written to disk")

            DLOG("Attempting to update game's customArtworkURL")
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                DLOG("Game thawed: \(thawedGame?.title ?? "Unknown")")
                thawedGame?.customArtworkURL = key
                DLOG("Game's customArtworkURL updated to: \(key)")
            }
            DLOG("Database transaction completed successfully")
            rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

            DLOG("Attempting to verify image retrieval")
            PVMediaCache.shareInstance().image(forKey: key) { retrievedKey, retrievedImage in
                if let retrievedImage = retrievedImage {
                    DLOG("Successfully retrieved saved image for key: \(retrievedKey)")
                    DLOG("Retrieved image size: \(retrievedImage.size)")
                } else {
                    DLOG("Failed to retrieve saved image for key: \(retrievedKey)")
                }
            }
        } catch {
            DLOG("Failed to set custom artwork: \(error.localizedDescription)")
            DLOG("Error details: \(error)")
            rootDelegate?.showMessage("Failed to set custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to move game to system")
        let frozenGame = game.isFrozen ? game : game.freeze()
        systemMoveState = SystemMoveState(game: frozenGame)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("ConsoleGamesView: Received request to show save states for game")
        continuesManagementState = ContinuesManagementState(game: game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor game: String) {
        showGameInfo(game)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        gameToUpdateCover = game
        showArtworkSearch = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("Setting gameToUpdateCover with game: \(game.title)")
        gameToUpdateCover = game
        showArtworkSourceAlert = true
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        // Only show disc selection if there are multiple associated files
        let associatedFiles = game.relatedFiles.toArray()
        let uniqueFiles = Set(associatedFiles.compactMap { $0.url?.path })

        guard uniqueFiles.count > 1 else {
            return
        }

        presentDiscSelectionAlert(for: game, rootDelegate: rootDelegate)
    }

    private func presentDiscSelectionAlert(for game: PVGame, rootDelegate: PVRootDelegate?) {
        let discs = game.relatedFiles.toArray()
        let alertDiscs: [DiscSelectionAlert.Disc] = discs.compactMap { (disc: PVFile?) -> DiscSelectionAlert.Disc? in
            guard let disc = disc, let url = disc.url else {
                WLOG("nil file for disc")
                return nil
            }
            return DiscSelectionAlert.Disc(fileName: disc.fileName, path: url.path)
        }

        self.discSelectionAlert = DiscSelectionAlert(
            game: game,
            discs: alertDiscs
        )
    }
}

// Add this struct at the end of the file
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
        }
    }
}

// Add this ScrollViewWithOffset struct if it doesn't already exist in the file
struct ScrollViewWithOffset<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let offsetChanged: (CGFloat) -> Void
    let content: Content

    init(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        offsetChanged: @escaping (CGFloat) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.offsetChanged = offsetChanged
        self.content = content()
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).origin.y
                )
            }
            .frame(width: 0, height: 0)

            content
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            offsetChanged(offset)
        }
    }
}
