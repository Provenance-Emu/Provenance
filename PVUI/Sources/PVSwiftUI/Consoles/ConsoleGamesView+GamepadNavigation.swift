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
        guard let currentSection = focusedSection else {
            // No section focused, select first section and item
            focusedSection = availableSections.first
            focusedItemInSection = getFirstItemInSection(availableSections.first!)
            return
        }

        if isMovingToNewSection(currentSection: currentSection, direction: yValue) {
            // Moving to a new section
            if let nextSection = getNextSection(from: currentSection, direction: yValue) {
                DLOG("Moving from section \(currentSection) to \(nextSection)")
                focusedSection = nextSection

                // Set appropriate item in new section
                if yValue > 0 && nextSection == .recentSaveStates {
                    // Moving up to continues section - select last item
                    focusedItemInSection = gamesViewModel.recentSaveStates.last?.id
                } else {
                    // Any other section transition - select first item
                    focusedItemInSection = getFirstItemInSection(nextSection)
                }
            }
        } else {
            // Moving within current section
            handleVerticalNavigationWithinSection(currentSection, direction: yValue)
        }
    }

    internal func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = focusedSection else { return }

        if xValue < 0 && isOnFirstItemInSection(section) {
            // At start of section, try to move to previous section
            _ = moveBetweenSections(section, direction: 1.0)
        } else if xValue > 0 && isOnLastItemInSection(section) {
            // At end of section, try to move to next section
            _ = moveBetweenSections(section, direction: -1.0)
        } else {
            // Normal within-section navigation
            _ = moveWithinSection(section, direction: xValue)
        }
    }

    internal func getFirstItemInSection(_ section: HomeSectionType) -> String? {
        return getItemsForSection(section).first
    }

    internal func getLastItemInSection(_ section: HomeSectionType) -> String? {
        return getItemsForSection(section).last
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

    // Helper functions for section navigation
    private func isMovingToNewSection(currentSection: HomeSectionType, direction: Float) -> Bool {
        let sections = availableSections
        guard !sections.isEmpty,
              let currentIndex = sections.firstIndex(of: currentSection) else { return false }

        if direction > 0 {  // Moving up
            // Check if there's any section above us and it's within bounds
            return currentIndex > 0 &&
                   currentIndex - 1 >= 0 &&
                   sections[currentIndex - 1] != currentSection
        } else {  // Moving down
            // Check if there's any section below us and it's within bounds
            return currentIndex < sections.count - 1 &&
                   currentIndex + 1 < sections.count &&
                   sections[currentIndex + 1] != currentSection
        }
    }

    private func getNextSection(from currentSection: HomeSectionType, direction: Float) -> HomeSectionType? {
        let sections = availableSections
        guard !sections.isEmpty,
              let currentIndex = sections.firstIndex(of: currentSection) else { return nil }

        let newIndex = direction > 0 ?
            max(0, currentIndex - 1) :
            min(sections.count - 1, currentIndex + 1)

        guard newIndex >= 0 && newIndex < sections.count else { return nil }
        return sections[newIndex]
    }

    private func handleVerticalNavigationWithinSection(_ section: HomeSectionType, direction: Float) {
        switch section {
        case .recentSaveStates:
            // Handle continues section navigation
            let saveStates = gamesViewModel.recentSaveStates
            if let currentItem = focusedItemInSection,
               let currentIndex = saveStates.firstIndex(where: { $0.id == currentItem }) {
                let newIndex = direction > 0 ?
                    max(0, currentIndex - 1) :
                    min(saveStates.count - 1, currentIndex + 1)
                focusedItemInSection = saveStates[newIndex].id
            }

        case .allGames:
            // Handle grid navigation
            let games = Array(gamesViewModel.games)
            if let currentIndex = games.firstIndex(where: { $0.id == focusedItemInSection }) {
                if direction > 0 {
                    // Moving up
                    let newIndex = currentIndex - Int(gameLibraryScale)
                    if newIndex >= 0 {
                        focusedItemInSection = games[newIndex].id
                    } else {
                        // We're at the first row
                        if let currentSection = focusedSection,
                           let nextSection = getNextSection(from: currentSection, direction: direction) {
                            if nextSection == .allGames {
                                // If next section is the same section, wrap to bottom
                                let totalRows = (games.count + Int(gameLibraryScale) - 1) / Int(gameLibraryScale)
                                let currentColumn = currentIndex % Int(gameLibraryScale)
                                let lastRowIndex = min(games.count - 1, ((totalRows - 1) * Int(gameLibraryScale)) + currentColumn)
                                focusedItemInSection = games[lastRowIndex].id
                            } else {
                                // Move to next section
                                focusedSection = nextSection
                                focusedItemInSection = getFirstItemInSection(nextSection)
                            }
                        }
                    }
                } else {
                    // Moving down
                    let newIndex = currentIndex + Int(gameLibraryScale)
                    if newIndex < games.count {
                        focusedItemInSection = games[newIndex].id
                    } else {
                        // We're at the last row
                        if let currentSection = focusedSection,
                           let nextSection = getNextSection(from: currentSection, direction: direction) {
                            if nextSection == .allGames {
                                // If next section is the same section, wrap to top
                                focusedItemInSection = games[currentIndex % Int(gameLibraryScale)].id
                            } else {
                                // Move to next section
                                focusedSection = nextSection
                                focusedItemInSection = getFirstItemInSection(nextSection)
                            }
                        }
                    }
                }
            }

        case .favorites:
            // Handle favorites section navigation
            let favorites = gamesViewModel.favorites
            if let currentItem = focusedItemInSection,
               let currentIndex = favorites.firstIndex(where: { $0.id == currentItem }) {
                let newIndex = direction > 0 ?
                    max(0, currentIndex - 1) :
                    min(favorites.count - 1, currentIndex + 1)
                focusedItemInSection = favorites[newIndex].id
            }

        case .recentlyPlayedGames:
            // Handle recently played section navigation
            let recentGames = gamesViewModel.recentlyPlayedGames
            if let currentItem = focusedItemInSection,
               let currentIndex = recentGames.firstIndex(where: { $0.game?.id == currentItem }) {
                let newIndex = direction > 0 ?
                    max(0, currentIndex - 1) :
                    min(recentGames.count - 1, currentIndex + 1)
                focusedItemInSection = recentGames[newIndex].game?.id
            }

        case .mostPlayed:
            // Handle most played section navigation
            let mostPlayed = gamesViewModel.mostPlayed
            if let currentItem = focusedItemInSection,
               let currentIndex = mostPlayed.firstIndex(where: { $0.id == currentItem }) {
                let newIndex = direction > 0 ?
                    max(0, currentIndex - 1) :
                    min(mostPlayed.count - 1, currentIndex + 1)
                focusedItemInSection = mostPlayed[newIndex].id
            }
        }
    }

    private func moveWithinSection(_ section: HomeSectionType, direction: Float) -> Bool {
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
            items = gamesViewModel.mostPlayed.map { $0.id }
        }

        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }

        let newIndex = direction < 0 ?
            max(0, currentIndex - 1) :
            min(items.count - 1, currentIndex + 1)

        focusedSection = section
        focusedItemInSection = items[newIndex]
        DLOG("Moving within section \(section) to item \(items[newIndex])")
        return true
    }

    private func moveBetweenSections(_ currentSection: HomeSectionType, direction: Float) -> Bool {
        if let nextSection = getNextSection(from: currentSection, direction: direction) {
            focusedSection = nextSection
            focusedItemInSection = direction < 0 ?
                getFirstItemInSection(nextSection) :
                getLastItemInSection(nextSection)
            DLOG("Moving to section: \(nextSection)")
            return true
        }
        return false
    }

    private func isOnFirstItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == 0
    }

    private func isOnLastItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == items.count - 1
    }

    private func getItemsForSection(_ section: HomeSectionType) -> [String] {
        switch section {
        case .recentSaveStates:
            return gamesViewModel.recentSaveStates.map { $0.id }
        case .favorites:
            return gamesViewModel.favorites.map { $0.id }
        case .recentlyPlayedGames:
            return gamesViewModel.recentlyPlayedGames.map { $0.id }
        case .allGames:
            return gamesViewModel.games.map { $0.id }
        case .mostPlayed:
            return gamesViewModel.mostPlayed.map { $0.id }
        }
    }
}
