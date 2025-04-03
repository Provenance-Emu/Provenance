//
//  GameLibraryView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import PVUIBase
import PVLibrary
import PVRealm
import RealmSwift
import PVMediaCache
import UniformTypeIdentifiers
import PVLogging
import PVSystems
import Combine
import Dispatch
import PVLibrary
import Perception

struct GameLibraryView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sceneCoordinator: TestSceneCoordinator
    
    // Reference to the GameImporter for tracking import progress
    @ObservedObject private var gameImporter = GameImporter.shared
    
    // State to hold the import queue items
    @State private var importQueueItems: [ImportQueueItem] = []

    // Observed results for all games in the database with debouncing wrapper
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: "title", ascending: true)
    ) var allGames

    // Observed results for all systems in the database with debouncing wrapper
    @ObservedResults(
        PVSystem.self,
        sortDescriptor: SortDescriptor(keyPath: "name", ascending: true)
    ) var allSystems
    
    // IDs to force view stability and prevent flickering
    @State private var importQueueUpdateID = UUID()

    // Track expanded sections with AppStorage to persist between app runs
    @AppStorage("GameLibraryExpandedSections") private var expandedSectionsData: Data = Data()

    // State to track expanded sections during the current session
    @State private var expandedSections: Set<String> = []

    // Track search text
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var isSearching = false
    
    // Debouncing properties
    private let searchDebounceTime: TimeInterval = 0.3
    @State private var searchTextPublisher = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedViewMode: ViewMode = .grid
    @State private var showFilterSheet = false
    @State private var selectedSortOption: SortOption = .name
    
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
    @State internal var showArtworkSearch = false
    @State internal var showArtworkSourceAlert = false
    
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
    }
    
    // Create a computed binding that wraps the String as String?
    private var newGameTitleBinding: Binding<String?> {
        Binding<String?>(
            get: { self.newGameTitle },
            set: { self.newGameTitle = $0 ?? "" }
        )
    }

    // Enum for view modes
    enum ViewMode: String, CaseIterable, Identifiable {
        case grid, list
        var id: Self { self }

        var iconName: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    // Enum for sort options
    enum SortOption: String, CaseIterable, Identifiable {
        case name, recentlyPlayed, recentlyAdded
        var id: Self { self }

        var displayName: String {
            switch self {
            case .name: return "Name"
            case .recentlyPlayed: return "Recently Played"
            case .recentlyAdded: return "Recently Added"
            }
        }
    }

    var body: some View {
        mainContentView()
            .background(retroBackgroundView())
            .navigationTitle("GAME LIBRARY")
            .navigationBarTitleDisplayMode(.inline) // Changed to inline to avoid overlap
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                // Add a spacer with height that matches status bar
                Color.clear.frame(height: 0)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(onImport: importFiles)
            }
            .alert("Import Result", isPresented: $showingImportMessage, presenting: importMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onAppear {

                // Set up debouncing for search text
                searchTextPublisher
                    .debounce(for: .seconds(searchDebounceTime), scheduler: DispatchQueue.main)
                    .sink { value in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.debouncedSearchText = value
                        }
                    }
                    .store(in: &cancellables)
                

                // Set up timer to refresh the import queue status
                setupImportQueueRefreshTimer()
                
                // Load initial import queue items
                Task {
                    await refreshImportQueue()
                }
                
                loadExpandedSections()
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
                    initialSystem: nil
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
    }

    /// Main content view that displays either the empty state or the game library
    @ViewBuilder
    private func mainContentView() -> some View {
        ZStack {
            // Background that respects safe areas
            RetroTheme.retroBackground

            if allGames.isEmpty {
                emptyLibraryView()
            } else {
                libraryContentView()
            }
        }
    }

    /// Background view with retro aesthetics
    @ViewBuilder
    private func retroBackgroundView() -> some View {
        ZStack {
            // Base dark background with proper safe area handling
            RetroTheme.retroBlack.ignoresSafeArea(edges: [.horizontal, .bottom])

            // Grid lines (horizontal)
            VStack(spacing: 20) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(Color.retroBlue.opacity(0.2))
                        .frame(height: 1)
                }
            }

            // Grid lines (vertical)
            HStack(spacing: 20) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(Color.retroBlue.opacity(0.2))
                        .frame(width: 1)
                }
            }

            // Sunset gradient at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.retroSunsetGradient)
                    .frame(height: 150)
                    .offset(y: 70)
                    .blur(radius: 20)
            }
        }
    }

    /// Content view for the library when games are present
    @ViewBuilder
    private func libraryContentView() -> some View {
        VStack(spacing: 0) {
            // Custom search bar with increased top padding for status bar
            searchBar
                .padding(.horizontal)
                .padding(.top, 16)

            // View mode and filter controls
            libraryControlsView()

            Divider()
                .padding(.horizontal)
                
            WithPerceptionTracking {
                // Show import progress bar when there are active imports
                // Only show if there are items that aren't just failed items
                if !importQueueItems.isEmpty && importQueueItems.contains(where: { $0.status != .failure }) {
                    importProgressView()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .id(importQueueUpdateID) // Only redraw the import view when necessary
                }
            }
            // Games organized by system
            libraryScrollView()
        }
    }

    /// Controls for sorting and view mode
    @ViewBuilder
    private func libraryControlsView() -> some View {
        HStack(spacing: 12) {
            Text("\(filteredGames.count) Games")
                .font(.subheadline)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))

            Spacer()
            
            // Import button
            Button(action: {
                showingDocumentPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 14, weight: .bold))
                    Text("IMPORT")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.retroPink, lineWidth: 1.5)
                        )
                )
                .foregroundColor(.retroPink)
                .shadow(color: Color.retroPink.opacity(0.5), radius: 3, x: 0, y: 0)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Sort button
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button(action: {
                        selectedSortOption = option
                    }) {
                        HStack {
                            Text(option.displayName)
                            if selectedSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
            }

            // View mode toggle
            Menu {
                ForEach(ViewMode.allCases) { mode in
                    Button(action: {
                        withAnimation {
                            selectedViewMode = mode
                        }
                    }) {
                        HStack {
                            Text(mode.rawValue.capitalized)
                            if selectedViewMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: selectedViewMode.iconName)
                    .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Main scroll view containing all game sections
    @ViewBuilder
    private func libraryScrollView() -> some View {
        ScrollView {
            // Use this ID to prevent unnecessary redraws when only search text changes
            // Only include the database update ID to stabilize during database changes
            // Don't include the import queue update ID to avoid redrawing the entire library
            let viewID = "library-\(debouncedSearchText.isEmpty ? "all" : "search")"
            
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Content is identified by the search state to prevent flickering
                if debouncedSearchText.isEmpty {
                    // All Games section
                    allGamesSection()

                    // Divider between All Games and systems
                    Divider()
                        .padding(.horizontal)

                    // Individual system sections
                    systemSections()
                } else {
                    // Search results
                    searchResultsView()
                }
            }
            .id(viewID) // Stabilize view with ID
            .padding()
        }
    }

    /// Section displaying all games
    @ViewBuilder
    private func allGamesSection() -> some View {
        Section {
            if expandedSections.contains("all") {
                if selectedViewMode == .grid {
                    systemGamesGrid(games: sortedGames(Array(allGames)))
                } else {
                    systemGamesList(games: sortedGames(Array(allGames)))
                }
            }
        } header: {
            sectionHeader(title: "All Games", count: allGames.count, systemId: "all")
        }
        .padding(.bottom, 8)
    }

    /// Sections for individual systems
    @ViewBuilder
    private func systemSections() -> some View {
        ForEach(allSystems, id: \.self) { system in
            let systemGames = gamesForSystem(system)
            if !systemGames.isEmpty {
                Section {
                    if expandedSections.contains(system.systemIdentifier.rawValue) {
                        if selectedViewMode == .grid {
                            systemGamesGrid(games: sortedGames(systemGames))
                        } else {
                            systemGamesList(games: sortedGames(systemGames))
                        }
                    }
                } header: {
                    sectionHeader(
                        title: system.name,
                        subtitle: system.shortName,
                        count: systemGames.count,
                        systemId: system.systemIdentifier.rawValue
                    )
                }
            }
        }
    }

    /// View displaying search results
    @ViewBuilder
    private func searchResultsView() -> some View {
        if filteredGames.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5))

                Text("No games found matching '\(debouncedSearchText)'")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            if selectedViewMode == .grid {
                systemGamesGrid(games: filteredGames)
            } else {
                systemGamesList(games: filteredGames)
            }
        }
    }

    @State private var showingDocumentPicker = false
    @State private var importMessage: String? = nil
    @State private var showingImportMessage = false

    // Empty library view
    @ViewBuilder
    private func emptyLibraryView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5))

            Text("No Games Found")
                .font(.title)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

            Text("Add games to your library to get started")
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Games")
                }
                .padding()
                .background(Color(themeManager.currentPalette.defaultTintColor))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
    }

    /// Function to refresh the import queue items
    private func refreshImportQueue() async {
        let queue = await gameImporter.importQueue
        await MainActor.run {
            self.importQueueItems = queue
        }
    }
    
    private func importFiles(urls: [URL]) {
        ILOG("GameLibraryView: Importing \(urls.count) files")

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ELOG("GameLibraryView: Could not access documents directory")
            importMessage = "Error: Could not access documents directory"
            showingImportMessage = true
            return
        }

        let importsDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)

        // Create Imports directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("GameLibraryView: Error creating Imports directory: \(error.localizedDescription)")
            importMessage = "Error creating Imports directory: \(error.localizedDescription)"
            showingImportMessage = true
            return
        }

        var successCount = 0
        var errorMessages = [String]()

        for url in urls {
            let destinationURL = importsDirectory.appendingPathComponent(url.lastPathComponent)

            do {
                // If file already exists, remove it first
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Copy file to Imports directory
                try FileManager.default.copyItem(at: url, to: destinationURL)
                ILOG("GameLibraryView: Successfully copied \(url.lastPathComponent) to Imports directory")
                successCount += 1
            } catch {
                ELOG("GameLibraryView: Error copying file \(url.lastPathComponent): \(error.localizedDescription)")
                errorMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Prepare result message
        if successCount == urls.count {
            importMessage = "Successfully imported \(successCount) file(s). The game importer will process them shortly."
        } else if successCount > 0 {
            importMessage = "Imported \(successCount) of \(urls.count) file(s). Some files could not be imported."
        } else {
            importMessage = "Failed to import any files. \(errorMessages.first ?? "Unknown error")"
        }

        showingImportMessage = true
    }

    // Launch game
    private func launchGame(_ game: PVGame) {
        ILOG("GameLibraryView: Launching game: \(game.title) (ID: \(game.id))")

        // Use the TestSceneCoordinator to launch the game
        sceneCoordinator.launchGame(game)
    }
}

