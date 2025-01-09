import Foundation
import Combine
import RealmSwift
import PVLibrary
import SwiftUI

/// Protocol defining the requirements for a save state driver
public protocol SaveStateDriver: ObservableObject {
    /// The game ID to filter save states by
    var gameId: String? { get set }

    /// Publisher for save state changes
    var saveStatesSubject: CurrentValueSubject<[SaveStateRowViewModel], Never> { get }
    var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> { get }

    /// Publisher for number of saves
    var numberOfSavesPublisher: AnyPublisher<Int, Never> { get }

    /// Publisher for total size of all save states in bytes
    var savesSizePublisher: AnyPublisher<UInt64, Never> { get }

    /// Get initial save states (for setup)
    func getAllSaveStates() -> [SaveStateRowViewModel]

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
}
