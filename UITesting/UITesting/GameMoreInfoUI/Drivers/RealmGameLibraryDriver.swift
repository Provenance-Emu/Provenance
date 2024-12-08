import Foundation
import RealmSwift
import PVRealm
import PVLibrary
import UIKit

/// A Realm-based implementation of GameLibraryDriver
final class RealmGameLibraryDriver: GameLibraryDriver {
    private let realm: Realm

    /// Initialize with an optional Realm instance
    /// - Parameter realm: Optional Realm instance. If nil, the default Realm will be used.
    init(realm: Realm? = nil) throws {
        self.realm = try realm ?? .init()
    }

    func game(byId id: String) -> GameMoreInfoViewModelDataSource? {
        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: id) else {
            return nil
        }

        return RealmGameWrapper(game: game)
    }

    /// Get the first game ID in the database
    func firstGameId() -> String? {
        return realm.objects(PVGame.self).first?.md5Hash
    }

    func updateGameName(id: String, value: String?) {
        updateGame(id: id) { game in
            game.title = value ?? ""
        }
    }

    func updateGameDeveloper(id: String, value: String?) {
        updateGame(id: id) { game in
            game.developer = value
        }
    }

    func updateGamePublishDate(id: String, value: String?) {
        updateGame(id: id) { game in
            game.publishDate = value
        }
    }

    func updateGameGenres(id: String, value: String?) {
        updateGame(id: id) { game in
            game.genres = value
        }
    }

    func updateGameRegion(id: String, value: String?) {
        updateGame(id: id) { game in
            game.regionName = value
        }
    }

    func resetGameStats(id: String) {
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
private struct RealmGameWrapper: GameMoreInfoViewModelDataSource {
    let game: PVGame

    var name: String? {
        get { game.title }
        set { /* Handled by driver */ }
    }

    var filename: String? { game.file.fileName }
    var system: String? { game.system.name }
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

    var playCount: Int? { game.playCount }
    var timeSpentInGame: Int? { game.timeSpentInGame }

    var boxFrontArtwork: UIImage? {
        // For now, just return a placeholder
        // In a real implementation, this would use PVMediaCache or similar
        UIImage.image(withText: game.title, ratio: boxArtAspectRatio)
    }

    var boxBackArtwork: UIImage? {
        // For now, just return a placeholder
        // In a real implementation, this would use PVMediaCache or similar
        UIImage.image(withText: game.title, ratio: boxArtAspectRatio)
    }

    var referenceURL: URL? {
        if let urlString = game.referenceURL {
            return URL(string: urlString)
        }
        return nil
    }

    var id: String { game.md5Hash }

    var boxArtAspectRatio: CGFloat {
        let ratio = game.boxartAspectRatio
        return ratio.rawValue
    }
}

// MARK: - Preview Helpers

extension RealmGameLibraryDriver {
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
