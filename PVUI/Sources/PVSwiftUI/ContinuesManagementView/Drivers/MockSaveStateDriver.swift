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
@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
@Observable
public class MockSaveStateDriver: SaveStateDriver {

    /// The game ID to filter save states by
    public var gameId: String? {
        didSet {
            updateSaveStates()
        }
    }

    public let saveStatesSubject = CurrentValueSubject<[SaveStateRowViewModel], Never>([])
    public var saveStatesPublisher: AnyPublisher<[SaveStateRowViewModel], Never> {
        saveStatesSubject.eraseToAnyPublisher()
    }

    public var numberOfSavesPublisher: AnyPublisher<Int, Never> {
        saveStatesPublisher.map { $0.count }.eraseToAnyPublisher()
    }

    public var savesSizePublisher: AnyPublisher<UInt64, Never> {
        saveStatesPublisher.map { states in
            states.reduce(into: 0) { total, state in
                if let size = self.mockSaveSizes[state.id] {
                    total += size
                }
            }
        }.eraseToAnyPublisher()
    }

    private var allSaveStates: [SaveStateRowViewModel] = []
    /// Mock dictionary to store save state sizes separately from the view models
    private var mockSaveSizes: [String: UInt64] = [:]

    /// Game metadata
    public let gameTitle: String
    public let systemTitle: String
    public let savesTotalSize: Int
    public let gameUIImage: UIImage?

    /// System identifier for filtering
    private var systemIdentifier: String

    public init(mockData: Bool = true,
                gameTitle: String = "Bomber Man",
                systemTitle: String = "Game Boy",
                savesTotalSize: Int = 2048,
                gameUIImage: UIImage? = nil,
                systemIdentifier: String = "com.provenance.gameboy") {
        self.gameTitle = gameTitle
        self.systemTitle = systemTitle
        self.savesTotalSize = savesTotalSize
        self.gameUIImage = gameUIImage
        self.systemIdentifier = systemIdentifier

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
            allSaveStates = mockStates
            updateSaveStates()
        }
    }

    public init(mockSaveStates: [SaveStateRowViewModel] = [], systemIdentifier: String = "com.provenance.gameboy") {
        self.gameTitle = "Test Game"
        self.systemTitle = "Test System"
        self.savesTotalSize = 0
        self.gameUIImage = nil
        self.systemIdentifier = systemIdentifier
        self.allSaveStates = mockSaveStates
        // Initialize mock sizes for provided save states
        mockSaveStates.forEach { state in
            mockSaveSizes[state.id] = UInt64.random(in: 1_000_000...10_000_000)
        }
        updateSaveStates()
    }

    private func updateSaveStates() {
        if let gameId = gameId {
            let filtered = allSaveStates.filter { $0.gameID == gameId }
            saveStatesSubject.send(filtered)
        } else {
            saveStatesSubject.send(allSaveStates)
        }
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        if let gameId = gameId {
            return allSaveStates.filter { $0.gameID == gameId }
        }
        return allSaveStates
    }

    public func update(saveState: SaveStateRowViewModel) {
        if let index = allSaveStates.firstIndex(where: { $0.id == saveState.id }) {
            allSaveStates[index] = saveState
            updateSaveStates()
        }
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        // Remove sizes for deleted save states
        saveStates.forEach { state in
            mockSaveSizes.removeValue(forKey: state.id)
        }
        allSaveStates.removeAll(where: { saveState in
            saveStates.contains(where: { $0.id == saveState.id })
        })
        updateSaveStates()
    }

    public func updateDescription(saveStateId: String, description: String?) {
        if let index = allSaveStates.firstIndex(where: { $0.id == saveStateId }) {
            var updated = allSaveStates[index]
            updated.description = description
            allSaveStates[index] = updated
            updateSaveStates()
        }
    }

    public func setPin(saveStateId: String, isPinned: Bool) {
        if let index = allSaveStates.firstIndex(where: { $0.id == saveStateId }) {
            var updated = allSaveStates[index]
            updated.isPinned = isPinned
            allSaveStates[index] = updated
            updateSaveStates()
        }
    }

    public func setFavorite(saveStateId: String, isFavorite: Bool) {
        if let index = allSaveStates.firstIndex(where: { $0.id == saveStateId }) {
            var updated = allSaveStates[index]
            updated.isFavorite = isFavorite
            allSaveStates[index] = updated
            updateSaveStates()
        }
    }

    public func share(saveStateId: String) -> URL? {
        // Mock implementation returns nil
        return nil
    }

    /// Load save states for a specific game
    public func loadSaveStates(forGameId gameID: String) {
        // Set the game ID filter and update save states
        self.gameId = gameID
        // updateSaveStates() is called by the gameId property observer
    }

    /// Load all save states for a specific system
    /// If systemID is empty, load save states for all systems
    public func loadAllSaveStates(forSystemID systemID: String) {
        // Clear any game ID filter
        self.gameId = nil

        // In a real implementation, we would filter by system ID
        // For the mock, we'll just pretend all save states belong to the requested system
        // In a more sophisticated mock, we could store system IDs with each save state

        // For now, we'll just update the system identifier and return all save states
        self.systemIdentifier = systemID

        // updateSaveStates() is called by the gameId property observer
        // which will send all save states since gameId is nil
    }
}
