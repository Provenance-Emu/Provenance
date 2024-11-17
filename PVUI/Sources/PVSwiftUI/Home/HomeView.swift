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

    @FocusState private var focusedSection: HomeSectionType?
    @FocusState private var focusedItemInSection: String?

    @State private var continuousNavigationTask: Task<Void, Never>?
    @State private var delayTask: Task<Void, Never>?

    @State private var isControllerConnected: Bool = false

    init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>? = nil, delegate: PVRootDelegate? = nil, viewModel: PVRootViewModel) {
//        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
        self.viewModel = viewModel
    }

    @ObservedObject private var themeManager = ThemeManager.shared

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
                            withAnimation {
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
            print("Focus changed to section: \(String(describing: newValue))")
        }
        .onChange(of: focusedItemInSection) { newValue in
            print("Focus changed to item: \(String(describing: newValue))")
        }
    }

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                // Only handle events if we're on the home screen
                guard !viewModel.isMenuVisible,
                      viewModel.selectedConsole == nil
                else { return }

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
                case .start(let isPressed):
                    if isPressed, let focusedItem = focusedItemInSection {
                        showOptionsMenu(for: focusedItem)
                    }
                default:
                    break
                }
            }
    }

    private func handleMenuToggle() {
        // Implement menu toggle logic here
        print("Menu toggle requested")
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
        guard let section = focusedSection, let itemId = focusedItemInSection else {
            print("No focused section or item")
            return
        }

        print("Handling button press for section: \(section), item: \(itemId)")

        switch section {
        case .recentSaveStates:
            if let saveState = recentSaveStates.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(
                        saveState.game,
                        sender: self,
                        core: saveState.core,
                        saveState: saveState
                    )
                }
            }
        case .recentlyPlayedGames:
            if let recentGame = recentlyPlayedGames.first(where: { $0.game?.id == itemId })?.game {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(recentGame, sender: self, core: nil, saveState: nil)
                }
            }
        case .favorites:
            if let game = favorites.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        case .mostPlayed:
            if let game = mostPlayed.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        case .allGames:
            if let game = allGames.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        }
    }

    private func handleVerticalNavigation(_ yValue: Float) {
        let sections: [HomeSectionType] = [
            showRecentSaveStates && !recentSaveStates.isEmpty ? .recentSaveStates : nil,
            showRecentGames && !recentlyPlayedGames.isEmpty ? .recentlyPlayedGames : nil,
            showFavorites && !favorites.isEmpty ? .favorites : nil,
            !mostPlayed.isEmpty ? .mostPlayed : nil,
            !allGames.isEmpty ? .allGames : nil
        ].compactMap { $0 }

        guard !sections.isEmpty else { return }

        if let currentSection = focusedSection,
           let currentIndex = sections.firstIndex(of: currentSection) {
            let newIndex = yValue > 0 ?
                max(0, currentIndex - 1) :
                min(sections.count - 1, currentIndex + 1)
            focusedSection = sections[newIndex]
            focusedItemInSection = getFirstItemInSection(sections[newIndex])

            print("Vertical navigation - New section: \(sections[newIndex])")
        } else {
            focusedSection = sections.first
            focusedItemInSection = getFirstItemInSection(sections.first!)
            print("Initial focus set to: \(String(describing: sections.first))")
        }
    }

    private func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = focusedSection else { return }

        let items: [String]
        switch section {
        case .recentSaveStates:
            items = recentSaveStates.map { $0.id }
        case .recentlyPlayedGames:
            items = recentlyPlayedGames.compactMap { $0.game?.id }
        case .favorites:
            items = favorites.map { $0.id }
        case .mostPlayed:
            items = mostPlayed.map { $0.id }
        case .allGames:
            items = allGames.map { $0.id }
        }

        guard !items.isEmpty else { return }

        if let currentItem = focusedItemInSection,
           let currentIndex = items.firstIndex(of: currentItem) {
            let newIndex = xValue < 0 ?
                (currentIndex > 0 ? currentIndex - 1 : items.count - 1) :
                (currentIndex < items.count - 1 ? currentIndex + 1 : 0)
            focusedItemInSection = items[newIndex]
        } else {
            focusedItemInSection = items.first
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
}

#endif
