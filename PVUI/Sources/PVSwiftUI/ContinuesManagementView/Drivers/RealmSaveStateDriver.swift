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

    /// The system ID to filter save states by when no game ID is specified
    private var systemId: String = ""

    private let realm: Realm
    private var notificationToken: NotificationToken?

    /// Cache for save state view models to avoid repeated conversions
    private var viewModelCache: [String: SaveStateRowViewModel] = [:]

    /// Cache for thumbnail images to avoid repeated loading
    private var imageCache: [String: SwiftUI.Image] = [:]

    /// Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.provenance.saveStateDriver.processing", qos: .userInitiated)

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
        saveStatesSubject.map { [weak self] saveStates in
            guard let self = self else { return 0 }

            // Use cached size calculation if available
            let ids = saveStates.map { $0.id }
            return self.calculateTotalSize(for: ids)
        }.eraseToAnyPublisher()
    }

    /// Cache for save state sizes to avoid repeated calculations
    private var sizeCache: [String: UInt64] = [:]

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
            self?.processingQueue.async {
                self?.clearCaches()
                self?.updateSaveStates()
            }
        }
        updateSaveStates()
    }

    /// Clears all caches when data changes
    private func clearCaches() {
        viewModelCache.removeAll()
        sizeCache.removeAll()
        // Keep image cache as images are unlikely to change
    }

    /// Calculate the total size for a set of save state IDs
    private func calculateTotalSize(for ids: [String]) -> UInt64 {
        // First check if we have all sizes in cache
        var totalSize: UInt64 = 0
        var missingIds: [String] = []

        for id in ids {
            if let cachedSize = sizeCache[id] {
                totalSize += cachedSize
            } else {
                missingIds.append(id)
            }
        }

        // If we have missing IDs, fetch them from Realm
        if !missingIds.isEmpty {
            let saveStates = realm.objects(PVSaveState.self).filter("id IN %@", missingIds)
            for saveState in saveStates {
                sizeCache[saveState.id] = saveState.size
                totalSize += saveState.size
            }
        }

        return totalSize
    }

    private func updateSaveStates() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Prepare the query
            var results = self.realm.objects(PVSaveState.self)

            // Apply game filter if specified
            if let gameId = self.gameId {
                results = results.filter("game.id == %@", gameId)
            }
            // Apply system filter if no game filter is specified and system filter is set
            else if !self.systemId.isEmpty {
                results = results.filter("game.systemIdentifier == %@", self.systemId)
            }

            // Convert results to view models (using cache where possible)
            let viewModels = self.convertRealmResults(results)

            // Update the subject on the main thread
            DispatchQueue.main.async {
                self.saveStatesSubject.send(viewModels)
            }
        }
    }

    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        var results = realm.objects(PVSaveState.self)

        // Apply game filter if specified
        if let gameId = gameId {
            results = results.filter("game.id == %@", gameId)
        }
        // Apply system filter if no game filter is specified and system filter is set
        else if !systemId.isEmpty {
            results = results.filter("game.systemIdentifier == %@", systemId)
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

        // Update cache if entry exists
        if var cachedViewModel = viewModelCache[saveStateId] {
            cachedViewModel.description = description
            viewModelCache[saveStateId] = cachedViewModel
        }
    }

    public func setPin(saveStateId: String, isPinned: Bool) {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

        try? realm.write {
            saveState.isPinned = isPinned
        }

        // Update cache if entry exists
        if var cachedViewModel = viewModelCache[saveStateId] {
            cachedViewModel.isPinned = isPinned
            viewModelCache[saveStateId] = cachedViewModel
        }
    }

    public func setFavorite(saveStateId: String, isFavorite: Bool) {
        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

        try? realm.write {
            saveState.isFavorite = isFavorite
        }

        // Update cache if entry exists
        if var cachedViewModel = viewModelCache[saveStateId] {
            cachedViewModel.isFavorite = isFavorite
            viewModelCache[saveStateId] = cachedViewModel
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

        // Update cache
        viewModelCache[saveState.id] = saveState
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        let ids = saveStates.map { $0.id }
        let realmSaveStates = realm.objects(PVSaveState.self).filter("id IN %@", ids)

        try? realm.write {
            realm.delete(realmSaveStates)
        }

        // Remove from caches
        for id in ids {
            viewModelCache.removeValue(forKey: id)
            imageCache.removeValue(forKey: id)
            sizeCache.removeValue(forKey: id)
        }
    }

    public func loadSaveStates(forGameId gameID: String) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Clear system filter when loading for a specific game
            self.systemId = ""

            // Set game ID filter
            DispatchQueue.main.async {
                self.gameId = gameID
            }

            // Note: updateSaveStates() will be called by the gameId property observer
        }
    }

    /// Load all save states for a specific system
    /// If systemID is empty, load save states for all systems
    public func loadAllSaveStates(forSystemID systemID: String) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Store the system ID for future updates
            self.systemId = systemID

            // Clear any game ID filter
            DispatchQueue.main.async {
                self.gameId = nil
            }

            // Get all save states from Realm
            var results = self.realm.objects(PVSaveState.self)

            // If a valid system ID is provided, filter by that system
            if !systemID.isEmpty {
                results = results.filter("game.systemIdentifier == %@", systemID)
            }
            // Otherwise, return all save states (no additional filtering)

            let viewModels = self.convertRealmResults(results)

            // Send the results to the subject
            DispatchQueue.main.async {
                self.saveStatesSubject.send(viewModels)
            }
        }
    }

    private func convertRealmResults(_ results: Results<PVSaveState>) -> [SaveStateRowViewModel] {
        // Filter out save states with no game
        let validResults = results.filter { $0.game != nil }

        // Process each save state, using cache where possible
        return validResults.map { realmSaveState -> SaveStateRowViewModel in
            // Check if we already have this save state in cache
            if let cachedViewModel = viewModelCache[realmSaveState.id] {
                return cachedViewModel
            }

            // Get or create the thumbnail image
            let thumbnailImage: SwiftUI.Image
            if let cachedImage = imageCache[realmSaveState.id] {
                thumbnailImage = cachedImage
            } else if let uiImage = realmSaveState.fetchUIImage() {
                thumbnailImage = .init(uiImage: uiImage)
                imageCache[realmSaveState.id] = thumbnailImage
            } else {
                thumbnailImage = .init(uiImage: UIImage.missingArtworkImage(gameTitle: realmSaveState.game?.title ?? "Deleted", ratio: 1))
                imageCache[realmSaveState.id] = thumbnailImage
            }

            // Create the view model
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

            // Cache the size
            sizeCache[realmSaveState.id] = realmSaveState.size

            // Cache the view model
            viewModelCache[realmSaveState.id] = viewModel

            return viewModel
        }
    }
}
