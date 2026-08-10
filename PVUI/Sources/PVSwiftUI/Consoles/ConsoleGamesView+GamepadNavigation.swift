//
//  ConsoleGamesView+GamepadNavigation.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

/// Gamepad navigation
extension ConsoleGamesView {

    /// Number of columns the *drawn* all-games section actually uses.
    ///
    /// Derived from the same `itemsPerRow` value that builds `columns` for the
    /// `LazyVGrid`, so vertical navigation can never desync from the rendered grid.
    /// Two adjustments on top of it:
    /// * list mode (`viewGamesAsGrid == false`) renders one item per row, so up/down
    ///   must step by 1 rather than by the grid scale;
    /// * `itemsPerRow` can return `0` on the simulator branch, and the navigation
    ///   math uses `%` / integer division, so it is clamped to at least 1.
    private var navigationColumnCount: Int {
        guard viewModel.viewGamesAsGrid else { return 1 }
        return max(1, itemsPerRow)
    }

    private var recentSaveStateIdsForNavigation: [String] {
        let realm = RomDatabase.sharedInstance.realm
        let results = realm.objects(PVSaveState.self)
            .filter("game.systemIdentifier == %@", console.identifier)
            .sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
        return results.prefix(20).map { $0.id }
    }

    internal var availableSections: [HomeSectionType] {
        [
            (showRecentSaveStates && !recentSaveStateIdsForNavigation.isEmpty) ? .recentSaveStates : nil,
            (showFavorites && !favoritesModels.isEmpty) ? .favorites : nil,
            (showRecentGames && !recentlyPlayedModels.isEmpty) ? .recentlyPlayedGames : nil,
            !allGamesModels.isEmpty ? .allGames : nil
        ].compactMap { $0 }
    }

    /// The `GameCellModel` currently focused, if the focused section is a game section.
    /// `nil` for `.recentSaveStates` (those are save states, not games) and `.mostPlayed`
    /// (not rendered by this view).
    internal var focusedGameModel: GameCellModel? {
        guard let section = gamesViewModel.focusedSection,
              let itemId = gamesViewModel.focusedItemInSection else { return nil }
        switch section {
        case .favorites:
            return favoritesModels.first(where: { $0.id == itemId })
        case .recentlyPlayedGames:
            return recentlyPlayedModels.first(where: { $0.id == itemId })
        case .allGames:
            return allGamesModels.first(where: { $0.id == itemId })
        case .recentSaveStates, .mostPlayed:
            return nil
        }
    }

