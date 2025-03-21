import Foundation
import RealmSwift
import Combine
import PVLibrary
import SwiftUI
import PVUIBase
import PVMediaCache
import AsyncAlgorithms
import PVSettings
import Defaults

public class RealmSaveStateDriver: SaveStateDriver {
    /// The game ID to filter save states by
    public var gameId: String? {
        didSet {
            if oldValue != gameId {
                // Only set up observers if we're actually changing the filter
                // and if initial setup is complete
                if isInitialSetupComplete {
                    setupFilteredObservers()
                    updateSaveStates()
                }
            }
        }
    }

    /// The system ID to filter save states by when no game ID is specified
    private var systemId: String = "" {
        didSet {
            if oldValue != systemId {
                // Only set up observers if we're actually changing the filter
                // and if initial setup is complete
                if isInitialSetupComplete {
                    setupFilteredObservers()
                    updateSaveStates()
                }
            }
        }
    }

    /// The Realm configuration to use for creating Realm instances
    private let realmConfiguration: Realm.Configuration

    private var notificationToken: NotificationToken?

    /// Cache for save state view models to avoid repeated conversions
    private var viewModelCache: [String: SaveStateRowViewModel] = [:]

    /// Cache for thumbnail images to avoid repeated loading
    private var imageCache: [String: SwiftUI.Image] = [:]

    /// Queue for background processing
    private let processingQueue = DispatchQueue(label: "com.provenance.saveStateDriver.processing", qos: .userInitiated)

    /// Lock for thread-safe access to caches
    private let cacheLock = NSLock()

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

    /// Task for current conversion operation
    private var currentConversionTask: Task<Void, Never>?

    /// ID for the current task to track which task is active
    private var currentTaskId = UUID()

    /// Lock for task ID access
    private let taskLock = NSLock()

    /// Check if a task with the given ID is still the current task and not cancelled
    private func isTaskActive(_ taskId: UUID) -> Bool {
        taskLock.lock()
        defer { taskLock.unlock() }

        guard let currentTask = currentConversionTask else { return false }
        return taskId == currentTaskId && !currentTask.isCancelled
    }

    /// Flag to indicate if initial setup is complete
    private var isInitialSetupComplete = false

    /// Initialize with a specific Realm instance
    /// - Parameter realm: The Realm instance to use
    public init(realm: Realm) {
        /// Store the configuration from the provided Realm
        self.realmConfiguration = realm.configuration

        // Don't set up observers or update save states until explicitly requested
        // This prevents loading all save states on initialization
        isInitialSetupComplete = true
    }

    /// Initialize with a Realm configuration
    /// - Parameter configuration: The Realm configuration to use
    public init(configuration: Realm.Configuration) {
        self.realmConfiguration = configuration

        // Don't set up observers or update save states until explicitly requested
        // This prevents loading all save states on initialization
        isInitialSetupComplete = true
    }

    /// Default initializer that uses the default Realm configuration
    public convenience init() {
        self.init(configuration: Realm.Configuration.defaultConfiguration)
    }

    /// Deinitialize the driver
    deinit {
        notificationToken?.invalidate()

        taskLock.lock()
        currentConversionTask?.cancel()
        currentConversionTask = nil
        taskLock.unlock()
    }

    /// Get a thread-specific Realm instance using the stored configuration
    private func realm() -> Realm {
        do {
            return try Realm(configuration: realmConfiguration)
        } catch {
            /// If we can't create a Realm with the stored configuration, fall back to the default
            ELOG("Failed to create Realm with stored configuration: \(error.localizedDescription)")
            do {
                return try Realm()
            } catch {
                /// This should never happen in practice, but we need to handle it
                fatalError("Failed to create Realm: \(error.localizedDescription)")
            }
        }
    }

