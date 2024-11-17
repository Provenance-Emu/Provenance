//
//  ConsoleGamesView+GamepadNavigation.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

/// Gamepad navigation
extension ConsoleGamesView {
    
    internal var availableSections: [HomeSectionType] {
        [
            (showRecentSaveStates && !gamesViewModel.recentSaveStates.isEmpty) ? .recentSaveStates : nil,
            (showFavorites && !gamesViewModel.favorites.isEmpty) ? .favorites : nil,
            (showRecentGames && !gamesViewModel.recentlyPlayedGames.isEmpty) ? .recentlyPlayedGames : nil,
            !gamesViewModel.games.isEmpty ? .allGames : nil
        ].compactMap { $0 }
    }
    
    internal func handleButtonPress() {
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
    
    internal func handleVerticalNavigation(_ yValue: Float) {
        let sections = availableSections
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

    internal func handleHorizontalNavigation(_ xValue: Float) {
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
    
    internal func getFirstItemInSection(_ section: HomeSectionType) -> String? {
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
    
    internal func currentSectionForGame(_ game: PVGame) -> HomeSectionType {
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
    
    internal func sectionToId(_ section: HomeSectionType) -> String {
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
