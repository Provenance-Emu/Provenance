import Foundation
import PVRealm
import PVMediaCache
import PVLogging
import SwiftUI
import Combine
import RealmSwift
import PVLibrary
import UIKit

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

    public func updateGameRating(id: String, value: Int) {
        assert(-1 ... 5 ~= value, "Rating must be between -1 and 5")
        guard let game = try? Realm().object(ofType: PVGame.self, forPrimaryKey: id) else {
            return
        }

        updateGame(id: id) { game in
            game.rating = value
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
private final class RealmGameWrapper: GameMoreInfoViewModelDataSource, ArtworkObservable {
    @ObservedRealmObject private var game: PVGame
    @Published private(set) var frontArtwork: UIImage?
    @Published private(set) var backArtwork: UIImage?
    /// Track the current artwork URL to detect changes
    private var currentArtworkURL: String = ""
    /// Cancellation token for observation
    private var cancellables = Set<AnyCancellable>()

    /// Access to the underlying PVGame object
    var pvGame: PVGame? {
        return game
    }

    var gameDescription: String? {
        game.gameDescription
    }

    func frontArtworkPublisher() -> AnyPublisher<UIImage?, Never> {
        $frontArtwork.eraseToAnyPublisher()
    }

    func backArtworkPublisher() -> AnyPublisher<UIImage?, Never> {
        $backArtwork.eraseToAnyPublisher()
    }

    init(game: PVGame) {
        self._game = ObservedRealmObject(wrappedValue: game)
        self.currentArtworkURL = game.trueArtworkURL

        // Don't set placeholder immediately anymore
        Task { await loadArtwork() }

        // Setup notification observer for artwork changes
        NotificationCenter.default.publisher(for: .gameLibraryDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Check if artwork URL has changed
                if self.game.trueArtworkURL != self.currentArtworkURL {
                    self.currentArtworkURL = self.game.trueArtworkURL
                    Task { await self.loadArtwork() }
                }
            }
            .store(in: &cancellables)
    }

    private func loadArtwork() async {
        // Try to load front artwork
        let artworkURL = game.trueArtworkURL
        if !artworkURL.isEmpty {
            // Clear existing artwork first to ensure UI updates
            await MainActor.run { self.frontArtwork = nil }

            if let image = await PVMediaCache.shareInstance().image(forKey: artworkURL) {
                await MainActor.run { self.frontArtwork = image }
            } else {
                // Set placeholder while loading
                await MainActor.run {
                    self.frontArtwork = UIImage.image(withText: game.title, ratio: boxArtAspectRatio)
                }
            }
        }

        // Try to load back artwork
        if let backURL = game.boxBackArtworkURL,
           !backURL.isEmpty {
            // Clear existing back artwork first
            await MainActor.run { self.backArtwork = nil }

            // First try to load from cache
            if let image = await PVMediaCache.shareInstance().image(forKey: backURL) {
                await MainActor.run { self.backArtwork = image }
            } else {
                // If not in cache, try to download
                guard let url = URL(string: backURL) else { return }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        // Save to cache for later
                        try? PVMediaCache.writeData(toDisk: data, withKey: backURL)
                        await MainActor.run { self.backArtwork = image }
                    }
                } catch {
                    ELOG("Failed to download back artwork: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    var name: String? {
        get { game.title }
        set { /* Handled by driver */ }
    }

    var filename: String? {
        get { game.file?.fileName }
        set { /* Handled by driver */ }
    }

    var system: String? {
        get { game.system?.name }
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
    }

    var boxBackArtwork: UIImage? {
        get { backArtwork }
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

    public var rating: Int {
        get { game.rating }
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
                    game.rating = Int.random(in: 0...5)
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

// MARK: - GameContextMenuDelegate Implementation
extension RealmGameLibraryDriver: GameContextMenuDelegate {
    /// Implementation of GameContextMenuDelegate methods
    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Rename requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Choose cover requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Move to system requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Show save states requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Show game info requested for game ID \(gameId)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Show image picker requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Show artwork search requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Choose artwork source requested for game \(game.title)")
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        /// This method would be implemented by the parent view controller
        DLOG("RealmGameLibraryDriver: Disc selection requested for game \(game.title)")
    }
}