    /// Get the current filtered query based on game ID and system ID
    private func getFilteredQuery() -> Results<PVSaveState> {
        let realm = self.realm()
        var results = realm.objects(PVSaveState.self)

        // Apply game filter if specified
        if let gameId = self.gameId {
            results = results.filter("game.id == %@", gameId)
        }
        // Apply system filter if no game filter is specified and system filter is set
        else if !self.systemId.isEmpty {
            results = results.filter("game.systemIdentifier == %@", self.systemId)
        }

        return results
    }

    /// Setup observers for the filtered save states
    private func setupFilteredObservers() {
        // Cancel any existing notification token
        notificationToken?.invalidate()

        // Get the filtered query
        let results = getFilteredQuery()
        @ThreadSafe
        var theadSafeResults = results

        // Set up a new notification token for the filtered results
        notificationToken = results.observe { [weak self] changes in
            guard let self = self else { return }

            self.processingQueue.async {
                // Only clear caches for modified or deleted objects
                switch changes {
                case .initial:
                    // Initial load, no need to clear caches
                    break
                case .update(_, let deletions, let insertions, let modifications):
                    // Selectively clear caches for affected objects
                    self.clearCachesForChanges(deletions: deletions, insertions: insertions, modifications: modifications, from: theadSafeResults!)
                case .error(let error):
                    ELOG("Error observing save states: \(error)")
                    // On error, clear all caches to be safe
                    self.clearCaches()
                }

                // Update save states
                self.updateSaveStates()
            }
        }
    }

    /// Clear caches only for the affected objects
    /// - Parameters:
    ///   - deletions: The indices of the deletions
    ///   - insertions: The indices of the insertions
    ///   - modifications: The indices of the modifications
    ///   - results: The results of the query
    private func clearCachesForChanges(deletions: [Int], insertions: [Int], modifications: [Int], from results: Results<PVSaveState>) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // Handle deletions - we need to remove these from caches
        // Since we only have indices, we need to get the IDs from somewhere else
        // For deletions, we can only clear the entire cache since we don't know which objects were deleted
        if !deletions.isEmpty {
            viewModelCache.removeAll()
            sizeCache.removeAll()
            return
        }

