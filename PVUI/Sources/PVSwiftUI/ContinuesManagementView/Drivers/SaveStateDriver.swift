import Foundation
import Combine
import RealmSwift
import PVLibrary
import SwiftUI

/// Protocol defining the requirements for a save state driver
public protocol SaveStateDriver {
    /// Publisher for save state changes
    var saveStatesSubject: CurrentValueSubject<[SaveStateRowViewModel], Never> { get }
    var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> { get }

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

/// Mock driver for testing
public class MockSaveStateDriver: SaveStateDriver {
    private var saveStates: [SaveStateRowViewModel] = []
    public let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])
    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    /// Game metadata
    public let gameTitle: String
    public let systemTitle: String
    public let gameSize: Int
    public let gameImage: Image

    public init(mockData: Bool = true,
                gameTitle: String = "Bomber Man",
                systemTitle: String = "Game Boy",
                gameSize: Int = 2048,
                gameImage: Image = Image(systemName: "gamecontroller")) {
        self.gameTitle = gameTitle
        self.systemTitle = systemTitle
        self.gameSize = gameSize
        self.gameImage = gameImage

        if mockData {
            saveStates = createMockSaveStates()
            saveStatesSubject.send(saveStates)
        }
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        saveStates
    }

    public func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel] {
        saveStates.filter { $0.gameID == gameID }
    }

    public func update(saveState: SaveStateRowViewModel) {
        if let index = saveStates.firstIndex(where: { $0.id == saveState.id }) {
            saveStates[index] = saveState
            saveStatesSubject.send(saveStates)
        }
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        self.saveStates.removeAll(where: { saveState in
            saveStates.contains(where: { $0.id == saveState.id })
        })
        saveStatesSubject.send(self.saveStates)
    }

    /// Creates mock save states for testing
    private func createMockSaveStates() -> [SaveStateRowViewModel] {
        let dates = (-5...0).map { days in
            Date().addingTimeInterval(TimeInterval(days * 24 * 3600))
        }

        return dates.enumerated().map { index, date in
            let saveState = SaveStateRowViewModel(
                gameID: "1",
                gameTitle: "Test Game",
                saveDate: date,
                thumbnailImage: Image(systemName: "gamecontroller"),
                description: index % 2 == 0 ? "Save \(index + 1)" : nil
            )

            saveState.isAutoSave = index % 3 == 0
            saveState.isFavorite = index % 4 == 0
            saveState.isPinned = index % 5 == 0

            return saveState
        }
    }

    public func updateDescription(saveStateId: String, description: String?) {
        if let index = saveStates.firstIndex(where: { $0.id == saveStateId }) {
            saveStates[index].description = description
            saveStatesSubject.send(saveStates)
        }
    }

    public func setPin(saveStateId: String, isPinned: Bool) {
        if let index = saveStates.firstIndex(where: { $0.id == saveStateId }) {
            saveStates[index].isPinned = isPinned
            saveStatesSubject.send(saveStates)
        }
    }

    public func setFavorite(saveStateId: String, isFavorite: Bool) {
        if let index = saveStates.firstIndex(where: { $0.id == saveStateId }) {
            saveStates[index].isFavorite = isFavorite
            saveStatesSubject.send(saveStates)
        }
    }

    public func share(saveStateId: String) -> URL? {
        // Implementation for sharing save state
        return nil
    }

    public func loadSaveStates(forGameId gameID: String) {
        let states = getAllSaveStates()
        saveStatesSubject.send(states)
    }
}
