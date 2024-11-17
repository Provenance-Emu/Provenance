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

enum HomeSectionType: Int, CaseIterable, Sendable {
    case recentSaveStates
    case recentlyPlayedGames
    case favorites
    case mostPlayed
    case allGames
}

@available(iOS 14, tvOS 14, *)
struct HomeView: SwiftUI.View {

//    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!

    weak var rootDelegate: PVRootDelegate?
    @ObservedObject var viewModel: PVRootViewModel

    @Default(.showRecentSaveStates) private var showRecentSaveStates
    @Default(.showRecentGames) private var showRecentGames
    @Default(.showFavorites) private var showFavorites

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
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed

    /// Sorted by systemIdentifier, then title
    @ObservedResults(
        PVGame.self,
        sortDescriptor: .init(keyPath: \PVGame.title, ascending: true)
    ) var allGames
    // RomDatabase.sharedInstance.allGamesSortedBySystemThenTitle

    @State private var gamepadCancellable: AnyCancellable?

    @State private var focusedSection: HomeSectionType?
    @State private var focusedItemInSection: String?

    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?

    @State private var isControllerConnected: Bool = false

    init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>? = nil, delegate: PVRootDelegate? = nil, viewModel: PVRootViewModel) {
//        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
        self.viewModel = viewModel
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
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack {
                        continuesSection()
                        recentlyPlayedSection()
                        favoritesSection()
                        mostPlayedSection()
                        displayOptionsView()
                        showGamesGrid(allGames)
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
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        }
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        .onAppear {
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
    }

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                guard !viewModel.isMenuVisible else {
                    print("🎮 HomeView: Ignoring input - menu visible")
                    return
                }

                print("🎮 HomeView: Received event: \(event)")

                switch event {
                case .buttonPress(true):
                    print("🎮 HomeView: Button press detected")
                    handleButtonPress()
                case .verticalNavigation(let value, true):
                    print("🎮 HomeView: Vertical navigation: \(value)")
                    print("🎮 HomeView: Current section: \(String(describing: focusedSection))")
                    print("🎮 HomeView: Current item: \(String(describing: focusedItemInSection))")
                    print("🎮 HomeView: Available sections: \(availableSections)")
                    handleVerticalNavigation(value)
                case .horizontalNavigation(let value, true):
                    print("🎮 HomeView: Horizontal navigation: \(value)")
                    handleHorizontalNavigation(value)
                default:
                    break
                }
            }
    }

    private func handleMenuToggle() {
        // Implement menu toggle logic here
        DLOG("Menu toggle requested")
    }

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
    }

    private func showGamesList(_ games: Results<PVGame>) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    viewType: .cell,
                    sectionContext: .allGames,
                    isFocused: Binding(
                        get: {
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
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
            }
        }
    }

    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        var gameLibraryItemsPerRow: Int {
            let gamesPerRow = min(8, games.count)
            return gamesPerRow.isMultiple(of: 2) ? gamesPerRow : gamesPerRow + 1
        }

        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: gameLibraryItemsPerRow)

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
        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
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
        DLOG("🎮 HomeView: Starting vertical navigation")
        DLOG("🎮 HomeView: Direction value: \(yValue)")
        DLOG("🎮 HomeView: Current section: \(String(describing: focusedSection))")
        DLOG("🎮 HomeView: Current item: \(String(describing: focusedItemInSection))")

        guard let currentSection = focusedSection else {
            DLOG("🎮 HomeView: No section focused, setting initial focus")
            setInitialFocus()
            return
        }

        let sections = availableSections
        DLOG("🎮 HomeView: Available sections: \(sections)")

        guard let currentIndex = sections.firstIndex(of: currentSection) else {
            DLOG("🎮 HomeView: Current section not found in available sections")
            return
        }

        DLOG("🎮 HomeView: Current section index: \(currentIndex)")

        if yValue < 0 { // Moving down
            if currentIndex < sections.count - 1 {
                let nextSection = sections[currentIndex + 1]
                DLOG("🎮 HomeView: Moving down to section: \(nextSection)")
                focusedSection = nextSection
                focusedItemInSection = getFirstItemInSection(nextSection)
                DLOG("🎮 HomeView: New focused item: \(String(describing: focusedItemInSection))")
            } else {
                DLOG("🎮 HomeView: Already at bottom section")
            }
        } else { // Moving up
            if currentIndex > 0 {
                let prevSection = sections[currentIndex - 1]
                DLOG("🎮 HomeView: Moving up to section: \(prevSection)")
                focusedSection = prevSection
                focusedItemInSection = getLastItemInSection(prevSection)
                DLOG("🎮 HomeView: New focused item: \(String(describing: focusedItemInSection))")
            } else {
                DLOG("🎮 HomeView: Already at top section")
            }
        }
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
                    .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
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
                    .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate) }
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
                .contextMenu { GameContextMenu(game: playedGame, rootDelegate: rootDelegate) }
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
}
#endif
