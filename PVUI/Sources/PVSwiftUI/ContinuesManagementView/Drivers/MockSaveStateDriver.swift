//
//  MockSaveStateDriver.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//

import Foundation
import Combine
import SwiftUI
import UIKit

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

    private var mockSaveSizes: [String: UInt64] = [:]

    public var savesSizePublisher: AnyPublisher<UInt64, Never> {
        saveStatesSubject.map { saveStates in
            saveStates.reduce(0) { $0 + (self.mockSaveSizes[$1.id] ?? 0) }
        }.eraseToAnyPublisher()
    }

    /// Game metadata
    public let gameTitle: String
    public let systemTitle: String
    public let savesTotalSize: Int
    public let gameUIImage: UIImage?

    public init(mockData: Bool = true,
                gameTitle: String = "Bomber Man",
                systemTitle: String = "Game Boy",
                savesTotalSize: Int = 2048,
                gameUIImage: UIImage? = nil) {
        self.gameTitle = gameTitle
        self.systemTitle = systemTitle
        self.savesTotalSize = savesTotalSize
        self.gameUIImage = gameUIImage

        if mockData {
            let mockStates = (0..<10).map { index -> SaveStateRowViewModel in
                let id = UUID().uuidString
                // Generate random size between 1MB and 10MB
                mockSaveSizes[id] = UInt64.random(in: 1_000_000...10_000_000)
                return SaveStateRowViewModel(
                    id: id,
                    gameID: "1",
                    gameTitle: "Pokemon Red",
                    saveDate: Date().addingTimeInterval(-Double(index * 86400)),
                    thumbnailImage: Image(systemName: "gamecontroller"),
                    description: "Save State \(index + 1)",
                    isAutoSave: index % 3 == 0,
                    isPinned: index < 2,
                    isFavorite: index % 2 == 0
                )
            }
            saveStates = mockStates
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
