//
//  MockSaveStateDriver.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//

import Foundation
import Combine
import SwiftUI

/// Mock driver for testing
@Observable
public class MockSaveStateDriver: SaveStateDriver {

    private var saveStates: [SaveStateRowViewModel] = []
    public let saveStatesSubject: CurrentValueSubject<[SaveStateRowViewModel], Never> = CurrentValueSubject([])
    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    public var numberOfSavesPublisher: AnyPublisher<Int, Never> {
        saveStatesSubject.map { $0.count }.eraseToAnyPublisher()
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
