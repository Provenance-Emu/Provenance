import Foundation
import RealmSwift
import Combine
import PVLibrary
import SwiftUI

public class RealmSaveStateDriver: SaveStateDriver {
    /// The game ID to filter save states by
    public var gameId: String? {
        didSet {
            updateSaveStates()
        }
    }

    private let realm: Realm
    private var notificationToken: NotificationToken?

    /// Publisher for save state changes
    public let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])
    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    /// Publisher for number of saves
    public var numberOfSavesPublisher: AnyPublisher<Int, Never> {
        saveStatesPublisher.map { $0.count }.eraseToAnyPublisher()
    }

    /// Publisher for total size of all save states
    public var savesSizePublisher: AnyPublisher<UInt64, Never> {
        saveStatesSubject.map { saveStates in
            self.realm.objects(PVSaveState.self)
                .filter { saveState in
                    saveStates.contains { $0.id == saveState.id }
                }
                .reduce(0) { $0 + $1.size }
        }.eraseToAnyPublisher()
    }

    public init(realm: Realm) {
        self.realm = realm
        setupObservers()
    }

    deinit {
        notificationToken?.invalidate()
    }

    private func setupObservers() {
        let results = realm.objects(PVSaveState.self)
        notificationToken = results.observe { [weak self] changes in
            self?.updateSaveStates()
        }
        updateSaveStates()
    }

    private func updateSaveStates() {
        var results = realm.objects(PVSaveState.self)

        if let gameId = gameId {
            results = results.filter("game.id == %@", gameId)
        }

        let viewModels = convertRealmResults(results)
        saveStatesSubject.send(viewModels)
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        var results = realm.objects(PVSaveState.self)

        if let gameId = gameId {
            results = results.filter("game.id == %@", gameId)
        }

        return convertRealmResults(results)
    }

    public func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel] {
        convertRealmResults(realm.objects(PVSaveState.self).filter("game.id == %@", gameID))
    }

    public func updateDescription(saveStateId: String, description: String?) {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

        try? realm.write {
            saveState.userDescription = description
        }
    }

    public func setPin(saveStateId: String, isPinned: Bool) {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

        try? realm.write {
            saveState.isPinned = isPinned
        }
    }

    public func setFavorite(saveStateId: String, isFavorite: Bool) {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

        try? realm.write {
            saveState.isFavorite = isFavorite
        }
    }

    public func share(saveStateId: String) -> URL? {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return nil }
        return saveState.file?.url
    }

    public func update(saveState: SaveStateRowViewModel) {
        guard let realmSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveState.id) else { return }

        try? realm.write {
            realmSaveState.userDescription = saveState.description
            realmSaveState.isPinned = saveState.isPinned
            realmSaveState.isFavorite = saveState.isFavorite
        }
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        let ids = saveStates.map { $0.id }
        let realmSaveStates = realm.objects(PVSaveState.self).filter("id IN %@", ids)

        try? realm.write {
            realm.delete(realmSaveStates)
        }
    }

    public func loadSaveStates(forGameId gameID: String) {
        let states = getSaveStates(forGameId: gameID)
        saveStatesSubject.send(states)
    }

    private func convertRealmResults(_ results: Results<PVSaveState>) -> [SaveStateRowViewModel] {
        results
            .filter {
                $0.game != nil
            }
            .map { realmSaveState in

                let thumbnailImage: SwiftUI.Image
                if let uiImage = realmSaveState.fetchUIImage() {
                    thumbnailImage = .init(uiImage: uiImage)
                } else {
                    thumbnailImage = .init(uiImage: UIImage.missingArtworkImage(gameTitle: realmSaveState.game?.title ?? "Deleted", ratio: 1))
                }

                let viewModel = SaveStateRowViewModel(
                    id: realmSaveState.id,
                    gameID: realmSaveState.game.id,
                    gameTitle: realmSaveState.game.title,
                    saveDate: realmSaveState.date,
                    thumbnailImage: thumbnailImage,
                    description: realmSaveState.userDescription,
                    isAutoSave: realmSaveState.isAutosave,
                    isPinned: realmSaveState.isPinned,
                    isFavorite: realmSaveState.isFavorite
                )

                return viewModel
        }
    }
}
