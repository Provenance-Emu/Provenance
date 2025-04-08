//
//  RetroGameLibraryView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVThemes
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

// ViewModel is defined in RetroGameLibraryViewModel.swift

public struct RetroGameLibraryView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    
    // State for document picker presentation
    @State private var isShowingDocumentPicker = false
    
    // MARK: - ViewModel
    @StateObject private var viewModel = RetroGameLibraryViewModel()
    
    // Observed results for all games in the database
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: "title", ascending: true)
    ) var allGames
    
    // Observed results for all systems in the database
    @ObservedResults(
        PVSystem.self,
        sortDescriptor: SortDescriptor(keyPath: "name", ascending: true)
    ) var allSystems
    
    // Track expanded sections with AppStorage to persist between app runs
    @AppStorage("GameLibraryExpandedSections") private var expandedSectionsData: Data = Data()
    
    // Focus state for rename field
    @FocusState internal var renameTitleFieldIsFocused: Bool
    
    public init () {
        
    }
    
    // Create a computed binding that wraps the String as String?
    private var newGameTitleBinding: Binding<String?> {
        Binding<String?>(
            get: { self.viewModel.newGameTitle },
            set: { self.viewModel.newGameTitle = $0 ?? "" }
        )
    }
    
    public var body: some View {
        // Main content
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
                        /// Show the document picker directly using local state
                        /// This simplifies the implementation and avoids environment object issues
                        isShowingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        /// Use a sheet modifier with local state for document picker
            .sheet(isPresented: $isShowingDocumentPicker) {
                /// When the sheet is dismissed, log for debugging
                VLOG("RetroGameLibraryView: Document picker sheet dismissed")
            } content: {
                /// Present the DocumentPicker directly with the importFiles callback
                DocumentPicker(onImport: importFiles)
            }
            .retroAlert("Import Result",
                        message: viewModel.importMessage ?? "",
                        isPresented: $viewModel.showingImportMessage) {
                Button("OK", role: .cancel) {}
            }
        .onAppear {
            // Load expanded sections from AppStorage
            viewModel.loadExpandedSections(from: expandedSectionsData, allSystems: Array(allSystems))
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
#if !os(tvOS)
            ImagePicker(sourceType: .photoLibrary) { image in
                if let game = viewModel.gameToUpdateCover {
                    viewModel.saveArtwork(image: image, forGame: game)
                }
                viewModel.showImagePicker = false
                viewModel.gameToUpdateCover = nil
            }
#endif
        }
        .fullScreenCover(isPresented: $viewModel.showArtworkSearch) {
            ArtworkSearchView(
                initialSearch: viewModel.gameToUpdateCover?.title ?? "",
                initialSystem: viewModel.gameToUpdateCover?.system?.enumValue ?? SystemIdentifier.Unknown
            ) { selection in
                if let game = viewModel.gameToUpdateCover {
                    Task {
                        do {
                            // Load image data from URL
                            let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                            if let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    viewModel.saveArtwork(image: uiImage, forGame: game)
                                    viewModel.showArtworkSearch = false
                                    viewModel.gameToUpdateCover = nil
                                }
                            }
                        } catch {
                            DLOG("Failed to load artwork image: \(error)")
                        }
                    }
                }
            }
        }
        .retroAlert(
            "Rename Game",
            message: "Enter a new name for \(viewModel.gameToRename?.title ?? "")",
            isPresented: $viewModel.showingRenameAlert,
            textFieldBinding: newGameTitleBinding,
            textFieldConfiguration: { textField in
                textField.placeholder = "Game name"
                textField.clearButtonMode = .whileEditing
                textField.autocapitalizationType = .words
            }
        ) {
            VStack(spacing: 10) {
                RetroButton(title: "Save", isPrimary: true) {
                    if let game = viewModel.gameToRename, !viewModel.newGameTitle.isEmpty {
                        Task {
                            await viewModel.renameGame(game, to: viewModel.newGameTitle)
                            viewModel.gameToRename = nil
                            viewModel.newGameTitle = ""
                            viewModel.showingRenameAlert = false
                        }
                    }
                }
                
                RetroButton(title: "Cancel", isPrimary: false) {
                    viewModel.gameToRename = nil
                    viewModel.newGameTitle = ""
                    viewModel.showingRenameAlert = false
                }
            }
        }
        .sheet(item: $viewModel.systemMoveState) { state in
            SystemPickerView(
                game: state.game,
                isPresented: Binding(
                    get: { state.isPresenting },
                    set: { newValue in
                        if !newValue {
                            viewModel.systemMoveState = nil
                        }
                    }
                )
            )
        }
