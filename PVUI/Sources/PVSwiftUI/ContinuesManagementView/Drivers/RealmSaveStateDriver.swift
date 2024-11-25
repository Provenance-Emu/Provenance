import Foundation
import RealmSwift
import Combine
import PVLibrary
import SwiftUI

public class RealmSaveStateDriver: SaveStateDriver {
    private let realm: Realm
    public let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])
    private var notificationToken: NotificationToken?

    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    public init(realm: Realm? = nil) throws {
        self.realm = try realm ?? Realm()

        // Observe Realm changes
        let token = self.realm.objects(PVSaveState.self).observe { [weak self] changes in
            self?.handleRealmChanges(changes)
        }
        self.notificationToken = token
    }

    deinit {
        notificationToken?.invalidate()
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        convertRealmResults(realm.objects(PVSaveState.self))
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
        return saveState.file.url
    }

    public func update(saveState: SaveStateRowViewModel) {
        guard let realmSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveState.id) else { return }

        try? realm.write {
            realmSaveState.userDescription = saveState.description
            realmSaveState.isPinned = saveState.isPinned
            realmSaveState.isFavorite = saveState.isFavorite
            realmSaveState.isAutosave = saveState.isAutoSave
        }
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        let saveStateIds = saveStates.map { $0.id }
        let realmSaveStates = realm.objects(PVSaveState.self).filter("id IN %@", saveStateIds)

        try? realm.write {
            realm.delete(realmSaveStates)
        }
    }

    public func loadSaveStates(forGameId gameID: String) {
        let states = getSaveStates(forGameId: gameID)
        saveStatesSubject.send(states)
    }

    private func handleRealmChanges(_ changes: RealmCollectionChange<Results<PVSaveState>>) {
        switch changes {
        case .initial(let results), .update(let results, _, _, _):
            saveStatesSubject.send(convertRealmResults(results))
        case .error(let error):
            print("Error observing Realm changes: \(error)")
        }
    }

    private func convertRealmResults(_ results: Results<PVSaveState>) -> [SaveStateRowViewModel] {
        results
            .filter {
                $0.game != nil
            }
            .map { realmSaveState in
                
                // TODO: Fix loading artwork from image cache
                let thumbnailImage: SwiftUI.Image
                if let imagePath = realmSaveState.image?.pathOfCachedImage,
                   FileManager.default.fileExists(atPath: imagePath.path()),
                   let image = UIImage(contentsOfFile: imagePath.path()) {
                    thumbnailImage = .init(uiImage: image)
                } else {
                    thumbnailImage = Image("missingArtwork")
//                    thumbnailImage = .missingArtwork(gameTitle: realmSaveState.game.title, ratio: 1.0)
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
