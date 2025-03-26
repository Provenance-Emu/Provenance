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

struct GameLibraryView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    
    // Observed results for all games in the database
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: "title", ascending: true)
    ) var allGames
        
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if allGames.isEmpty {
                    emptyLibraryView()
                } else {
                    // Games grid
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                            ForEach(allGames, id: \.self) { game in
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
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
            .navigationTitle("Game Library")
        }
    }
    
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
                // Action to add games
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
    
    // Launch game
    private func launchGame(_ game: PVGame) {
        ILOG("GameLibraryView: Launching game: \(game.title) (ID: \(game.id))")
        
        // Set the current game in EmulationUIState
        appState.emulationUIState.currentGame = game
        
        // Verify the game was set correctly
        if let currentGame = appState.emulationUIState.currentGame {
            ILOG("GameLibraryView: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
        } else {
            ELOG("GameLibraryView: Failed to set current game in EmulationUIState")
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
