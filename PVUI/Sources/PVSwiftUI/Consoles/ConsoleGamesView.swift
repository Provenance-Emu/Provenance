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

private struct SystemMoveState: Identifiable {
    var id: String { game.id }
    let game: PVGame
    var isPresenting: Bool = true
}

class ConsoleGamesViewModel: ObservableObject {
    let console: PVSystem

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

    init(console: PVSystem) {
        self.console = console
        _games = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
        )
        _recentSaveStates = ObservedResults(
            PVSaveState.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
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
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
        )
    }
}

struct ConsoleGamesView: SwiftUI.View, GameContextMenuDelegate {

    @StateObject private var gamesViewModel: ConsoleGamesViewModel
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedRealmObject var console: PVSystem
    weak var rootDelegate: PVRootDelegate?

    let gamesForSystemPredicate: NSPredicate

    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var gameLibraryItemsPerRow: Int = 4
    @Default(.gameLibraryScale) private var gameLibraryScale

    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var gameToUpdateCover: PVGame?
    @State private var showingRenameAlert = false
    @State private var gameToRename: PVGame?
    @State private var newGameTitle = ""
    @FocusState private var renameTitleFieldIsFocused: Bool

    @Default(.showRecentSaveStates) private var showRecentSaveStates
    @Default(.showFavorites) private var showFavorites
    @Default(.showRecentGames) private var showRecentGames

    @State private var systemMoveState: SystemMoveState?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var focusedSection: HomeSectionType?
    @State private var focusedItemInSection: String?

    @State private var gamepadHandler: Any?
    @State private var lastFocusedSection: HomeSectionType?

    @State private var gamepadCancellable: AnyCancellable?

    @State private var navigationTimer: Timer?
    @State private var initialDelay: TimeInterval = 0.5
    @State private var repeatDelay: TimeInterval = 0.15

    private var sectionHeight: CGFloat {
        // Use compact size class to determine if we're in portrait on iPhone
        let baseHeight: CGFloat = horizontalSizeClass == .compact ? 150 : 75
        return verticalSizeClass == .compact ? baseHeight / 2 : baseHeight
    }

    private var focusedSectionBinding: Binding<HomeSectionType?> {
        Binding(
            get: { focusedSection },
            set: { focusedSection = $0 }
        )
    }

    private var focusedItemBinding: Binding<String?> {
        Binding(
            get: { focusedItemInSection },
            set: { focusedItemInSection = $0 }
        )
    }

