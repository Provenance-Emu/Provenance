import Foundation
import Combine

/// Protocol for paged game library data source
protocol PagedGameLibraryDataSource {
    /// Get total number of games
    var gameCount: Int { get }

    /// Get game ID at index
    func gameId(at index: Int) -> String?

    /// Get index for game ID
    func index(for gameId: String) -> Int?

    /// Get game IDs sorted by system then name
    var sortedGameIds: [String] { get }
}

/// Protocol for game library data driver
protocol GameLibraryDriver: ObservableObject {
    /// Get a game by ID
    func game(byId id: String) -> GameMoreInfoViewModelDataSource?

    /// Update game properties
    func updateGameName(id: String, value: String?)
    func updateGameDeveloper(id: String, value: String?)
    func updateGamePublishDate(id: String, value: String?)
    func updateGameGenres(id: String, value: String?)
    func updateGameRegion(id: String, value: String?)

    /// Reset game statistics
    func resetGameStats(id: String)
}

/// Mock implementation of game library driver
class MockGameLibraryDriver: GameLibraryDriver, PagedGameLibraryDataSource {
    @Published private var games: [MockGameLibraryEntry] = []

    init() {
        // Create some mock entries
        games = [
            createMockGame(
                id: "mario",
                title: "Super Mario World",
                system: "SNES",
                developer: "Nintendo",
                genres: "Platform, Action"
            ),
            createMockGame(
                id: "zelda",
                title: "The Legend of Zelda",
                system: "NES",
                developer: "Nintendo",
                genres: "Action, Adventure"
            ),
            createMockGame(
                id: "sonic",
                title: "Sonic the Hedgehog",
                system: "Genesis",
                developer: "Sega",
                genres: "Platform"
            ),
            createMockGame(
                id: "ff7",
                title: "Final Fantasy VII",
                system: "PlayStation",
                developer: "Square",
                genres: "RPG"
            )
        ]

        // Sort games by system then name
        games.sort { g1, g2 in
            if g1.system == g2.system {
                return g1.title < g2.title
            }
            return (g1.system ?? "") < (g2.system ?? "")
        }
    }

    private func createMockGame(
        id: String,
        title: String,
        system: String,
        developer: String,
        genres: String
    ) -> MockGameLibraryEntry {
        let game = MockGameLibraryEntry()
        game.id = id
        game.title = title
        game.systemIdentifier = system
        game.developer = developer
        game.genres = genres
        return game
    }

    func game(byId id: String) -> GameMoreInfoViewModelDataSource? {
        games.first { $0.id == id }
    }

    private func updateGame<T>(_ id: String, update: (inout MockGameLibraryEntry) -> T) -> T? {
        if let index = games.firstIndex(where: { $0.id == id }) {
            var game = games[index]
            let result = update(&game)
            objectWillChange.send()
            games[index] = game
            return result
        }
        return nil
    }

    func updateGameName(id: String, value: String?) {
        updateGame(id) { game in
            game.name = value
        }
    }

    func updateGameDeveloper(id: String, value: String?) {
        updateGame(id) { game in
            game.developer = value
        }
    }

    func updateGamePublishDate(id: String, value: String?) {
        updateGame(id) { game in
            game.publishDate = value
        }
    }

    func updateGameGenres(id: String, value: String?) {
        updateGame(id) { game in
            game.genres = value
        }
    }

    func updateGameRegion(id: String, value: String?) {
        updateGame(id) { game in
            game.region = value
        }
    }

    func resetGameStats(id: String) {
        updateGame(id) { game in
            game.playCount = 0
            game.timeSpentInGame = 0
            game.lastPlayed = nil
        }
    }

    // MARK: - PagedGameLibraryDataSource

    var gameCount: Int {
        games.count
    }

    func gameId(at index: Int) -> String? {
        guard index >= 0 && index < games.count else { return nil }
        return games[index].id
    }

    func index(for gameId: String) -> Int? {
        games.firstIndex { $0.id == gameId }
    }

    var sortedGameIds: [String] {
        games.map(\.id)
    }
}

// Extension to make MockGameLibraryEntry mutable
extension MockGameLibraryEntry {
    func update<T>(_ keyPath: WritableKeyPath<MockGameLibraryEntry, T>, value: T) {
        var mutable = self
        mutable[keyPath: keyPath] = value
    }
}