// MARK: - GameContextMenuDelegate

extension GameLibraryView {
    /// Sort games based on the selected sort option
    private func sortedGames(_ games: [PVGame]) -> [PVGame] {
        switch selectedSortOption {
        case .name:
            return games.sorted(by: { $0.title < $1.title })
        case .recentlyPlayed:
            // This would ideally use a lastPlayed date property
            // For now, just return alphabetically sorted
            return games.sorted(by: { $0.title < $1.title })
        case .recentlyAdded:
            return games.sorted(by: { $0.importDate > $1.importDate })
        }
    }
}

extension GameLibraryView: GameContextMenuDelegate {
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
//                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
//                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if newGameTitle.isEmpty {
//            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        showingRenameAlert = false
        gameToRename = nil
    }

    // MARK: - Image Picker Methods

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    internal func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID: String = UUID().uuidString
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
//            rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

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
//            rootDelegate?.showMessage("Failed to set custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
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

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
//        showGameInfo(gameId)
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
        // gamesViewModel.presentDiscSelectionAlert(for: game, rootDelegate: rootDelegate)
    }
}

// MARK: - System Section Helpers

extension GameLibraryView {
    // MARK: - Computed Properties

    /// Filtered games based on search text
    private var filteredGames: [PVGame] {
        guard !debouncedSearchText.isEmpty else { return Array(allGames) }

        return allGames.filter { game in
            game.title.lowercased().contains(debouncedSearchText.lowercased())
        }
    }
    