    init(console: PVSystem, viewModel: PVRootViewModel, rootDelegate: PVRootDelegate? = nil) {
        _gamesViewModel = StateObject(wrappedValue: ConsoleGamesViewModel(console: console))
        self.console = console
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
        self.gamesForSystemPredicate = NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])
    }

    var body: some SwiftUI.View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                displayOptionsView()
                ZStack(alignment: .bottom) {
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 20) {
                                continueSection()
                                    .id("section_continues")
                                favoritesSection()
                                    .id("section_favorites")
                                recentlyPlayedSection()
                                    .id("section_recent")
                                gamesSection()
                                    .id("section_allgames")
                                BiosesView(console: console)
                            }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 44)
                            .onChange(of: focusedSection) { newSection in
                                if let section = newSection {
                                    withAnimation {
                                        let sectionId = sectionToId(section)
                                        proxy.scrollTo(sectionId, anchor: .top)
                                    }
                                }
                            }
                        }
                    }.refreshable {
                        ILOG("Refreshing game library")
                        await AppState.shared.libraryUpdatesController?.importROMDirectories()
                    }
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            #if !os(tvOS)
            .gesture(magnificationGesture())
            #endif
            .onAppear {
                adjustZoomLevel(for: gameLibraryScale)
                setupGamepadHandling()

                // Set initial focus
                let sections: [HomeSectionType] = [
                    showRecentSaveStates && !gamesViewModel.recentSaveStates.isEmpty ? .recentSaveStates : nil,
                    showFavorites && !gamesViewModel.favorites.isEmpty ? .favorites : nil,
                    showRecentGames && !gamesViewModel.recentlyPlayedGames.isEmpty ? .recentlyPlayedGames : nil,
                    !gamesViewModel.games.isEmpty ? .allGames : nil
                ].compactMap { $0 }

                if let firstSection = sections.first {
                    focusedSection = firstSection
                    focusedItemInSection = getFirstItemInSection(firstSection)
                    DLOG("Set initial focus - Section: \(firstSection), Item: \(String(describing: focusedItemInSection))")
                }
            }
            .onDisappear {
                gamepadCancellable?.cancel()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            #if !os(tvOS)
            imagePickerView()
            #endif
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
    }

    // MARK: - View Components

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

    private func continueSection() -> some View {
        Group {
            if showRecentSaveStates && !gamesViewModel.recentSaveStates.isEmpty {
                HomeContinueSection(
                    rootDelegate: rootDelegate,
                    consoleIdentifier: console.identifier,
                    parentFocusedSection: focusedSectionBinding,
                    parentFocusedItem: focusedItemBinding
                )
                HomeDividerView()
            }
        }
    }

    private func favoritesSection() -> some View {
        Group {
            if showFavorites && !gamesViewModel.favorites.isEmpty {
                HomeSection(title: "Favorites") {
                    ForEach(gamesViewModel.favorites, id: \.self) { game in
                        gameItem(game)
                    }
                }
                .frame(height: sectionHeight)
                HomeDividerView()
            }
        }
    }

    private func recentlyPlayedSection() -> some View {
        Group {
            if showRecentGames && !gamesViewModel.recentlyPlayedGames.isEmpty {
                HomeSection(title: "Recently Played") {
                    ForEach(gamesViewModel.recentlyPlayedGames, id: \.self) { recentGame in
                        if let game = recentGame.game {
                            gameItem(game)
                        }
                    }
                }
                .frame(height: sectionHeight)
                HomeDividerView()
            }
        }
    }

    private func gamesSection() -> some View {
        Group {
            if gamesViewModel.games.filter{!$0.isInvalidated}.isEmpty && AppState.shared.isSimulator {
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
                        showGamesGrid(gamesViewModel.games)
                    } else {
                        showGamesList(gamesViewModel.games)
                    }
                }
            }
        }
    }

#if !os(tvOS)
    private func imagePickerView() -> some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = gameToUpdateCover {
                saveArtwork(image: image, forGame: game)
            }
            gameToUpdateCover = nil
            showImagePicker = false
        }
    }