//            .fullScreenCover(item: $viewModel.continuesManagementState) { state in
//                let driver = RealmSaveStateDriver()
//                // Load save states for the specific game
//                driver.loadSaveStates(forGameId: state.game.id)
//
//                /// Create view model with mock driver
//                let viewModel = ContinuesMagementViewModel(
//                    driver: driver,
//                    gameTitle: driver.gameTitle,
//                    systemTitle: driver.systemTitle,
//                    numberOfSaves: driver.getAllSaveStates().count,
//                    gameUIImage: driver.gameUIImage,
//                    onLoadSave: { id in
//                        ILOG("load save \(id)")
//                    }
//                )
//
//                ContinuesManagementView(viewModel: viewModel)
//            }
        .retroAlert(
            "Choose Artwork Source",
            message: "Select artwork from your photo library or search online sources",
            isPresented: $viewModel.showArtworkSourceAlert
        ) {
            VStack(spacing: 10) {
                RetroButton(title: "Select from Photos", isPrimary: true) {
                    viewModel.showArtworkSourceAlert = false
                    viewModel.showImagePicker = true
                }
                
                RetroButton(title: "Search Online", isPrimary: true) {
                    let game = viewModel.gameToUpdateCover  // Preserve the game reference
                    viewModel.showArtworkSourceAlert = false
                    viewModel.gameToUpdateCover = game
                    viewModel.showArtworkSearch = true
                }
                
                RetroButton(title: NSLocalizedString("Cancel", comment: "Cancel"), isPrimary: false) {
                    viewModel.showArtworkSourceAlert = false
                }
            }
        }
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
            
            // Import progress view - now using the improved ImportProgressView
            importProgressView()
                .padding(.horizontal)
                .padding(.vertical, 8)
            
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
                isShowingDocumentPicker = true
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
                ForEach(SortOptions.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.selectedSortOption = option
                    }) {
                        HStack {
                            Text(option.description)
                            if viewModel.selectedSortOption == option {
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
                            viewModel.selectedViewMode = mode
                        }
                    }) {
                        HStack {
                            Text(mode.rawValue.capitalized)
                            if viewModel.selectedViewMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: viewModel.selectedViewMode.iconName)
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
            let viewID = "library-\(viewModel.debouncedSearchText.isEmpty ? "all" : "search")"
            
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Content is identified by the search state to prevent flickering
                if viewModel.debouncedSearchText.isEmpty {
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
        SwiftUI.Section {
            if viewModel.expandedSections.contains("all") {
                if viewModel.selectedViewMode == .grid {
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
                SwiftUI.Section {
                    if viewModel.expandedSections.contains(system.systemIdentifier.rawValue) {
                        if viewModel.selectedViewMode == .grid {
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
                
                Text("No games found matching '\(viewModel.debouncedSearchText)'")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            if viewModel.selectedViewMode == .grid {
                systemGamesGrid(games: filteredGames)
            } else {
                systemGamesList(games: filteredGames)
            }
        }
    }
    
    // Empty library view
    /// A retrowave-styled empty library view with VHS effect
    @ViewBuilder
    private func emptyLibraryView() -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.retroDarkBlue, Color.retroBlack]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // Grid pattern
            RetroGridPattern()
                .opacity(0.3)
            
            // VHS static effect overlay
            VHSStaticEffect()
                .opacity(0.1)
            
            // Main content
            VStack(spacing: 30) {
                // Retrowave title with glowing effect
                RetroGlowText("NO GAMES FOUND", fontSize: 32)
                    .padding(.top, 20)
                
                // Arcade controller icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.retroPink)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.retroBlue)
                            .offset(x: 2, y: 2)
                            .opacity(0.7)
                            .blendMode(.screen)
                    )
                    .shadow(color: .retroPink.opacity(0.8), radius: 15, x: 0, y: 0)
                    .padding(.bottom, 10)
                
                // Subtitle with scanline effect
                Text("INSERT GAMES TO CONTINUE")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.retroBlack.opacity(0.5))
                    .overlay(RetroScanlineEffect())
                
                // Add games button with retrowave styling
                Button(action: {
                    isShowingDocumentPicker = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 18))
                        Text("ADD GAMES")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .cornerRadius(8)
                    .shadow(color: .retroBlue.opacity(0.7), radius: 10, x: 0, y: 0)
                }
                .padding(.top, 20)
                
                // VHS tracking line
                RetroTrackingLine()
                    .frame(height: 4)
                    .padding(.top, 40)
            }
            .padding(30)
        }
    }
    
    /// Function to refresh the import queue items
    // Import queue refresh is now handled by ImportProgressView
    
    private func importFiles(urls: [URL]) {
        ILOG("RetroGameLibraryView: Importing \(urls.count) files")
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ELOG("RetroGameLibraryView: Could not access documents directory")
            viewModel.importMessage = "Error: Could not access documents directory"
            viewModel.showingImportMessage = true
            return
        }
        
        let importsDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)
        
        // Create Imports directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("RetroGameLibraryView: Error creating Imports directory: \(error.localizedDescription)")
            viewModel.importMessage = "Error creating Imports directory: \(error.localizedDescription)"
            viewModel.showingImportMessage = true
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
                ILOG("RetroGameLibraryView: Successfully copied \(url.lastPathComponent) to Imports directory")
                successCount += 1
            } catch {
                ELOG("RetroGameLibraryView: Error copying file \(url.lastPathComponent): \(error.localizedDescription)")
                errorMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Prepare result message
        if successCount == urls.count {
            viewModel.importMessage = "Successfully imported \(successCount) file(s). The game importer will process them shortly."
        } else if successCount > 0 {
            viewModel.importMessage = "Imported \(successCount) of \(urls.count) file(s). Some files could not be imported."
        } else {
            viewModel.importMessage = "Failed to import any files. \(errorMessages.first ?? "Unknown error")"
        }
        
        viewModel.showingImportMessage = true
    }
    
    // Launch game
    private func launchGame(_ game: PVGame) {
        ILOG("RetroGameLibraryView: Launching game: \(game.title) (ID: \(game.id))")
        
        // Use the SceneCoordinator to launch the game
        sceneCoordinator.launchGame(game)
    }
}

