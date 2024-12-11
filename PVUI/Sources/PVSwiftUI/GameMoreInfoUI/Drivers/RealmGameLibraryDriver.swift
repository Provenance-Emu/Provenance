import Foundation
import RealmSwift
import PVRealm
import PVLibrary
import UIKit
import PVLogging

/// A Realm-based implementation of GameLibraryDriver
@MainActor
public final class RealmGameLibraryDriver: GameLibraryDriver, PagedGameLibraryDataSource {
    private let realm: Realm
    private var sortedGames: Results<PVGame>
    private var gameWrappers: [String: RealmGameWrapper] = [:]

    /// Initialize with an optional Realm instance
    /// - Parameter realm: Optional Realm instance. If nil, the default Realm will be used.
    public init(realm: Realm? = nil) throws {
        self.realm = try realm ?? .init()
        self.sortedGames = self.realm.objects(PVGame.self)
            .sorted(by: [
                SortDescriptor(keyPath: "systemIdentifier"),
                SortDescriptor(keyPath: "title")
            ])
    }

    public func game(byId id: String) -> (any GameMoreInfoViewModelDataSource)? {
        if let existing = gameWrappers[id] {
            return existing
        }

        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) else {
            return nil
        }

        let wrapper = RealmGameWrapper(game: game)
        gameWrappers[id] = wrapper
        return wrapper
    }

    /// Get the first game ID in the database
    func firstGameId() -> String? {
        return sortedGames.first?.md5Hash
    }

    // MARK: - PagedGameLibraryDataSource

    public var gameCount: Int {
        sortedGames.count
    }

    public func gameId(at index: Int) -> String? {
        guard index >= 0 && index < sortedGames.count else { return nil }
        return sortedGames[index].md5Hash
    }

    public func index(for gameId: String) -> Int? {
        sortedGames.firstIndex { $0.md5Hash == gameId }
    }

    public var sortedGameIds: [String] {
        sortedGames.map(\.md5Hash)
    }

    // MARK: - Game Updates

    public func updateGameName(id: String, value: String?) {
        updateGame(id: id) { game in
            game.title = value ?? ""
        }
    }

    public func updateGameDeveloper(id: String, value: String?) {
        updateGame(id: id) { game in
            game.developer = value
        }
    }

    public func updateGamePublishDate(id: String, value: String?) {
        updateGame(id: id) { game in
            game.publishDate = value
        }
    }

    public func updateGameGenres(id: String, value: String?) {
        updateGame(id: id) { game in
            game.genres = value
        }
    }

    public func updateGameRegion(id: String, value: String?) {
        updateGame(id: id) { game in
            game.regionName = value
        }
    }

    public func resetGameStats(id: String) {
        updateGame(id: id) { game in
            game.playCount = 0
            game.timeSpentInGame = 0
            game.lastPlayed = nil
        }
    }

    // MARK: - Private Helpers

    private func updateGame(id: String, update: @escaping (PVGame) -> Void) {
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) else {
            return
        }

        do {
            try realm.write {
                update(game)
            }
        } catch {
            print("Error updating game: \(error)")
        }
    }
}

/// Wrapper to adapt PVGame to GameMoreInfoViewModelDataSource
@MainActor
private class RealmGameWrapper: GameMoreInfoViewModelDataSource {
    @ObservedRealmObject private var game: PVGame
    @Published private(set) var frontArtwork: UIImage?
    @Published private(set) var backArtwork: UIImage?

    init(game: PVGame) {
        self._game = ObservedRealmObject(wrappedValue: game)
        // Set placeholder images immediately
        self.frontArtwork = UIImage.image(withText: game.title, ratio: boxArtAspectRatio)
        Task { await loadArtwork() }
    }

    private func loadArtwork() async {
        // Try to load front artwork
        if let artworkURL = game.activeArtworkURL,
           let image = await PVMediaCache.shareInstance().image(forKey: artworkURL) {
            await MainActor.run { self.frontArtwork = image }
        }

        // Try to load back artwork
        if let backURL = game.boxBackArtworkURL,
           let image = await PVMediaCache.shareInstance().image(forKey: backURL) {
            await MainActor.run { self.backArtwork = image }
        }
    }

