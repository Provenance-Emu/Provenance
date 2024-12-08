import Foundation
import Combine

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
class MockGameLibraryDriver: GameLibraryDriver {
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
        game.originalArtworkURL = URL(string: "https://example.com/\(id)-front.jpg")
        game.boxBackArtworkURL = URL(string: "https://example.com/\(id)-back.jpg")
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
}

// Extension to make MockGameLibraryEntry mutable
extension MockGameLibraryEntry {
    func update<T>(_ keyPath: WritableKeyPath<MockGameLibraryEntry, T>, value: T) {
        var mutable = self
        mutable[keyPath: keyPath] = value
    }
}
