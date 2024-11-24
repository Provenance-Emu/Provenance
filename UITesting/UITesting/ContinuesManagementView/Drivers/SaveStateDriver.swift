import Foundation
import Combine
import RealmSwift
import PVLibrary
import SwiftUI

/// Protocol defining the requirements for a save state driver
public protocol SaveStateDriver {
    /// Get all save states
    func getAllSaveStates() -> [SaveStateRowViewModel]

    /// Get save states filtered by game ID
    func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel]

    /// Update save state properties
    func update(saveState: SaveStateRowViewModel)

    /// Delete save states
    func delete(saveStates: [SaveStateRowViewModel])

    /// Publisher for save state changes
    var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> { get }
}

/// Mock driver for testing
public class MockSaveStateDriver: SaveStateDriver {
    private var saveStates: [SaveStateRowViewModel] = []
    private let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])

    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    public init(mockData: Bool = true) {
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
}