        // For insertions and modifications, we can be more selective
        let modifiedIndices = Set(modifications + insertions)
        if !modifiedIndices.isEmpty {
            // Get the IDs of modified objects
            let modifiedIds = modifiedIndices.compactMap { index -> String? in
                guard index < results.count else { return nil }
                return results[index].id
            }

            // Remove modified objects from caches
            for id in modifiedIds {
                viewModelCache.removeValue(forKey: id)
                sizeCache.removeValue(forKey: id)
                // Keep image cache as images are unlikely to change
            }
        }
    }

    /// Clears all caches
    private func clearCaches() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        viewModelCache.removeAll()
        sizeCache.removeAll()
        // Keep image cache as images are unlikely to change
    }

    /// Calculate the total size for a set of save state IDs
    /// - Parameter ids: The IDs of the save states to calculate the total size for
    /// - Returns: The total size of the save states in bytes
    private func calculateTotalSize(for ids: [String]) -> UInt64 {
        cacheLock.lock()
        defer { cacheLock.unlock() }

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
            let realm = self.realm()
            let saveStates = realm.objects(PVSaveState.self).filter("id IN %@", missingIds)
            for saveState in saveStates {
                sizeCache[saveState.id] = saveState.size
                totalSize += saveState.size
            }

            // Start async calculation for more accurate sizes
            Task {
                await calculateSizesAsync(for: missingIds)
            }
        }

        return totalSize
    }

    /// Calculate sizes asynchronously for a set of save state IDs
    /// - Parameter ids: The IDs of the save states to calculate sizes for
    /// - Returns: A dictionary of save state IDs and their sizes
    private func calculateSizesAsync(for ids: [String]) async {
        let realm = self.realm()
        let saveStates = realm.objects(PVSaveState.self).filter("id IN %@", ids)
        let numberOfSaveStates = saveStates.count

        // Process in batches to avoid overwhelming the system
        let batchSize = 5
        var updatedSizes: [String: UInt64] = [:]
        var needsUIUpdate = false

        for i in stride(from: 0, to: numberOfSaveStates, by: batchSize) {
            let endIndex = min(i + batchSize, numberOfSaveStates)
            let batch = saveStates[i..<endIndex]

            // Process batch in parallel
            await withTaskGroup(of: (String, UInt64).self) { group in
                for saveState in batch {
                    group.addTask {
                        let size = await saveState.sizeAsync()
                        return (saveState.id, size)
                    }
                }

                // Collect results
                for await (id, size) in group {
                    cacheLock.lock()
                    let oldSize = sizeCache[id]
                    sizeCache[id] = size

                    // Check if size changed
                    if oldSize != size {
                        updatedSizes[id] = size
                        needsUIUpdate = true

                        // Update view model cache if it exists
                        if var viewModel = viewModelCache[id] {
                            viewModel.size = size
                            viewModelCache[id] = viewModel
                        }
                    }
                    cacheLock.unlock()
                }
            }
        }

        // Update UI if sizes changed
        if needsUIUpdate {
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // Send updated view models
                let currentViewModels = self.saveStatesSubject.value
                var updatedViewModels = currentViewModels

                // Update sizes in view models
                for i in 0..<updatedViewModels.count {
                    let id = updatedViewModels[i].id
                    if let newSize = updatedSizes[id] {
                        updatedViewModels[i].size = newSize
                    }
                }

                // Send updated models
                self.saveStatesSubject.send(updatedViewModels)
            }
        }
    }

    /// Update the save states
    private func updateSaveStates() {
        // Skip updates during initialization to avoid redundant work
        guard isInitialSetupComplete else { return }

        // Cancel any ongoing conversion task
        currentConversionTask?.cancel()

        // Generate a new task ID
        let taskId = UUID()
        taskLock.lock()
        currentTaskId = taskId
        taskLock.unlock()

        // Create a new task for this update
        let task = Task { [weak self] in
            guard let self = self else { return }

            // Get the filtered query
            @ThreadSafe
            var results = self.getFilteredQuery()

            // Check if the task is still active
            if !self.isTaskActive(taskId) { return }

            // First send quick results without images
            let initialViewModels = self.convertRealmResultsSync(results!)

            // Check if the task is still active
            if !self.isTaskActive(taskId) { return }

            await MainActor.run {
                // Only update if this task is still active
                if self.isTaskActive(taskId) {
                    self.saveStatesSubject.send(initialViewModels)
                }
            }

            // Check if the task is still active before proceeding with expensive image loading
            if !self.isTaskActive(taskId) { return }

            // Then convert results to view models asynchronously with images
            let viewModels = await self.convertRealmResults(results!, taskId: taskId)

            // Check if the task is still active
            if !self.isTaskActive(taskId) { return }

            // Update the subject on the main thread with complete data
            await MainActor.run {
                // Only update if this task is still active
                if self.isTaskActive(taskId) {
                    self.saveStatesSubject.send(viewModels)
                }
            }
        }

        // Store the task reference
        taskLock.lock()
        currentConversionTask = task
        taskLock.unlock()
    }

    /// Get all save states
    /// - Returns: An array of SaveStateRowViewModel objects
    public func getAllSaveStates() -> [SaveStateRowViewModel] {
        // Get the filtered query
        let results = getFilteredQuery()

        // For synchronous API, use the synchronous conversion
        return convertRealmResultsSync(results)
    }

    /// Synchronous version of convertRealmResults for backward compatibility
    /// - Parameter results: The Realm results to convert
    /// - Returns: An array of SaveStateRowViewModel objects
    private func convertRealmResultsSync(_ results: Results<PVSaveState>) -> [SaveStateRowViewModel] {
        // Filter out save states with no game
        let validResults = results.filter { $0.game != nil }

        // Process each save state, using cache where possible
        return validResults.map { realmSaveState -> SaveStateRowViewModel in
            cacheLock.lock()
            // Check if we already have this save state in cache
            if let cachedViewModel = viewModelCache[realmSaveState.id] {
                cacheLock.unlock()
                return cachedViewModel
            }
            cacheLock.unlock()

            // Get or create the thumbnail image
            let thumbnailImage: SwiftUI.Image

            cacheLock.lock()
            if let cachedImage = imageCache[realmSaveState.id] {
                thumbnailImage = cachedImage
                cacheLock.unlock()
            } else {
                cacheLock.unlock()

                // Try to get the image from the save state
                if let uiImage = realmSaveState.fetchUIImage() {
                    thumbnailImage = .init(uiImage: uiImage)

                    cacheLock.lock()
                    imageCache[realmSaveState.id] = thumbnailImage
                    cacheLock.unlock()
                } else {
                    // Use the game title for the missing artwork
                    let gameTitle = realmSaveState.game?.title ?? "Deleted"
                    let ratio = 1.0

//                    // Generate a cache key for the missing artwork
//                    let artworkStyle = Defaults[.missingArtworkStyle].description
//                    let missingArtworkKey = "missing_artwork_\(gameTitle)_\(ratio)_\(artworkStyle)"
//
//                    // Check if the missing artwork is already in PVMediaCache
//                    if PVMediaCache.fileExists(forKey: missingArtworkKey) {
//                        var cachedImage: UIImage?
//                        let semaphore = DispatchSemaphore(value: 0)
//
//                        PVMediaCache.shareInstance().image(forKey: missingArtworkKey) { _, image in
//                            cachedImage = image
//                            semaphore.signal()
//                        }
//
//                        _ = semaphore.wait(timeout: .now() + 0.5)
//
//                        if let image = cachedImage {
//                            thumbnailImage = .init(uiImage: image)
//                        } else {
//                            // Fallback to generating a new image
//                            let missingImage = UIImage.missingArtworkImage(gameTitle: gameTitle, ratio: 1)
//                            thumbnailImage = .init(uiImage: missingImage)
//
//                            // Cache the generated image
//                            try? PVMediaCache.writeImage(toDisk: missingImage, withKey: missingArtworkKey)
//                        }
//                    } else {
                        // Generate a new missing artwork image
                    let missingImage = UIImage.missingArtworkImage(gameTitle: gameTitle, ratio: ratio)
                        thumbnailImage = .init(uiImage: missingImage)

                        // Cache the generated image
//                        try? PVMediaCache.writeImage(toDisk: missingImage, withKey: missingArtworkKey)
//                    }

                    cacheLock.lock()
                    imageCache[realmSaveState.id] = thumbnailImage
                    cacheLock.unlock()
                }
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

            // Cache the size and view model
            cacheLock.lock()
            sizeCache[realmSaveState.id] = realmSaveState.size
            viewModelCache[realmSaveState.id] = viewModel
            cacheLock.unlock()

            return viewModel
        }
    }

    /// Get save states for a specific game ID
    /// - Parameter gameID: The ID of the game to get save states for
    /// - Returns: An array of SaveStateRowViewModel objects
    public func getSaveStates(forGameId gameID: String) -> [SaveStateRowViewModel] {
        // Get a thread-local Realm instance
        let realm = self.realm()
        return convertRealmResultsSync(realm.objects(PVSaveState.self).filter("game.id == %@", gameID))
    }

    /// Update the description of a save state
    /// - Parameters:
    ///   - saveStateId: The ID of the save state to update
    ///   - description: The new description
    public func updateDescription(saveStateId: String, description: String?) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Get a thread-local Realm instance
            let realm = self.realm()
            
            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }
            
            // Only update if the value is actually changing
            guard saveState.userDescription != description else { return }
            
            try? realm.write {
                saveState.userDescription = description
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Update cache if entry exists
                cacheLock.lock()
                var shouldUpdateUI = false
                if var cachedViewModel = viewModelCache[saveStateId] {
                    cachedViewModel.description = description ?? ""
                    viewModelCache[saveStateId] = cachedViewModel
                    shouldUpdateUI = true
                }
                cacheLock.unlock()
                
                // Update UI on main thread if needed
                if shouldUpdateUI {
                    // Instead of sending the entire value, update just the affected item
                    var currentSaveStates = self.saveStatesSubject.value
                    if let index = currentSaveStates.firstIndex(where: { $0.id == saveStateId }) {
                        currentSaveStates[index].description = description ?? ""
                        self.saveStatesSubject.send(currentSaveStates)
                    }
                }
            }
        }
    }

    /// Set the pin status of a save state
    /// - Parameters:
    ///   - saveStateId: The ID of the save state to update
    ///   - isPinned: The new pin status
    public func setPin(saveStateId: String, isPinned: Bool) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Get a thread-local Realm instance
            let realm = self.realm()

            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

            // Only update if the value is actually changing
            guard saveState.isPinned != isPinned else { return }

            try? realm.write {
                saveState.isPinned = isPinned
            }

            // Update cache if entry exists
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                cacheLock.lock()
                var shouldUpdateUI = false
                if var cachedViewModel = viewModelCache[saveStateId] {
                    cachedViewModel.isPinned = isPinned
                    viewModelCache[saveStateId] = cachedViewModel
                    shouldUpdateUI = true
                }
                cacheLock.unlock()
                
                // Update UI on main thread if needed
                if shouldUpdateUI {
                    // Instead of sending the entire value, update just the affected item
                    var currentSaveStates = self.saveStatesSubject.value
                    if let index = currentSaveStates.firstIndex(where: { $0.id == saveStateId }) {
                        currentSaveStates[index].isPinned = isPinned
                        self.saveStatesSubject.send(currentSaveStates)
                    }
                }
            }
        }
    }

    /// Set the favorite status of a save state
    /// - Parameters:
    ///   - saveStateId: The ID of the save state to update
    ///   - isFavorite: The new favorite status
    public func setFavorite(saveStateId: String, isFavorite: Bool) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Get a thread-local Realm instance
            let realm = self.realm()

            guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return }

            // Only update if the value is actually changing
            guard saveState.isFavorite != isFavorite else { return }

            try? realm.write {
                saveState.isFavorite = isFavorite
            }

            // Update cache if entry exists
            Task { @MainActor in
                self.cacheLock.lock()
                var shouldUpdateUI = false
                if var cachedViewModel = self.viewModelCache[saveStateId] {
                    cachedViewModel.isFavorite = isFavorite
                    self.viewModelCache[saveStateId] = cachedViewModel
                    shouldUpdateUI = true
                }
                self.cacheLock.unlock()

                // Update UI on main thread if needed
                if shouldUpdateUI {
                    Task { @MainActor in
                        // Instead of sending the entire value, update just the affected item
                        var currentSaveStates = self.saveStatesSubject.value
                        if let index = currentSaveStates.firstIndex(where: { $0.id == saveStateId }) {
                            currentSaveStates[index].isFavorite = isFavorite
                            self.saveStatesSubject.send(currentSaveStates)
                        }
                    }
                }
            }
        }
    }

    public func share(saveStateId: String) -> URL? {
        // Get a thread-local Realm instance
        let realm = self.realm()

        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveStateId) else { return nil }
        return saveState.file?.url
    }

    public func update(saveState: SaveStateRowViewModel) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Get a thread-local Realm instance
            let realm = self.realm()

            guard let realmSaveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveState.id) else { return }

            // Check if any values are actually changing
            let descriptionChanged = realmSaveState.userDescription != saveState.description
            let isPinnedChanged = realmSaveState.isPinned != saveState.isPinned
            let isFavoriteChanged = realmSaveState.isFavorite != saveState.isFavorite

            // Only update if something has changed
            guard descriptionChanged || isPinnedChanged || isFavoriteChanged else { return }

            try? realm.write {
                if descriptionChanged {
                    realmSaveState.userDescription = saveState.description
                }
                if isPinnedChanged {
                    realmSaveState.isPinned = saveState.isPinned
                }
                if isFavoriteChanged {
                    realmSaveState.isFavorite = saveState.isFavorite
                }
            }

            // Update cache
            cacheLock.lock()
            viewModelCache[saveState.id] = saveState
            cacheLock.unlock()

            // Update UI on main thread
            Task { @MainActor in
                // Instead of sending the entire value, update just the affected item
                var currentSaveStates = self.saveStatesSubject.value
                if let index = currentSaveStates.firstIndex(where: { $0.id == saveState.id }) {
                    currentSaveStates[index] = saveState
                    self.saveStatesSubject.send(currentSaveStates)
                }
            }
        }
    }

    public func delete(saveStates: [SaveStateRowViewModel]) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Get a thread-local Realm instance
            let realm = self.realm()

            let ids = saveStates.map { $0.id }
            let realmSaveStates = realm.objects(PVSaveState.self).filter("id IN %@", ids)

            try? realm.write {
                realm.delete(realmSaveStates)
            }

            // Remove from caches
            cacheLock.lock()
            defer { cacheLock.unlock() }

            for id in ids {
                viewModelCache.removeValue(forKey: id)
                imageCache.removeValue(forKey: id)
                sizeCache.removeValue(forKey: id)
            }
        }
    }

    public func loadSaveStates(forGameId gameID: String) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Clear system filter when loading for a specific game
            self.systemId = ""

            // Set game ID filter - this will trigger setupFilteredObservers via the property observer
            Task { @MainActor in
                // Only set up observers if we're changing the game ID
                if self.gameId != gameID {
                    self.gameId = gameID

                    // If property observer didn't trigger (e.g., if we're setting to the same value),
                    // explicitly set up observers and update
                    self.setupFilteredObservers()
                    self.updateSaveStates()
                }
            }
        }
    }

    /// Load all save states for a specific system
    /// If systemID is empty, load save states for all systems
    public func loadAllSaveStates(forSystemID systemID: String = "") {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // Clear any game ID filter and set system ID on the main thread
            Task { @MainActor in
                let gameIdChanged = self.gameId != nil
                let systemIdChanged = self.systemId != systemID

                // Clear game ID first to avoid redundant updates
                self.gameId = nil

                // Set system ID - this will trigger setupFilteredObservers via the property observer
                // only if the system ID is different
                self.systemId = systemID

                // If neither property observer triggered (e.g., if we're setting to the same values),
                // explicitly set up observers and update
                if !gameIdChanged && !systemIdChanged {
                    self.setupFilteredObservers()
                    self.updateSaveStates()
                }
            }
        }
    }

    /// Asynchronously convert Realm results to view models
    /// - Parameter results: The Realm results to convert
    /// - Parameter taskId: The ID of the task to track the task
    /// - Returns: An array of SaveStateRowViewModel objects
    private func convertRealmResults(_ results: Results<PVSaveState>, taskId: UUID) async -> [SaveStateRowViewModel] {
        // First get basic models without images (fast)
        var viewModels = convertRealmResultsSync(results)

        // Check if task was cancelled before proceeding with expensive image loading
        if !self.isTaskActive(taskId) { return viewModels }

        // Then load images and update sizes asynchronously
        await withTaskGroup(of: (String, SwiftUI.Image?, UInt64).self) { group in
            // Limit the number of concurrent image loading tasks to avoid overwhelming the system
            let maxConcurrentTasks = 5
            var tasksAdded = 0

            for (index, viewModel) in viewModels.enumerated() {
                // Check for cancellation before adding each task
                if !self.isTaskActive(taskId) { break }

                // Limit the number of concurrent tasks
                if tasksAdded >= maxConcurrentTasks { break }
                tasksAdded += 1

                group.addTask { [weak self] in
                    guard let self = self else { return (viewModel.id, nil, 0) }

                    // Check for cancellation before processing
                    if !self.isTaskActive(taskId) { return (viewModel.id, nil, viewModel.size) }

                    // Check if we already have the image in cache
                    self.cacheLock.lock()
                    let cachedImage = self.imageCache[viewModel.id]
                    self.cacheLock.unlock()

                    if let cachedImage = cachedImage {
                        // Use cached image
                        return (viewModel.id, cachedImage, viewModel.size)
                    } else {
                        // Check for cancellation before loading image from disk
                        if !self.isTaskActive(taskId) { return (viewModel.id, nil, viewModel.size) }

                        // Load image from disk
                        let realm = self.realm()
                        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: viewModel.id) else {
                            return (viewModel.id, nil, viewModel.size)
                        }

                        var image: SwiftUI.Image?
                        if let screenshot = saveState.image,
                           !screenshot.isInvalidated,
                           let url = screenshot.url,
                           let uiImage = UIImage(contentsOfFile: url.path) {
                            image = SwiftUI.Image(uiImage: uiImage)

                            // Check for cancellation before caching
                            if !self.isTaskActive(taskId) { return (viewModel.id, image, viewModel.size) }

                            // Cache the image
                            self.cacheLock.lock()
                            self.imageCache[viewModel.id] = image
                            self.cacheLock.unlock()
                        }

                        // Check for cancellation before getting size
                        if !self.isTaskActive(taskId) { return (viewModel.id, image, viewModel.size) }

                        // Get accurate size
                        let size = await saveState.sizeAsync()

                        // Check for cancellation before caching size
                        if !self.isTaskActive(taskId) { return (viewModel.id, image, size) }

                        // Cache the size
                        self.cacheLock.lock()
                        self.sizeCache[viewModel.id] = size
                        self.cacheLock.unlock()

                        return (viewModel.id, image, size)
                    }
                }
            }

            // Process results and update view models
            var updatedModels = [String: (image: SwiftUI.Image?, size: UInt64)]()

            for await (id, image, size) in group {
                // Check for cancellation before processing each result
                if !self.isTaskActive(taskId) { break }

                updatedModels[id] = (image, size)
            }

            // Check for cancellation before updating view models
            if !self.isTaskActive(taskId) { return }

            // Create a copy of the view models to update
            var updatedViewModels = viewModels

            // Update view models with loaded images and sizes on the main thread
            await MainActor.run {
                for i in 0..<updatedViewModels.count {
                    let id = updatedViewModels[i].id
                    if let updates = updatedModels[id] {
                        // Check for cancellation before each update
                        if !self.isTaskActive(taskId) { break }

                        if let image = updates.image {
                            updatedViewModels[i].thumbnail = image
                        }
                        updatedViewModels[i].size = updates.size

                        // Update cache
                        self.cacheLock.lock()
                        self.viewModelCache[id] = updatedViewModels[i]
                        self.cacheLock.unlock()
                    }
                }
            }

            // Update the original view models array with the updated values
            viewModels = updatedViewModels
        }

        // Return updated view models
        return viewModels
    }
}

// MARK: - Preview Support
@available(iOS 17.0, tvOS 17.0, watchOS 7.0, *)
extension RealmSaveStateDriver {
    /// Create a preview-friendly driver that doesn't use async methods
    /// This is used for SwiftUI previews which don't support async/await
    public static func previewDriver() -> any SaveStateDriver {
        // Use the mock driver for previews
        return MockSaveStateDriver(mockData: true)
    }
}

// MARK: - Preview Support
extension SaveStateRowViewModel {
    /// Create a preview-friendly view model
    /// This is used for SwiftUI previews which don't support async/await
    public static func previewViewModel() -> SaveStateRowViewModel {
        return SaveStateRowViewModel(
            id: UUID().uuidString,
            gameID: "preview-game",
            gameTitle: "Preview Game",
            saveDate: Date(),
            thumbnailImage: Image(systemName: "gamecontroller"),
            description: "Preview Save State",
            isAutoSave: false,
            isPinned: false,
            isFavorite: true,
            size: 1024 * 1024 // 1MB
        )
    }
}
