import Foundation
import Combine

/// Protocol for paged game library data source
public protocol PagedGameLibraryDataSource {
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
public protocol GameLibraryDriver: ObservableObject {
    /// Get a game by ID
    func game(byId id: String) -> (any GameMoreInfoViewModelDataSource)?

    /// Update game properties
    func updateGameName(id: String, value: String?)
    func updateGameDeveloper(id: String, value: String?)
    func updateGamePublishDate(id: String, value: String?)
    func updateGameGenres(id: String, value: String?)
    func updateGameRegion(id: String, value: String?)
    /// Update game rating (-1 for unrated, 0-5 for rated)
    func updateGameRating(id: String, value: Int)

    /// Reset game statistics
    func resetGameStats(id: String)
}

/// Mock implementation of game library driver
public class MockGameLibraryDriver: GameLibraryDriver, PagedGameLibraryDataSource {
    @Published private var games: [MockGameLibraryEntry] = []

    public init() {
        // Create some mock entries
        games = [
            createMockGame(
                id: "mario",
                title: "Super Mario World",
                system: "SNES",
                developer: "Nintendo",
                genres: "Platform, Action",
                rating: 5,
                referenceURL: "https://www.mobygames.com/game/super-mario-world"
            ),
            createMockGame(
                id: "zelda",
                title: "The Legend of Zelda",
                system: "NES",
                developer: "Nintendo",
                genres: "Action, Adventure",
                rating: 4,
                referenceURL: nil
            ),
            createMockGame(
                id: "sonic",
                title: "Sonic the Hedgehog",
                system: "Genesis",
                developer: "Sega",
                genres: "Platform",
                rating: 3,
                referenceURL: "https://www.mobygames.com/game/sonic-the-hedgehog"
            ),
            createMockGame(
                id: "ff7",
                title: "Final Fantasy VII",
                system: "PlayStation",
                developer: "Square",
                genres: "RPG",
                rating: 2,
                referenceURL: nil
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
        genres: String,
        rating: Int = 0,
        referenceURL: String?
    ) -> MockGameLibraryEntry {
        let game = MockGameLibraryEntry()
        game.id = id
        game.title = title
        game.systemIdentifier = system
        game.developer = developer
        game.genres = genres
        game.rating = rating
        if let urlString = referenceURL {
            game.referenceURL = URL(string: urlString)
        }
        
        // Add custom descriptions for each game
        game.gameDescription = switch id {
        case "mario":
            """
            Experience Mario's most exciting adventure yet in this classic SNES title!
            Join Mario and Yoshi as they explore Dinosaur Land to rescue Princess Peach
            from the evil Bowser. Discover new power-ups, secret exits, and hidden paths
            across multiple worlds filled with challenging enemies and puzzles.
            """
        case "zelda":
            """
            Embark on an epic quest to save Princess Zelda and the kingdom of Hyrule.
            As Link, you'll explore a vast world, discover dungeons, collect powerful
            items, and face challenging enemies in this groundbreaking NES adventure.
            """
        case "sonic":
            """
            Speed through multiple zones as Sonic the Hedgehog in this classic Genesis
            platformer. Use your spin dash to defeat Dr. Robotnik's mechanical army
            and collect the Chaos Emeralds to save the animals of Green Hill Zone.
            """
        case "ff7":
            """
            Join Cloud Strife and a diverse cast of characters in this epic RPG.
            Battle the evil Shinra Corporation, uncover dark secrets, and save the
            planet from destruction in this PlayStation masterpiece.
            """
        default:
            nil
        }

        return game
    }

    public func game(byId id: String) -> (any GameMoreInfoViewModelDataSource)? {
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

    public func updateGameName(id: String, value: String?) {
        updateGame(id) { game in
            game.name = value
        }
    }

    public func updateGameDeveloper(id: String, value: String?) {
        updateGame(id) { game in
            game.developer = value
        }
    }

    public func updateGamePublishDate(id: String, value: String?) {
        updateGame(id) { game in
            game.publishDate = value
        }
    }

    public func updateGameGenres(id: String, value: String?) {
        updateGame(id) { game in
            game.genres = value
        }
    }

    public func updateGameRegion(id: String, value: String?) {
        updateGame(id) { game in
            game.region = value
        }
    }

    public func updateGameRating(id: String, value: Int) {
        assert(-1 ... 5 ~= value, "Rating must be between -1 and 5")
        updateGame(id) { game in
            game.rating = value
        }
    }

    public func resetGameStats(id: String) {
        updateGame(id) { game in
            game.playCount = 0
            game.timeSpentInGame = 0
            game.lastPlayed = nil
        }
    }

    // MARK: - PagedGameLibraryDataSource

    public var gameCount: Int {
        games.count
    }

    public func gameId(at index: Int) -> String? {
        guard index >= 0 && index < games.count else { return nil }
        return games[index].id
    }

    public func index(for gameId: String) -> Int? {
        games.firstIndex { $0.id == gameId }
    }

    public var sortedGameIds: [String] {
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