// MARK: - GameContextMenuDelegate

extension RetroGameLibraryView {
    /// Sort games based on the selected sort option
    private func sortedGames(_ games: [PVGame]) -> [PVGame] {
        switch viewModel.selectedSortOption {
        case .title:
            return games.sorted(by: { $0.title < $1.title })
        case .lastPlayed:
            // This would ideally use a lastPlayed date property
            // For now, just return alphabetically sorted
            return games.sorted(by: { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) })
        case .importDate:
            return games.sorted(by: { $0.importDate > $1.importDate })
        case .mostPlayed:
            return games.sorted(by: { $0.playCount > $1.playCount })
        }
    }
}

extension RetroGameLibraryView: GameContextMenuDelegate {
#if !os(tvOS)
    @ViewBuilder
    internal func imagePickerView() -> some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = viewModel.gameToUpdateCover {
                viewModel.saveArtwork(image: image, forGame: game)
            }
            viewModel.gameToUpdateCover = nil
            viewModel.showImagePicker = false
        }
    }
#endif
    
    // MARK: - Rename Methods
    public func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        viewModel.gameToRename = game.freeze()
        viewModel.newGameTitle = game.title
        viewModel.showingRenameAlert = true
    }
    
    private func submitRename() {
        if !viewModel.newGameTitle.isEmpty, let frozenGame = viewModel.gameToRename, viewModel.newGameTitle != frozenGame.title {
            do {
                guard let thawedGame = frozenGame.thaw() else {
                    throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to thaw game object"])
                }
                RomDatabase.sharedInstance.renameGame(thawedGame, toTitle: viewModel.newGameTitle)
                //                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
                //                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if viewModel.newGameTitle.isEmpty {
            //            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        viewModel.showingRenameAlert = false
        viewModel.gameToRename = nil
    }
    
    // MARK: - Image Picker Methods
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showImagePicker = true
    }
    
    // saveArtwork method has been moved to the ViewModel
    private func availableSystems(forGame game: PVGame) -> [PVSystem] {
        PVEmulatorConfiguration.systems.filter {
            $0.identifier != game.systemIdentifier &&
            !(AppState.shared.isAppStore && $0.appStoreDisabled && !Defaults[.unsupportedCores])
        }
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("RetroGameLibraryView: Received request to move game to system")
        let frozenGame = game.isFrozen ? game : game.freeze()
        viewModel.systemMoveState = RetroGameLibrarySystemMoveState(game: frozenGame, availableSystems: availableSystems(forGame: frozenGame))
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("RetroGameLibraryView: Received request to show save states for game")
        viewModel.continuesManagementState = RetroGameLibraryContinuesManagementState(game: game)
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        /// Show the GameMoreInfoView for the selected game
        DLOG("RetroGameLibraryView: Showing game info for game ID: \(gameId)")
        
        /// Delegate to the ViewModel to handle showing the game info
        /// This ensures proper state management and consistent presentation
        viewModel.showGameInfo(gameId: gameId, appState: appState)
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showImagePicker = true
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showArtworkSearch = true
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("Setting gameToUpdateCover with game: \(game.title)")
        viewModel.gameToUpdateCover = game
        viewModel.showArtworkSourceAlert = true
    }
    
    public func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        // gamesViewModel.presentDiscSelectionAlert(for: game, rootDelegate: rootDelegate)
    }
}

