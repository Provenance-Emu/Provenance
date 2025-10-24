//
//  RetroGameGridView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVRealm
import RealmSwift
import PVLibrary
import PVLogging

public struct RetroGameGridView: View {
    @EnvironmentObject var realmEnvironment: RealmEnvironment
    @ObservedResults(PVGame.self) var games

    // State for tracking focused game
    @State private var focusedGameID: String? = nil

    // Callback for when a game is selected
    var onGameSelected: ((PVGame) -> Void)?

    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    public var body: some View {
        VStack {
            if games.isEmpty {
                emptyStateView
            } else {
                gameGridContent
            }
        }
        .navigationTitle("Games")
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var emptyStateView: some View {
        Text("No games found in database")
            .font(.headline)
            .foregroundColor(.gray)
            .padding()
    }
    
    @ViewBuilder
    private var gameGridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(games) { game in
                    if !game.isInvalidated {
                        gameItemView(for: game)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func gameItemView(for game: PVGame) -> some View {
        // Create a simple wrapper view to avoid GameItemView initialization issues
        RetroGameCellWrapper(game: game, isSelected: focusedGameID == game.id) { selectedGame in
            focusedGameID = selectedGame.id
            launchGame(selectedGame)
        }
        .frame(height: 220)
    }

    private func launchGame(_ game: PVGame) {
        ILOG("RetroGameGridView: Selected game: \(game.title)")
        ILOG("RetroGameGridView: Game ID: \(game.id)")
        ILOG("RetroGameGridView: System: \(game.system?.name ?? "Unknown")")
        ILOG("RetroGameGridView: Core: \(game.userPreferredCoreID ?? game.system?.userPreferredCore ?? "Unknown")")

        // Call the callback if provided
        if let onGameSelected = onGameSelected {
            onGameSelected(game)
        } else {
            ILOG("RetroGameGridView: No game selection handler provided")
        }
    }
}

#if DEBUG
#Preview {
    RetroGameGridView()
        .environmentObject(RealmEnvironment())
}
#endif