#endif

    private func renameAlertView() -> some View {
        Group {
            TextField("New name", text: $newGameTitle)
                .onSubmit { submitRename() }
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Cancel", role: .cancel) { showingRenameAlert = false }
            Button("OK") { submitRename() }
        }
    }

    // MARK: - Helper Methods
    private var hasRecentSaveStates: Bool {
        !gamesViewModel.recentSaveStates.filter("game.systemIdentifier == %@", console.identifier).isEmpty
    }

    private var hasFavorites: Bool {
        !gamesViewModel.favorites.filter("systemIdentifier == %@", console.identifier).isEmpty
    }

    private var favoritesArray: [PVGame] {
        Array(gamesViewModel.favorites.filter("systemIdentifier == %@", console.identifier))
    }

    private var hasRecentlyPlayedGames: Bool {
        !gamesViewModel.recentlyPlayedGames.isEmpty
    }

    private var recentlyPlayedGamesArray: [PVGame] {
        gamesViewModel.recentlyPlayedGames.compactMap { $0.game }
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
            count = min(max(0, roundedScale), gamesViewModel.games.count)
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
                    isFocused: Binding(
                        get: { focusedItemInSection == game.id },
                        set: { if $0 { focusedItemInSection = game.id } }
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
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games.filter{!$0.isInvalidated}, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    isFocused: Binding(
                        get: { focusedItemInSection == game.id },
                        set: { if $0 { focusedItemInSection = game.id } }
                    )
                ) {
                    Task.detached { @MainActor in
                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                    }
                }
                .id(game.id)
                .focusableIfAvailable()
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
            }
        }
        .padding(.horizontal, 10)
    }

    private func showGamesList(_ games: [PVGame]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(games.filter{!$0.isInvalidated}, id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: true,
                    viewType: .row,
                    isFocused: Binding(
                        get: { focusedItemInSection == game.id },
                        set: { if $0 { focusedItemInSection = game.id } }
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
                    isFocused: Binding(
                                 get: { focusedItemInSection == game.id },
                                 set: { if $0 { focusedItemInSection = game.id } }
                             ))
                {
                    loadGame(game)
                }
                .focusableIfAvailable()
                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
            }
        }
    }

    private func calculateGridItemSize() -> CGFloat {
        let numberOfItemsPerRow: CGFloat = CGFloat(gameLibraryScale)
        let totalSpacing: CGFloat = 10 * (numberOfItemsPerRow - 1)
        let availableWidth = UIScreen.main.bounds.width - totalSpacing - 20
        return availableWidth / numberOfItemsPerRow
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
        let key = "artwork_\(game.md5)_\(uniqueID)"
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
    }

    private func handleButtonPress() {
        guard let section = focusedSection, let itemId = focusedItemInSection else {
            DLOG("No focused section or item")
            return
        }

        DLOG("Handling button press for section: \(section), item: \(itemId)")

        switch section {
        case .recentSaveStates:
            if let saveState = gamesViewModel.recentSaveStates.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(
                        saveState.game,
                        sender: self,
                        core: saveState.core,
                        saveState: saveState
                    )
                }
            }
        case .favorites:
            if let game = gamesViewModel.favorites.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        case .recentlyPlayedGames:
            if let recentGame = gamesViewModel.recentlyPlayedGames.first(where: { $0.id == itemId })?.game {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(recentGame, sender: self, core: nil, saveState: nil)
                }
            }
        case .allGames:
            if let game = gamesViewModel.games.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        case .mostPlayed:
            if let game = gamesViewModel.mostPlayed.first(where: { $0.id == itemId }) {
                Task.detached { @MainActor in
                    await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                }
            }
        }
    }

    private func handleVerticalNavigation(_ yValue: Float) {
        let sections: [HomeSectionType] = [
            showRecentSaveStates && !gamesViewModel.recentSaveStates.isEmpty ? .recentSaveStates : nil,
            showFavorites && !gamesViewModel.favorites.isEmpty ? .favorites : nil,
            showRecentGames && !gamesViewModel.recentlyPlayedGames.isEmpty ? .recentlyPlayedGames : nil,
            !gamesViewModel.games.isEmpty ? .allGames : nil
        ].compactMap { $0 }

        guard !sections.isEmpty else { return }

        // For single section (grid) navigation
        if sections.count == 1 && sections[0] == .allGames {
            let games = Array(gamesViewModel.games)
            guard !games.isEmpty else { return }

            // Calculate total rows
            let totalRows = Int(ceil(Double(games.count) / Double(itemsPerRow)))

            // Handle edge case of only 1 row
            guard totalRows > 1 else { return }

            // If no item is focused, start with first item
            if focusedItemInSection == nil {
                focusedSection = .allGames
                focusedItemInSection = games.first?.id
                return
            }

            // Find current position in grid
            if let currentIndex = games.firstIndex(where: { $0.id == focusedItemInSection }) {
                let currentRow = currentIndex / itemsPerRow
                let columnPosition = currentIndex % itemsPerRow

                var newRow: Int
                if yValue > 0 {
                    // Move up
                    newRow = currentRow > 0 ? currentRow - 1 : totalRows - 1
                } else {
                    // Move down
                    newRow = currentRow < totalRows - 1 ? currentRow + 1 : 0
                }

                // Calculate new index maintaining column position
                let newIndex = min(games.count - 1, (newRow * itemsPerRow) + columnPosition)
                focusedItemInSection = games[newIndex].id
            }
            return
        }

        // Handle multi-section navigation as before
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
    }

    private func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = focusedSection else { return }

        let items: [String]
        switch section {
        case .recentSaveStates:
            items = gamesViewModel.recentSaveStates.map { $0.id }
        case .favorites:
            items = gamesViewModel.favorites.map { $0.id }
        case .recentlyPlayedGames:
            items = gamesViewModel.recentlyPlayedGames.map { $0.id }
        case .allGames:
            items = gamesViewModel.games.map { $0.id }
        case .mostPlayed:
            items = gamesViewModel.games.map { $0.id }
        }

        // Handle edge case of only 1 item
        guard items.count > 1 else { return }

        if let currentItem = focusedItemInSection,
           let currentIndex = items.firstIndex(of: currentItem) {
            let newIndex: Int
            if xValue < 0 {
                // Moving left
                newIndex = currentIndex > 0 ? currentIndex - 1 : items.count - 1
            } else {
                // Moving right
                newIndex = currentIndex < items.count - 1 ? currentIndex + 1 : 0
            }
            focusedItemInSection = items[newIndex]
        } else {
            focusedItemInSection = items.first
        }
    }

    private func getFirstItemInSection(_ section: HomeSectionType) -> String? {
        switch section {
        case .recentSaveStates:
            return gamesViewModel.recentSaveStates.first?.id
        case .recentlyPlayedGames:
            return gamesViewModel.recentlyPlayedGames.first?.game?.id
        case .favorites:
            return gamesViewModel.favorites.first?.id
        case .mostPlayed:
            return gamesViewModel.mostPlayed.first?.id
        case .allGames:
            DLOG("Getting first game from allGames section")
            DLOG("Games count: \(gamesViewModel.games.count)")
            if let firstGame = gamesViewModel.games.first {
                DLOG("First game: \(firstGame.title)")
                DLOG("First game ID: \(firstGame.id)")
                return firstGame.id
            }
            return nil
        }
    }

    private func gameItem(_ game: PVGame) -> some View {
        GameItemView(
            game: game,
            constrainHeight: true,
            isFocused: Binding(
                get: {
                    // Only show focus if:
                    // 1. We're in the current section
                    // 2. This item is focused
                    // 3. This view of the game belongs to the current section
                    let currentSection = currentSectionForGame(game)
                    return focusedSection == currentSection &&
                           focusedItemInSection == game.id &&
                           focusedSection == currentSection
                },
                set: {
                    if $0 {
                        focusedSection = currentSectionForGame(game)
                        focusedItemInSection = game.id
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

    private func currentSectionForGame(_ game: PVGame) -> HomeSectionType {
        // If we're in favorites section, ONLY return favorites if the game is actually in favorites
        if focusedSection == .favorites {
            return gamesViewModel.favorites.contains(where: { $0.id == game.id }) ? .favorites : .allGames
        }
        // If we're in recently played, ONLY return recently played if the game is actually in recently played
        else if focusedSection == .recentlyPlayedGames {
            return gamesViewModel.recentlyPlayedGames.contains(where: { $0.game?.id == game.id }) ? .recentlyPlayedGames : .allGames
        }
        // If we're in most played, ONLY return most played if the game is actually in most played
        else if focusedSection == .mostPlayed {
            return gamesViewModel.mostPlayed.contains(where: { $0.id == game.id }) ? .mostPlayed : .allGames
        }
        // Default to all games
        else {
            return .allGames
        }
    }

    private func saveStateItem(_ saveState: PVSaveState) -> some View {
        GameItemView(
            game: saveState.game,
            saveState: saveState,
            constrainHeight: true,
            isFocused: Binding(
                get: { focusedItemInSection == saveState.id },
                set: { if $0 { focusedItemInSection = saveState.id } }
            )
        ) {
            Task.detached { @MainActor in
                await rootDelegate?.root_load(saveState.game, sender: self, core: saveState.core, saveState: saveState)
            }
        }
        .id(saveState.id)
        .focusableIfAvailable()
    }

    private func sectionToId(_ section: HomeSectionType) -> String {
        switch section {
        case .recentSaveStates:
            return "section_continues"
        case .favorites:
            return "section_favorites"
        case .recentlyPlayedGames:
            return "section_recent"
        case .allGames:
            return "section_allgames"
        case .mostPlayed:
            return "section_mostplayed"
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
                         rootDelegate: nil)
    }
}

struct BiosesView: View {
    let console: PVSystem

    var body: some View {
        VStack {
            GamesDividerView()
            ForEach(console.bioses, id: \.self) { bios in
                BiosRowView(bios: bios.warmUp())
                GamesDividerView()
            }
        }
    }
}

#endif
