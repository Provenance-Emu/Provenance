import Foundation
import RealmSwift
import Combine
import PVLibrary
import SwiftUI

public class RealmSaveStateDriver: SaveStateDriver {
    private let realm: Realm
    private let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])

    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    public init(realm: Realm? = nil) throws {
        self.realm = try realm ?? Realm()

        // Observe Realm changes
        let token = self.realm.objects(PVSaveState.self).observe { [weak self] changes in
            self?.handleRealmChanges(changes)
        }

        // Store token to keep observation alive
        self.notificationToken = token
    }

    private var notificationToken: NotificationToken?

    deinit {
        notificationToken?.invalidate()
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        convertRealmResults(realm.objects(PVSaveState.self))
    }

    public func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel] {
        convertRealmResults(realm.objects(PVSaveState.self).filter("game.id == %@", gameID))
    }

    public func update(saveState: SaveStateRowViewModel) {
        guard let realmSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveState.id) else { return }

        try? realm.write {
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

    private func handleRealmChanges(_ changes: RealmCollectionChange<Results<PVSaveState>>) {
        switch changes {
        case .initial(let results), .update(let results, _, _, _):
            saveStatesSubject.send(convertRealmResults(results))
        case .error(let error):
            print("Error observing Realm changes: \(error)")
        }
    }

    private func convertRealmResults(_ results: Results<PVSaveState>) -> [SaveStateRowViewModel] {
        results.map { realmSaveState in
            let viewModel = SaveStateRowViewModel(
                gameID: realmSaveState.game.id,
                gameTitle: realmSaveState.game.title,
                saveDate: realmSaveState.date,
                thumbnailImage: Image(systemName: "gamecontroller"), // TODO: Load actual image
                description: nil // TODO: Add description support if needed
            )

            viewModel.isAutoSave = realmSaveState.isAutosave
            viewModel.isFavorite = realmSaveState.isFavorite
            viewModel.isPinned = realmSaveState.isPinned

            return viewModel
        }
    }
}
