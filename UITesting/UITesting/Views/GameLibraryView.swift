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
        
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if allGames.isEmpty {
                    emptyLibraryView()
                } else {
                    // Games organized by system
                    ScrollView {
                        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                            // All Games section that's always visible
                            Section {
                                systemGamesGrid(games: Array(allGames))
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
                                            systemGamesGrid(games: systemGames)
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
                        .padding()
                    }
                }
            }
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
            .navigationTitle("Game Library")
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
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(themeManager.currentPalette.defaultTintColor.swiftUIColor.opacity(0.2))
                    .cornerRadius(8)
                
                if systemId != "all" {
                    Image(systemName: expandedSections.contains(systemId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(.system(size: 14, weight: .bold))
                        .animation(.easeInOut(duration: 0.2), value: expandedSections.contains(systemId))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
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