// MARK: - System Section Helpers

extension RetroGameLibraryView {
    // MARK: - Computed Properties
    
    /// Filtered games based on search text
    private var filteredGames: [PVGame] {
        viewModel.filteredGames
    }
    
    /// Import progress view with retrowave styling
    @ViewBuilder
    private func importProgressView() -> some View {
        ImportProgressView(
            gameImporter: viewModel.gameImporter,
            updatesController: AppState.shared.libraryUpdatesController!,
            onTap: {
                viewModel.showImportStatusView = true
            }
        )
        .sheet(isPresented: $viewModel.showImportStatusView) {
            ImportStatusView(
                updatesController: AppState.shared.libraryUpdatesController!,
                gameImporter: viewModel.gameImporter,
                dismissAction: {
                    viewModel.showImportStatusView = false
                }
            )
        }
    }
    // statusCountView has been moved to ImportProgressView
    
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
                    .foregroundColor(viewModel.isSearching ? themeManager.currentPalette.defaultTintColor.swiftUIColor : .gray)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isSearching)
                
                TextField("Search Games", text: $viewModel.searchText, onEditingChanged: { editing in
                    withAnimation {
                        viewModel.isSearching = editing
                    }
                })
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
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
    
    /// Creates a collapsible section header for a system
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String? = nil, count: Int, systemId: String) -> some View {
        Button(action: {
            viewModel.toggleSection(systemId)
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
                
                Image(systemName: viewModel.expandedSections.contains(systemId) ? "chevron.up" : "chevron.down")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 24, height: 24)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.expandedSections.contains(systemId))
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
        let gridID = "grid-\(viewModel.debouncedSearchText)-\(games.count)"
        
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
        //        let listID = "list-\(viewModel.debouncedSearchText)-\(games.count)"
        
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
                gameListItem(game: game)
            }
        }
        //        .id(listID)
    }
    
    /// Creates a single game list item
    @ViewBuilder
    private func gameListItem(game: PVGame) -> some View {
        // Use ID to stabilize view and prevent unnecessary redraws
        let gameID = "list-item-\(game.id)"
        GameItemView(
            game: game,
            constrainHeight: true,
            viewType: .row,
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
}
