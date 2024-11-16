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

enum PVHomeSection: Int, CaseIterable, Sendable {
    case recentSaveStates
    case recentlyPlayedGames
    case favorites
    case mostPlayed
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

    @FocusState private var focusedSection: GameSection?
    @FocusState private var focusedItemInSection: String?

    @State private var navigationTimer: Timer?
    @State private var initialDelay: TimeInterval = 0.5
    @State private var repeatDelay: TimeInterval = 0.15

    init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>? = nil, delegate: PVRootDelegate? = nil, viewModel: PVRootViewModel) {
//        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
        self.viewModel = viewModel
    }

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            ScrollView {
                LazyVStack {
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

                    if showRecentGames {
                        HomeSection(title: "Recently Played") {
                            ForEach(recentlyPlayedGames.compactMap{$0.game}, id: \.self) { game in
                                GameItemView(game: game, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)}
                                }
                                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                            }
                        }
                        HomeDividerView()
                    }

                    if showFavorites {
                        HomeSection(title: "Favorites") {
                            ForEach(favorites, id: \.self) { favorite in
                                GameItemView(game: favorite, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)}
                                }
                                .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate) }
                            }
                        }
                        HomeDividerView()
                    }

                    HomeSection(title: "Most Played") {
                        ForEach(mostPlayed, id: \.self) { playedGame in
                            GameItemView(game: playedGame, constrainHeight: true) {
                                Task.detached { @MainActor in
                                    await rootDelegate?.root_load(playedGame, sender: self, core: nil, saveState: nil)}
                            }
                            .contextMenu { GameContextMenu(game: playedGame, rootDelegate: rootDelegate) }
                        }
                    }

                    HomeDividerView()
                    displayOptionsView()
                    showGamesGrid(allGames)
                }
            }
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        }
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        .onAppear {
            setupGamepadHandling()
        }
        .onDisappear {
            navigationTimer?.invalidate()
            gamepadCancellable?.cancel()
        }
    }

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .buttonPress:
                    handleButtonPress()
                case .verticalNavigation(let value, let isPressed):
                    // Cancel existing timer if any
                    navigationTimer?.invalidate()
                    navigationTimer = nil

                    // Perform initial navigation
                    handleVerticalNavigation(value)

                    // Only setup continuous navigation if button is pressed
                    if isPressed {
                        navigationTimer = Timer.scheduledTimer(withTimeInterval: initialDelay, repeats: false) { [self] _ in
                            navigationTimer = Timer.scheduledTimer(withTimeInterval: repeatDelay, repeats: true) { [self] _ in
                                handleVerticalNavigation(value)
                            }
                        }
                    }
                case .horizontalNavigation(let value, _):
                    handleHorizontalNavigation(value)
                case .start:
                    if let focusedItem = focusedItemInSection {
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
                GameItemView(game: game, constrainHeight: false, viewType: .cell) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)}
                }
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
            }
        }
    }

    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        let gamesPerRow = min(8, games.count)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: gamesPerRow)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games, id: \.self) { game in
                GameItemView(game: game, constrainHeight: false) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                }
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - GamepadNavigationDelegate

    func handleButtonPress() {
        guard let section = focusedSection, let itemId = focusedItemInSection else {
            print("No focused section or item")
            return
        }

        print("Handling button press for section: \(section), item: \(itemId)")

        switch section {
        case .continues:
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
        case .recentlyPlayed:
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
        case .games:
            if let game = allGames.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        }
    }

    func handleVerticalNavigation(_ yValue: Float) {
        let sections: [GameSection] = [
            showRecentSaveStates && !recentSaveStates.isEmpty ? .continues : nil,
            showRecentGames && !recentlyPlayedGames.isEmpty ? .recentlyPlayed : nil,
            showFavorites && !favorites.isEmpty ? .favorites : nil,
            !allGames.isEmpty ? .games : nil
        ].compactMap { $0 }

        guard !sections.isEmpty else { return }

        if let currentSection = focusedSection,
           let currentIndex = sections.firstIndex(of: currentSection) {
            let newIndex = yValue > 0 ?
                max(0, currentIndex - 1) :
                min(sections.count - 1, currentIndex + 1)
            focusedSection = sections[newIndex]
            focusedItemInSection = getFirstItemInSection(sections[newIndex])
        } else {
            focusedSection = sections.first
            focusedItemInSection = getFirstItemInSection(sections.first!)
        }

        print("Vertical navigation - New section: \(String(describing: focusedSection))")
    }

    func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = focusedSection else { return }

        let items: [String]
        switch section {
        case .continues:
            items = recentSaveStates.map { $0.id }
        case .recentlyPlayed:
            items = recentlyPlayedGames.compactMap { $0.game?.id }
        case .favorites:
            items = favorites.map { $0.id }
        case .games:
            items = allGames.map { $0.id }
        }

        if let currentItem = focusedItemInSection,
           let currentIndex = items.firstIndex(of: currentItem) {
            let newIndex = xValue < 0 ?
                max(0, currentIndex - 1) :
                min(items.count - 1, currentIndex + 1)
            focusedItemInSection = items[newIndex]
        } else {
            focusedItemInSection = items.first
        }

        print("Horizontal navigation - New item: \(String(describing: focusedItemInSection))")
    }

    private func getFirstItemInSection(_ section: GameSection) -> String? {
        switch section {
        case .continues:
            return recentSaveStates.first?.id
        case .recentlyPlayed:
            return recentlyPlayedGames.first?.game?.id
        case .favorites:
            return favorites.first?.id
        case .games:
            return allGames.first?.id
        }
    }

    private func showOptionsMenu(for gameId: String) {
        // Similar to ConsoleGamesView implementation
        // Show context menu for the focused game
    }
}

#endif