    internal func handleButtonPress() {
        guard let section = gamesViewModel.focusedSection,
              let itemId = gamesViewModel.focusedItemInSection else {
            DLOG("No focused section or item")
            return
        }

        DLOG("Handling button press for section: \(section), item: \(itemId)")

        switch section {
        case .recentSaveStates:
            let realm = RomDatabase.sharedInstance.realm
            if let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: itemId) {
                Task.detached { @MainActor in
                    SceneCoordinator.shared.launchSaveState(saveState.freeze(), core: saveState.core?.freeze())
                }
            }
        case .favorites, .recentlyPlayedGames, .allGames:
            /// Route through the exact same closure the tap/click path uses so that
            /// multi-select mode toggles selection instead of launching the game.
            if let model = focusedGameModel {
                gameAction(for: model.md5)()
            }
        case .mostPlayed:
            break
        }
    }

    /// Escape / B — step out of grid navigation entirely so the focus ring clears.
    internal func clearNavigationFocus() {
        guard gamesViewModel.focusedSection != nil || gamesViewModel.focusedItemInSection != nil else { return }
        Task {
            await gamesViewModel.updateFocus(section: nil, item: nil)
        }
    }

    /// Place focus on the first item of the first available section. Used when a
    /// navigation key arrives before anything is focused.
    internal func seedInitialFocusIfNeeded() {
        guard gamesViewModel.focusedSection == nil else { return }
        guard let firstSection = availableSections.first else { return }
        Task {
            await gamesViewModel.updateFocus(
                section: firstSection,
                item: getFirstItemInSection(firstSection)
            )
        }
    }

    internal func handleVerticalNavigation(_ yValue: Float) {
        guard let currentSection = gamesViewModel.focusedSection else {
            // No section focused, select first section and item.
            // (`seedInitialFocusIfNeeded` no-ops on an empty library rather than
            // force-unwrapping `availableSections.first`.)
            seedInitialFocusIfNeeded()
            return
        }

        /// `.allGames` is the only multi-row section, so it must get first refusal on
        /// vertical input: `handleVerticalNavigationWithinSection` moves a row at a time
        /// and *already* hands off to the adjacent section once it runs out of rows.
        ///
        /// Without this exclusion `isMovingToNewSection` reported `true` for every Up
        /// press in the grid (there is always a shelf above it), so Up jumped straight
        /// out of the grid instead of moving up one row — Down worked because
        /// `.allGames` is last and the same check returned `false`. That asymmetry made
        /// multi-row grid navigation impossible whenever any shelf was visible.
        let sectionOwnsVerticalMovement = (currentSection == .allGames)

        if !sectionOwnsVerticalMovement, isMovingToNewSection(currentSection: currentSection, direction: yValue) {
            // Moving to a new section
            if let nextSection = getNextSection(from: currentSection, direction: yValue) {
                DLOG("Moving from section \(currentSection) to \(nextSection)")

                if yValue > 0 && nextSection == .recentSaveStates {
                    // Moving up to continues section - select last item
                    Task {
                        await gamesViewModel.updateFocus(
                            section: nextSection,
                            item: recentSaveStateIdsForNavigation.last
                        )
                    }
                } else {
                    // Any other section transition - select first item
                    Task {
                        await gamesViewModel.updateFocus(
                            section: nextSection,
                            item: getFirstItemInSection(nextSection)
                        )
                    }
                }
            }
        } else {
            // Moving within current section
            handleVerticalNavigationWithinSection(currentSection, direction: yValue)
        }
    }

    internal func handleHorizontalNavigation(_ xValue: Float) {
        guard let section = gamesViewModel.focusedSection else {
            seedInitialFocusIfNeeded()
            return
        }

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
        guard !game.isInvalidated else { return .allGames }
        // If we're in favorites section, ONLY return favorites if the game is actually in favorites
        if gamesViewModel.focusedSection == .favorites {
            return favoritesModels.contains(where: { $0.id == game.id }) ? .favorites : .allGames
        }
        // If we're in recently played, ONLY return recently played if the game is actually in recently played
        else if gamesViewModel.focusedSection == .recentlyPlayedGames {
            return recentlyPlayedModels.contains(where: { $0.id == game.id }) ? .recentlyPlayedGames : .allGames
        }
        // If we're in most played, ONLY return most played if the game is actually in most played
        else if gamesViewModel.focusedSection == .mostPlayed {
            return .allGames
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
        case .allGames:
            let columnCount = navigationColumnCount
            if let currentIndex = allGamesModels.firstIndex(where: { $0.id == gamesViewModel.focusedItemInSection }) {
                if direction > 0 {
                    // Moving up
                    let newIndex = currentIndex - columnCount
                    if newIndex >= 0 {
                        Task {
                            await gamesViewModel.updateFocus(section: section, item: allGamesModels[newIndex].id)
                        }
                    } else {
                        // We're at the first row
                        if let nextSection = getNextSection(from: section, direction: direction) {
                            if nextSection == .allGames {
                                // If next section is the same section, wrap to bottom
                                let totalRows = (allGamesModels.count + columnCount - 1) / columnCount
                                let currentColumn = currentIndex % columnCount
                                let lastRowIndex = min(allGamesModels.count - 1, ((totalRows - 1) * columnCount) + currentColumn)
                                Task {
                                    await gamesViewModel.updateFocus(section: section, item: allGamesModels[lastRowIndex].id)
                                }
                            } else {
                                // Move to next section
                                Task {
                                    await gamesViewModel.updateFocus(
                                        section: nextSection,
                                        item: getFirstItemInSection(nextSection)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // Moving down
                    let newIndex = currentIndex + columnCount
                    if newIndex < allGamesModels.count {
                        Task {
                            await gamesViewModel.updateFocus(section: section, item: allGamesModels[newIndex].id)
                        }
                    } else {
                        // We're at the last row
                        if let nextSection = getNextSection(from: section, direction: direction) {
                            if nextSection == .allGames {
                                // If next section is the same section, wrap to top
                                Task {
                                    await gamesViewModel.updateFocus(
                                        section: section,
                                        item: allGamesModels[currentIndex % columnCount].id
                                    )
                                }
                            } else {
                                // Move to next section
                                Task {
                                    await gamesViewModel.updateFocus(
                                        section: nextSection,
                                        item: getFirstItemInSection(nextSection)
                                    )
                                }
                            }
                        }
                    }
                }
            }

        default:
            moveWithinSection(section, direction: direction)
        }
    }

    private func moveWithinSection(_ section: HomeSectionType, direction: Float) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = gamesViewModel.focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }

        let newIndex = direction < 0 ?
            max(0, currentIndex - 1) :
            min(items.count - 1, currentIndex + 1)

        Task {
            await gamesViewModel.updateFocus(section: section, item: items[newIndex])
        }
        DLOG("Moving within section \(section) to item \(items[newIndex])")
        return true
    }

    private func moveBetweenSections(_ currentSection: HomeSectionType, direction: Float) -> Bool {
        if let nextSection = getNextSection(from: currentSection, direction: direction) {
            DLOG("ConsoleGamesView: Moving from section \(currentSection) to \(nextSection)")
            let newItem = direction < 0 ?
                getFirstItemInSection(nextSection) :
                getLastItemInSection(nextSection)

            DLOG("ConsoleGamesView: Current focus - Section: \(String(describing: gamesViewModel.focusedSection)), Item: \(String(describing: gamesViewModel.focusedItemInSection))")
            Task {
                await gamesViewModel.updateFocus(section: nextSection, item: newItem)
            }
            DLOG("ConsoleGamesView: New focus - Section: \(nextSection), Item: \(String(describing: newItem))")
            return true
        }
        return false
    }

    private func isOnFirstItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = gamesViewModel.focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == 0
    }

    private func isOnLastItemInSection(_ section: HomeSectionType) -> Bool {
        let items = getItemsForSection(section)
        guard let currentItem = gamesViewModel.focusedItemInSection,
              let currentIndex = items.firstIndex(of: currentItem) else { return false }
        return currentIndex == items.count - 1
    }

    private func getItemsForSection(_ section: HomeSectionType) -> [String] {
        switch section {
        case .recentSaveStates:
            return recentSaveStateIdsForNavigation
        case .favorites:
            return favoritesModels.map { $0.id }
        case .recentlyPlayedGames:
            return recentlyPlayedModels.map { $0.id }
        case .allGames:
            return allGamesModels.map { $0.id }
        case .mostPlayed:
            return []
        }
    }
}
