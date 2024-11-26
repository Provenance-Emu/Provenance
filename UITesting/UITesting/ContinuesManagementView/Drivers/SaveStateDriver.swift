import Foundation
import Combine
import RealmSwift
import PVLibrary
import SwiftUI

/// Protocol defining the requirements for a save state driver
public protocol SaveStateDriver: ObservableObject {
    /// Publisher for save state changes
    var saveStatesSubject: CurrentValueSubject<[SaveStateRowViewModel], Never> { get }
    var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> { get }

    /// Publisher for number of saves
    var numberOfSavesPublisher: AnyPublisher<Int, Never> { get }

    /// Publisher for total size of all save states in bytes
    var savesSizePublisher: AnyPublisher<UInt64, Never> { get }

    /// Get initial save states (for setup)
    func getAllSaveStates() -> [SaveStateRowViewModel]

    /// Get save states filtered by game ID
    func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel]

    /// Update save state properties
    func update(saveState: SaveStateRowViewModel)

    /// Delete save states
    func delete(saveStates: [SaveStateRowViewModel])

    /// Update save state description
    func updateDescription(saveStateId: String, description: String?)

    /// Set pin state
    func setPin(saveStateId: String, isPinned: Bool)

    /// Set favorite state
    func setFavorite(saveStateId: String, isFavorite: Bool)

    /// Share save state
    func share(saveStateId: String) -> URL?

    /// Load save states for a specific game
    func loadSaveStates(forGameId gameID: String)
}