    var name: String? {
        get { game.title }
        set { /* Handled by driver */ }
    }

    var filename: String? {
        get { game.file.fileName }
        set { /* Handled by driver */ }
    }

    var system: String? {
        get { game.system.name }
        set { /* Handled by driver */ }
    }

    var region: String? {
        get { game.regionName }
        set { /* Handled by driver */ }
    }

    var developer: String? {
        get { game.developer }
        set { /* Handled by driver */ }
    }

    var publishDate: String? {
        get { game.publishDate }
        set { /* Handled by driver */ }
    }

    var genres: String? {
        get { game.genres }
        set { /* Handled by driver */ }
    }

    var playCount: Int? {
        get { game.playCount }
        set { /* Handled by driver */ }
    }

    var timeSpentInGame: Int? {
        get { game.timeSpentInGame }
        set { /* Handled by driver */ }
    }

    var boxFrontArtwork: UIImage? {
        get { frontArtwork }
        set { /* Handled by driver */ }
    }

    var boxBackArtwork: UIImage? {
        get { backArtwork }
        set { /* Handled by driver */ }
    }

    var referenceURL: URL? {
        get {
            if let urlString = game.referenceURL {
                return URL(string: urlString)
            }
            return nil
        }
        set { /* Handled by driver */ }
    }

    var id: String {
        get { game.md5Hash }
        set { /* Handled by driver */ }
    }

    var boxArtAspectRatio: CGFloat {
        get { game.boxartAspectRatio.rawValue }
        set { /* Handled by driver */ }
    }

    var debugDescription: String? {
        get { game.debugDescription }
        set { /* Handled by driver */ }
    }
}

// MARK: - Preview Helpers

public extension RealmGameLibraryDriver {
    /// Create a preview Realm with mock data
    static func previewDriver() throws -> RealmGameLibraryDriver {
        // Create in-memory Realm for previews
        let config = Realm.Configuration(inMemoryIdentifier: "preview")
        let realm = try Realm(configuration: config)

        // Create mock systems
        let systems = [
            ("SNES", "Super Nintendo", "Nintendo", 1990),
            ("Genesis", "Sega Genesis", "Sega", 1988),
            ("PS1", "PlayStation", "Sony", 1994)
        ]

        try realm.write {
            // Add mock systems
            for (identifier, name, manufacturer, year) in systems {
                let system = PVSystem()
                system.identifier = identifier
                system.name = name
                system.manufacturer = manufacturer
                system.releaseYear = year
                realm.add(system)

                // Add 4 games for each system
                for i in 1...4 {
                    let md5Hash = UUID().uuidString
                    let game = PVGame()
                    game.title = "\(name) Game \(i)"
                    game.system = system
                    game.systemIdentifier = identifier
                    game.md5Hash = md5Hash
                    game.developer = "Developer \(i)"
                    game.publisher = "Publisher \(i)"
                    game.publishDate = "\(year + i)"
                    game.genres = "Action, Adventure"
                    game.regionName = ["USA", "Japan", "Europe"][i % 3]
                    game.playCount = Int.random(in: 0...100)
                    game.timeSpentInGame = Int.random(in: 0...10000)
                    game.originalArtworkURL = "https://example.com/\(identifier)/game\(i).jpg"
                    game.boxBackArtworkURL = "https://example.com/\(identifier)/game\(i)_back.jpg"

                    // Create a mock file
                    let file = PVFile(withPartialPath: "game\(i).rom", relativeRoot: .caches, size: Int.random(in: 0...100), md5: md5Hash)
                    game.file = file

                    realm.add(game)
                }
            }
        }

        return try RealmGameLibraryDriver(realm: realm)
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let gameLibraryDidUpdate = Notification.Name("gameLibraryDidUpdate")
}