    /// Import progress view with retrowave styling
    @ViewBuilder
    private func importProgressView() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WithPerceptionTracking {
                // Header with count of imports
                HStack {
                    Text("IMPORTING \(importQueueItems.count) FILES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.retroBlue)
                    
                    Spacer()
                    
                    // Show processing status if any item is processing
                    if importQueueItems.contains(where: { $0.status == .processing }) {
                        Text("PROCESSING")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.retroPink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.retroBlack.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(Color.retroPink, lineWidth: 1)
                                    )
                            )
                    }
                }
                
                // Progress bar with retrowave styling
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.retroBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(height: 12)
                    
                    // Progress fill - count both completed and failed items for progress
                    let processedCount = importQueueItems.filter { $0.status == .success || $0.status == .failure }.count
                    let progress = importQueueItems.isEmpty ? 0.0 : Double(processedCount) / Double(importQueueItems.count)
                    
                    // Create a GeometryReader to get the actual width of the container
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        // Calculate width as a percentage of the available width
                        // Use max to ensure a minimum visible width
                        .frame(width: max(12, progress * geometry.size.width), height: 8)
                        .cornerRadius(4)
                        .padding(2)
                    }
                    // Set a fixed height for the GeometryReader
                    .frame(height: 12)
                }
                
                // Status details
                HStack(spacing: 12) {
                    statusCountView(count: importQueueItems.filter { $0.status == .queued }.count, label: "QUEUED", color: .gray)
                    statusCountView(count: importQueueItems.filter { $0.status == .processing }.count, label: "PROCESSING", color: .retroBlue)
                    statusCountView(count: importQueueItems.filter { $0.status == .success }.count, label: "COMPLETED", color: .retroYellow)
                    statusCountView(count: importQueueItems.filter { $0.status == .failure }.count, label: "FAILED", color: .retroPink)
                    
                    Spacer()
                }
            }
        }
        .padding(12)
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
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }
    
    /// Helper view for status counts
    @ViewBuilder
    private func statusCountView(count: Int, label: String, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
            }
        }
    }
    

    
    /// Set up a timer to refresh the import queue status
    private func setupImportQueueRefreshTimer() {
        // Create a timer that updates the UI every 0.5 seconds when imports are active
        Timer.publish(every: 1.0, on: .main, in: .common) // Reduced frequency to 1 second
            .autoconnect()
            .sink { _ in
                // Only trigger UI updates if there are active imports
                Task {
                    // Get the current import queue
                    let queue = await self.gameImporter.importQueue
                    
                    // Only update if the queue has changed
                    if self.importQueueItems != queue {
                        // Update the state on the main thread
                        await MainActor.run {
                            self.importQueueItems = queue
                            
                            // Only trigger UI updates if there are active imports
                            // Use a separate ID for import queue updates to avoid redrawing the entire view
                            if !queue.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.importQueueUpdateID = UUID()
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Custom search bar view
    private var searchBar: some View {
        customSearchBar()
    }

    /// Creates a custom search bar
    @ViewBuilder
    private func customSearchBar() -> some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearching ? themeManager.currentPalette.defaultTintColor.swiftUIColor : .gray)
                    .animation(.easeInOut(duration: 0.2), value: isSearching)

                TextField("Search Games", text: $searchText, onEditingChanged: { editing in
                    withAnimation {
                        isSearching = editing
                    }
                })
                .onChange(of: searchText) { newValue in
                    searchTextPublisher.send(newValue)
                }
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.retroPink, lineWidth: 1.5)
                    )
            )
        }
    }

    /// Get games for a specific system
    private func gamesForSystem(_ system: PVSystem) -> [PVGame] {
        return Array(system.games.sorted(by: { $0.title < $1.title }))
    }

    /// Load expanded sections from AppStorage
    private func loadExpandedSections() {
        // If no data is stored yet, expand all sections by default
        if expandedSectionsData.isEmpty {
            expandedSections = Set(allSystems.map { $0.systemIdentifier.rawValue })
            return
        }

        // Otherwise, load from AppStorage
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: expandedSectionsData) {
            expandedSections = decoded
        } else {
            // Fallback to all expanded if there's an error
            expandedSections = Set(allSystems.map { $0.systemIdentifier.rawValue })
        }
    }

    /// Toggle the expanded state of a section
    private func toggleSection(_ systemId: String) {
        // Use slightly longer animation to reduce perceived flickering
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSections.contains(systemId) {
                expandedSections.remove(systemId)
            } else {
                expandedSections.insert(systemId)
            }

            // Save to AppStorage
            saveExpandedSections()
        }
    }

    /// Save expanded sections to AppStorage
    private func saveExpandedSections() {
        if let encoded = try? JSONEncoder().encode(expandedSections) {
            expandedSectionsData = encoded
        }
    }

    /// Creates a collapsible section header for a system
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String? = nil, count: Int, systemId: String) -> some View {
        Button(action: {
            toggleSection(systemId)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(Color.retroBlue)
                            .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    }
                }

                Spacer()

                Text("\(count)")
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

                    Image(systemName: expandedSections.contains(systemId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.2), value: expandedSections.contains(systemId))
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
        .buttonStyle(PlainButtonStyle())
    }

    /// Creates a grid of games for a system
    @ViewBuilder
    private func systemGamesGrid(games: [PVGame]) -> some View {
        // Use stable ID to prevent unnecessary redraws
        let gridID = "grid-\(debouncedSearchText)-\(games.count)"
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
            ForEach(games, id: \.self) { game in
                gameGridItem(game: game)
            }
        }
    }

    /// Creates a single game grid item
    @ViewBuilder
    private func gameGridItem(game: PVGame) -> some View {
        // Use ID to stabilize view and prevent unnecessary redraws
        let gameID = "grid-item-\(game.id)"
        
        GameItemView(
            game: game,
            constrainHeight: false,
            viewType: .cell,
            sectionContext: .allGames,
            isFocused: .constant(false)
        ) {
            // Launch game action
            launchGame(game)
        }
        .contextMenu {
            GameContextMenu(
                game: game,
                rootDelegate: nil,
                contextMenuDelegate: self
            )
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .id(gameID)
    }

    /// Creates a list of games for a system
    @ViewBuilder
    private func systemGamesList(games: [PVGame]) -> some View {
        // Use stable ID to prevent unnecessary redraws
        let listID = "list-\(debouncedSearchText)-\(games.count)"
        
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
                gameListItem(game: game)
            }
        }
        .id(listID)
    }

    /// Creates a single game list item
    @ViewBuilder
    private func gameListItem(game: PVGame) -> some View {
        // Use ID to stabilize view and prevent unnecessary redraws
        let gameID = "list-item-\(game.id)"
        
        HStack(spacing: 12) {
            // Game cover image
            GameItemView(
                game: game,
                constrainHeight: true,
                viewType: .row,
                sectionContext: .allGames,
                isFocused: .constant(false)
            ) {
                // Empty action as we'll handle it in the parent HStack
            }
            .frame(width: 60, height: 60)

            // Game details
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title.uppercased())
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(Color.retroYellow)
                    .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    .lineLimit(1)

                if let system = game.system {
                    Text(system.shortName.uppercased())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color.retroBlue)
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 0, y: 0)
                }
            }

            Spacer()

            // Play button
            Button(action: {
                launchGame(game)
            }) {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .contextMenu {
            GameContextMenu(
                game: game,
                rootDelegate: nil,
                contextMenuDelegate: self
            )
        }
    }
}

internal struct SystemMoveState: Identifiable {
    var id: String {
        guard !game.isInvalidated else { return "" }
        return game.id
    }
    let game: PVGame
    var isPresenting: Bool = true
}

internal struct ContinuesManagementState: Identifiable {
    var id: String {
        guard !game.isInvalidated else { return "" }
        return game.id
    }
    let game: PVGame
    var isPresenting: Bool = true
}
