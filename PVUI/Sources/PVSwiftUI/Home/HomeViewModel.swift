//
//  HomeViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/15/26.
//

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVRealm
import PVUIBase
import Combine

/// View model for HomeView that observes Realm collections on a background queue
/// and publishes immutable snapshot models. This prevents the excessive SwiftUI
/// view invalidation caused by multiple `@ObservedResults` property wrappers
/// each independently triggering re-renders on any Realm write.
///
/// Modelled after `ConsoleGamesViewModel` which does not have the flickering issue.
@available(iOS 14, tvOS 14, *)
final class HomeViewModel: ObservableObject {

    // MARK: - Published snapshot models

    @Published var allGamesModels: [GameCellModel] = []
    @Published var favoritesModels: [GameCellModel] = []
    @Published var recentlyPlayedModels: [GameCellModel] = []
    @Published var mostPlayedModels: [GameCellModel] = []

    /// Sort direction - toggling re-sorts the cached models without a Realm re-query.
    @Published var sortAscending: Bool = true {
        didSet {
            guard oldValue != sortAscending else { return }
            Task { @MainActor in
                resortModelsOnMain()
            }
        }
    }

    // MARK: - Private Realm observation

    private let modelsQueue = DispatchQueue(
        label: "org.provenance.ui.home.models",
        qos: .userInitiated
    )
    private var modelsRealm: Realm?
    private var allGamesToken: NotificationToken?
    private var favoritesToken: NotificationToken?
    private var recentToken: NotificationToken?
    private var mostPlayedToken: NotificationToken?

    /// MD5 -> model lookup for deriving recently-played from the order list.
    private var modelsByMD5: [String: GameCellModel] = [:]
    /// Ordered list of MD5 hashes from PVRecentGame, newest first.
    private var recentMD5Order: [String] = []

    // MARK: - Init / Deinit

    init(sortAscending: Bool = true) {
        self.sortAscending = sortAscending
        startModelObservations()
    }

    deinit {
        allGamesToken?.invalidate()
        favoritesToken?.invalidate()
        recentToken?.invalidate()
        mostPlayedToken?.invalidate()
    }

    // MARK: - Observation setup

    private func startModelObservations() {
        modelsQueue.async { [weak self] in
            guard let self else { return }
            do {
                let realm = try Realm()
                self.modelsRealm = realm

                // All games
                let allGames = realm.objects(PVGame.self)
                self.allGamesToken = allGames.observe(
                    keyPaths: GameCellModel.observedKeyPaths,
                    on: self.modelsQueue
                ) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildAllGamesModels(from: snapshot)
                        case .error(let error):
                            ELOG("HomeViewModel: error observing all games: \(error.localizedDescription)")
                        }
                    }
                }

                // Favorites
                let favorites = realm.objects(PVGame.self)
                    .filter("isFavorite == true")
                self.favoritesToken = favorites.observe(
                    keyPaths: GameCellModel.observedKeyPaths,
                    on: self.modelsQueue
                ) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildFavoritesModels(from: snapshot)
                        case .error(let error):
                            ELOG("HomeViewModel: error observing favorites: \(error.localizedDescription)")
                        }
                    }
                }

                // Most played
                let mostPlayed = realm.objects(PVGame.self)
                    .filter("playCount > 0")
                self.mostPlayedToken = mostPlayed.observe(
                    keyPaths: GameCellModel.observedKeyPaths,
                    on: self.modelsQueue
                ) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildMostPlayedModels(from: snapshot)
                        case .error(let error):
                            ELOG("HomeViewModel: error observing most played: \(error.localizedDescription)")
                        }
                    }
                }

                // Recently played
                let recent = realm.objects(PVRecentGame.self)
                    .sorted(byKeyPath: "lastPlayedDate", ascending: false)
                self.recentToken = recent.observe(
                    on: self.modelsQueue
                ) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildRecentOrder(from: snapshot)
                        case .error(let error):
                            ELOG("HomeViewModel: error observing recent games: \(error.localizedDescription)")
                        }
                    }
                }

            } catch {
                ELOG("HomeViewModel: failed to open Realm: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Model rebuilding

    private func rebuildAllGamesModels(from games: Results<PVGame>) {
        autoreleasepool {
            var byMD5: [String: GameCellModel] = [:]
            byMD5.reserveCapacity(games.count)

            var all: [GameCellModel] = []
            all.reserveCapacity(games.count)

            for game in games where !game.isInvalidated {
                let model = GameCellModel(game: game)
                byMD5[model.md5] = model
                all.append(model)
            }

            self.modelsByMD5 = byMD5

            // Re-derive recently played from existing order with updated models.
            let recents = self.recentMD5Order.compactMap { byMD5[$0] }

            let sorted = self.sorted(all)
            Task { @MainActor [weak self] in
                self?.allGamesModels = sorted
                self?.recentlyPlayedModels = recents
            }
        }
    }

    private func rebuildFavoritesModels(from games: Results<PVGame>) {
        autoreleasepool {
            var favs: [GameCellModel] = []
            favs.reserveCapacity(games.count)
            for game in games where !game.isInvalidated {
                favs.append(GameCellModel(game: game))
            }
            let sorted = self.sorted(favs)
            Task { @MainActor [weak self] in
                self?.favoritesModels = sorted
            }
        }
    }

    private func rebuildMostPlayedModels(from games: Results<PVGame>) {
        autoreleasepool {
            var models: [GameCellModel] = []
            models.reserveCapacity(games.count)
            for game in games where !game.isInvalidated {
                models.append(GameCellModel(game: game))
            }
            // Sort by play count descending.
            models.sort { $0.playCount > $1.playCount }
            Task { @MainActor [weak self] in
                self?.mostPlayedModels = models
            }
        }
    }

    private func rebuildRecentOrder(from recents: Results<PVRecentGame>) {
        autoreleasepool {
            recentMD5Order = recents.compactMap { recent in
                guard !recent.isInvalidated,
                      let game = recent.game,
                      !game.isInvalidated else { return nil }
                return game.md5Hash
            }

            let models = recentMD5Order.compactMap { modelsByMD5[$0] }

            Task { @MainActor [weak self] in
                self?.recentlyPlayedModels = models
            }
        }
    }

    // MARK: - Sorting

    @MainActor
    private func resortModelsOnMain() {
        allGamesModels = sorted(allGamesModels)
        favoritesModels = sorted(favoritesModels)
        // recentlyPlayedModels keeps play-order, do not resort.
        // mostPlayedModels keeps play-count order, do not resort.
    }

    private func sorted(_ models: [GameCellModel]) -> [GameCellModel] {
        let ascending = sortAscending
        return models.sorted { lhs, rhs in
            if ascending {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            } else {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            }
        }
    }

    // MARK: - Convenience accessors for navigation

    /// Look up a game model by its ID across the all-games model cache.
    func gameModel(byID id: String) -> GameCellModel? {
        allGamesModels.first { $0.id == id }
    }
}
#endif
