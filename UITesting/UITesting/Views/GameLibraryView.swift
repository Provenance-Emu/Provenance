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

// Retrowave color extension
extension Color {
    static let retroPink = Color(red: 0.98, green: 0.2, blue: 0.6)
    static let retroPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
    static let retroBlue = Color(red: 0.0, green: 0.8, blue: 0.95)
    static let retroYellow = Color(red: 0.98, green: 0.84, blue: 0.2)
    static let retroBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    // Gradient helpers
    static let retroGradient = LinearGradient(
        gradient: Gradient(colors: [.retroPurple, .retroPink]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let retroSunsetGradient = LinearGradient(
        gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
        startPoint: .top,
        endPoint: .bottom
    )
}

struct GameLibraryView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sceneCoordinator: TestSceneCoordinator
    
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
    
    // State to track expanded sections during the current session
    @State private var expandedSections: Set<String> = []
    
    // Track search text
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedViewMode: ViewMode = .grid
    @State private var showFilterSheet = false
    @State private var selectedSortOption: SortOption = .name
    
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
        NavigationStack {
            ZStack {
                themeManager.currentPalette.gameLibraryBackground.swiftUIColor.ignoresSafeArea()
                
                if allGames.isEmpty {
                    emptyLibraryView()
                } else {
                    VStack(spacing: 0) {
                        // Custom search bar
                        searchBar
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // View mode and filter controls
                        HStack {
                            Text("\(filteredGames.count) Games")
                                .font(.subheadline)
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                            
                            Spacer()
                            
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
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Games organized by system
                        ScrollView {
                            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                                // All Games section that's always visible
                                if searchText.isEmpty {
                                    Section {
                                        if selectedViewMode == .grid {
                                            systemGamesGrid(games: sortedGames(Array(allGames)))
                                        } else {
                                            systemGamesList(games: sortedGames(Array(allGames)))
                                        }
                                    } header: {
                                        sectionHeader(title: "All Games", count: allGames.count, systemId: "all")
                                    }
                                    .padding(.bottom, 8)
                                    
                                    // Divider between All Games and systems
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    // Individual system sections
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
                                } else {
                                    // Search results
                                    if filteredGames.isEmpty {
                                        VStack(spacing: 20) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 40))
                                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5))
                                            
                                            Text("No games found matching '\(searchText)'")
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
                            }
                            .padding()
                        }
                    }
                }
            }
            .background(
                ZStack {
                    // Base dark background
                    Color.retroBlack.ignoresSafeArea()
                    
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
            )
            .navigationTitle("GAME LIBRARY")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                loadExpandedSections()
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
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        ILOG("GameLibraryView: Rename requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        ILOG("GameLibraryView: Choose cover requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        ILOG("GameLibraryView: Move to system requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        ILOG("GameLibraryView: Show save states requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        ILOG("GameLibraryView: Show game info requested for game ID: \(gameId)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        ILOG("GameLibraryView: Show image picker requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        ILOG("GameLibraryView: Show artwork search requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        ILOG("GameLibraryView: Choose artwork source requested for game: \(game.title)")
    }
    
    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        ILOG("GameLibraryView: Disc selection requested for game: \(game.title)")
    }
}

// MARK: - System Section Helpers

extension GameLibraryView {
    // MARK: - Computed Properties
    
    /// Filtered games based on search text
    private var filteredGames: [PVGame] {
        guard !searchText.isEmpty else { return Array(allGames) }
        
        return allGames.filter { game in
            game.title.lowercased().contains(searchText.lowercased())
        }
    }
    
    /// Custom search bar view
    private var searchBar: some View {
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
        // Don't allow collapsing the All Games section
        if systemId == "all" { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
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
                
                if systemId != "all" {
                    Image(systemName: expandedSections.contains(systemId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 24, height: 24)
                        .animation(.easeInOut(duration: 0.2), value: expandedSections.contains(systemId))
                }
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
    private func systemGamesGrid(games: [PVGame]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
            ForEach(games, id: \.self) { game in
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
            }
        }
    }
    
    /// Creates a list of games for a system
    private func systemGamesList(games: [PVGame]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.self) { game in
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
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
            
            TextField("Search games...", text: $text)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                }
            }
        }
        .padding(8)
        .background(themeManager.currentPalette.gameLibraryCellBackground?.swiftUIColor.opacity(0.3) ?? Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}


