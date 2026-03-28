/// RetroGameLibraryViewModel.swift
/// Provenance
///
/// Created by Joseph Mattiello on 4/6/25.
///

import SwiftUI
import PVThemes
import PVLibrary
import PVRealm
import RealmSwift
import PVMediaCache
import UniformTypeIdentifiers
import PVLogging
import PVSystems
import Combine
import Dispatch

/// ViewModel for RetroGameLibraryView to manage state and business logic
public class RetroGameLibraryViewModel: ObservableObject {
    // MARK: - Published Properties

    /// IDs to force view stability and prevent flickering
    @Published var importQueueUpdateID = UUID()
    @Published var importQueueItems: [ImportQueueItem] = [ImportQueueItem]()

    /// State to control the presentation of ImportStatusView
    @Published var showImportStatusView = false

    /// State to track expanded sections during the current session
    @Published var expandedSections: Set<String> = []

    /// Track search text
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    @Published var isSearching = false

    /// View mode and filter options
    @Published var selectedViewMode: ViewMode = .grid
    @Published var showFilterSheet = false
    @Published var selectedSortOption: SortOptions = .title

    /// Import status message
    @Published var importMessage: String? = nil
    @Published var showingImportMessage = false

    /// Control visibility of status messages
    @Published var showStatusMessages = true

    /// GameContextMenuDelegate properties
    @Published var showImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var gameToUpdateCover: PVGame?
    @Published var showingRenameAlert = false
    @Published var gameToRename: PVGame?
    @Published var newGameTitle = ""
    @Published var systemMoveState: RetroGameLibrarySystemMoveState?
    @Published var continuesManagementState: RetroGameLibraryContinuesManagementState?
    @Published var showArtworkSearch = false
    @Published var showArtworkSourceAlert = false

    /// Reference to the GameImporter for tracking import progress
    internal let gameImporter = GameImporter.shared

    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()

    private func setupImportQueueMonitoring() {
        // Create a timer that updates the UI every second when imports are active
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // Only trigger UI updates if there are active imports
                Task {
                    // Get the current import queue
                    let queue = await self.gameImporter.importQueue

                    // Only update if the queue has changed
                    if self.importQueueItems != queue {
                        // Update the state on the main thread
                        await MainActor.run {
                            self.importQueueItems = queue

                            // Only trigger UI updates if there are active imports
                            if !queue.isEmpty {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.importQueueUpdateID = UUID()
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Load expanded sections from AppStorage
    public func loadExpandedSections(from data: Data, allSystems: [PVSystem]) {
        DLOG("RetroGameLibraryViewModel: Loading expanded sections from AppStorage")

        // If no data is stored yet, keep all sections collapsed by default
        if data.isEmpty {
            DLOG("RetroGameLibraryViewModel: No expanded sections data found, keeping all sections collapsed by default")
            expandedSections = Set() // Empty set means all sections are collapsed
            return
        }

        // Otherwise decode the stored data
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            DLOG("RetroGameLibraryViewModel: Successfully decoded expanded sections: \(decoded)")
            expandedSections = decoded
        } else {
            ELOG("RetroGameLibraryViewModel: Failed to decode expanded sections data")
            // Fallback to keeping all sections collapsed
            expandedSections = Set() // Empty set means all sections are collapsed
        }
    }

    /// Toggle the expanded state of a section
    public func toggleSection(_ systemId: String) {
        DLOG("RetroGameLibraryViewModel: Toggling section: \(systemId)")

        /// Toggle the section state without animation wrapper to prevent focus issues on tvOS
        if expandedSections.contains(systemId) {
            expandedSections.remove(systemId)
            DLOG("RetroGameLibraryViewModel: Section collapsed: \(systemId)")
        } else {
            expandedSections.insert(systemId)
            DLOG("RetroGameLibraryViewModel: Section expanded: \(systemId)")
        }
        /// Note: The view is responsible for persisting to AppStorage via onChange
    }


    /// Save artwork for a game
    public func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("RetroGameLibraryViewModel: Saving artwork for game: \(game.title)")

        Task {
            do {
                let uniqueID = UUID().uuidString
                let md5: String = game.md5Hash ?? ""
                let key = "artwork_\(md5)_\(uniqueID)"
                DLOG("RetroGameLibraryViewModel: Generated key for image: \(key)")

                // Write image to disk
                try PVMediaCache.writeImage(toDisk: image, withKey: key)
                DLOG("RetroGameLibraryViewModel: Image successfully written to disk")

                // Update game's customArtworkURL in the database
                try RomDatabase.sharedInstance.writeTransaction {
                    let thawedGame = game.thaw()
                    DLOG("RetroGameLibraryViewModel: Game thawed: \(thawedGame?.title ?? "Unknown")")
                    thawedGame?.customArtworkURL = key
                    DLOG("RetroGameLibraryViewModel: Game's customArtworkURL updated to: \(key)")
                }
                DLOG("RetroGameLibraryViewModel: Database transaction completed successfully")

                // Sync artwork to CloudKit in background
                let gameMD5 = md5.uppercased()
                Task.detached(priority: .utility) {
                    if let gameToSync = await MainActor.run(body: {
                        RomDatabase.sharedInstance.game(withMD5: gameMD5)
                    }) {
                        do {
                            try await CloudSyncManager.shared.syncArtwork(for: gameToSync, artworkKey: key)
                            ILOG("RetroGameLibraryViewModel: Artwork synced to CloudKit for game: \(gameToSync.title)")
                        } catch {
                            ELOG("RetroGameLibraryViewModel: Failed to sync artwork to CloudKit: \(error.localizedDescription)")
                        }
                    }
                }

                // Verify image retrieval
                PVMediaCache.shareInstance().image(forKey: key) { retrievedKey, retrievedImage in
                    if let retrievedImage = retrievedImage {
                        DLOG("RetroGameLibraryViewModel: Successfully retrieved saved image for key: \(retrievedKey)")
                        DLOG("RetroGameLibraryViewModel: Retrieved image size: \(retrievedImage.size)")
                    } else {
                        DLOG("RetroGameLibraryViewModel: Failed to retrieve saved image for key: \(retrievedKey)")
                    }
                }
            } catch {
                ELOG("RetroGameLibraryViewModel: Failed to set custom artwork: \(error.localizedDescription)")
                ELOG("RetroGameLibraryViewModel: Error details: \(error)")
            }
        }
    }

    /// Show the GameMoreInfoView for a game
    @MainActor
    public func showGameInfo(gameId: String, appState: AppState) {
        DLOG("RetroGameLibraryViewModel: Showing game info for game ID: \(gameId)")

        /// Find the game by ID directly from database (single query, no observation)
        guard let game = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: gameId) else {
            ELOG("RetroGameLibraryViewModel: Could not find game with ID: \(gameId)")
            return
        }

        DLOG("RetroGameLibraryViewModel: Found game: \(game.title)")

        /// Create a view model for the game info view
        let driver = try! RealmGameLibraryDriver()
        let gameInfoViewModel = PagedGameMoreInfoViewModel(
            driver: driver,
            initialGameId: gameId,
            playGameCallback: { md5 in
                // TODO: Play game
            })

        /// Present the game info view as a sheet
        let gameInfoView = PagedGameMoreInfoView(viewModel: gameInfoViewModel)
            .environmentObject(appState)

        /// Use UIKit presentation for consistent behavior
        /// This approach ensures the view is presented properly regardless of the SwiftUI view hierarchy
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            DLOG("RetroGameLibraryViewModel: Presenting GameMoreInfoView using UIKit")
            let hostingController = UIHostingController(rootView: gameInfoView)
            hostingController.modalPresentationStyle = .fullScreen
            rootVC.present(hostingController, animated: true)
        } else {
            ELOG("RetroGameLibraryViewModel: Could not find root view controller to present GameMoreInfoView")
        }
    }

    // MARK: - Private Properties

    /// Cache for sorted games by system identifier to avoid repeated sorting
    private var cachedSystemGames: [String: [PVGame]] = [:]

    /// Cache for sorted all games
    private var cachedAllGamesSorted: [PVGame]?

    /// Last sort option used for caching
    private var lastCacheSortOption: SortOptions?

    /// Debouncing properties
    private let searchDebounceTime: TimeInterval = 0.3
    private var searchTextPublisher = PassthroughSubject<String, Never>()

    /// Timer for import queue updates
    private var importQueueTimer: AnyCancellable?

    // MARK: - Initialization

    public init() {
        setupSearchDebounce()
        setupImportQueueTimer()

        // Load status message visibility from UserDefaults
        showStatusMessages = UserDefaults.standard.bool(forKey: "ShowStatusMessages")

        // Save status message visibility when it changes
        $showStatusMessages
            .dropFirst() // Skip initial value
            .sink { [weak self] value in
                UserDefaults.standard.set(value, forKey: "ShowStatusMessages")
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    /// Filter games based on search text
    /// - Parameter games: The games to filter
    /// - Returns: Filtered array of games
    public func filterGames(_ games: [PVGame]) -> [PVGame] {
        guard !debouncedSearchText.isEmpty else { return games }

        return games.filter { game in
            game.title.lowercased().contains(debouncedSearchText.lowercased())
        }
    }

    // MARK: - Public Methods

    /// Import files from URLs
    public func importFiles(urls: [URL]) {
        // Skip empty URL arrays (happens when document picker is cancelled)
        if urls.isEmpty {
            VLOG("RetroGameLibraryViewModel: Skipping import for empty URL array (likely cancelled)")
            return
        }

        ILOG("RetroGameLibraryViewModel: Importing \(urls.count) files")

        // Use Task to move file operations off the main thread
        Task {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    ELOG("RetroGameLibraryViewModel: Could not access documents directory")
                    importMessage = "Error: Could not access documents directory"
                    showingImportMessage = true
                }
                return
            }

            // Create an Imports directory if it doesn't exist
            let importsDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
            } catch {
                await MainActor.run {
                    ELOG("RetroGameLibraryViewModel: Error creating Imports directory: \(error)")
                    importMessage = "Error creating Imports directory: \(error.localizedDescription)"
                    showingImportMessage = true
                }
                return
            }

            // Copy each file to the Imports directory
            var successCount = 0
            var errorMessages: [String] = []

            for url in urls {
                let destinationURL = importsDirectory.appendingPathComponent(url.lastPathComponent)

                do {
                    // Remove any existing file at the destination
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    // Copy the file
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    successCount += 1
                    ILOG("RetroGameLibraryViewModel: Successfully copied \(url.lastPathComponent) to Imports directory")
                } catch {
                    ELOG("RetroGameLibraryViewModel: Error copying file \(url.lastPathComponent): \(error)")
                    errorMessages.append("Error copying \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            // Show a message with the result on the main thread
            await MainActor.run {
                if successCount == urls.count {
                    importMessage = "Successfully imported \(successCount) file(s). The game importer will process them shortly."
                } else if successCount > 0 {
                    importMessage = "Imported \(successCount) of \(urls.count) file(s). Some files could not be imported."
                } else {
                    importMessage = "Failed to import any files. \(errorMessages.first ?? "Unknown error")"
                }

                showingImportMessage = true
            }
        }
    }

    /// Rename a game
    public func renameGame(_ game: PVGame, to newName: String) async {
        guard !newName.isEmpty else { return }
        await MainActor.run {
            do {
                try RomDatabase.sharedInstance.writeTransaction {
                    let primaryKey = game.md5Hash.uppercased()
                    guard let liveGame = RomDatabase.sharedInstance.realm.object(ofType: PVGame.self, forPrimaryKey: primaryKey) else {
                        return
                    }
                    liveGame.title = newName
                }
            } catch {
                ELOG("RetroGameLibraryViewModel: Failed to rename game: \(error)")
            }
        }
    }

    /// Move a game to a different system
    public func moveGame(_ game: PVGame, toSystem system: PVSystem) async {
        // Get a reference to the Realm
        guard let realm = try? await Realm() else {
            ELOG("Failed to open Realm for moving game")
            return
        }

        do {
            guard let sourceURL = PVEmulatorConfiguration.path(forGame: game) else {
                ELOG("Cannot move game with no path")
                return
            }

            let destinationURL = PVEmulatorConfiguration.romDirectory(forSystemIdentifier: system.identifier)
                .appendingPathComponent(sourceURL.lastPathComponent)

            // Save old values for cache cleanup
            let oldRomPath = game.romPath
            let oldSystemIdentifier = game.systemIdentifier
            let oldFileURL = game.file?.url
            let oldRelatedFiles = Array(game.relatedFiles.compactMap { $0.url })

            // Move the actual file first
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            DLOG("Successfully moved game file to new system directory: \(destinationURL.path)")

            var updatedGame: PVGame?
            try realm.write {
                guard !game.isInvalidated else { return }

                let thawedGame = game.thaw() ?? game
                thawedGame.system = system
                thawedGame.systemIdentifier = system.identifier

                // Update file path to new system directory
                let fileName = sourceURL.lastPathComponent
                let partialPath: String = (system.identifier as NSString).appendingPathComponent(fileName)
                thawedGame.romPath = partialPath
                DLOG("Updated game romPath to: \(partialPath)")

                // Update PVFile to point to the new location
                let newFile = PVFile(withURL: destinationURL)
                thawedGame.file = newFile
                DLOG("Updated PVFile to point to new location: \(newFile.partialPath)")

                DLOG("Successfully moved game \(thawedGame.title) to system \(system.name)")
                updatedGame = thawedGame
            }

            // Update cache: remove old entries and add new ones
            if let game = updatedGame {
                RomDatabase.removeGameFromCache(oldRomPath: oldRomPath, oldSystemIdentifier: oldSystemIdentifier, oldFileURL: oldFileURL, oldRelatedFiles: oldRelatedFiles)
                RomDatabase.addGameToCache(game)
                DLOG("Updated games cache after moving game to new system")
            }
        } catch {
            ELOG("Failed to move game: \(error)")
        }
    }

    /// Get encoded expanded sections data for saving to AppStorage
    public func getExpandedSectionsData() -> Data {
        let expandedArray = Array(expandedSections)
        return (try? JSONEncoder().encode(expandedArray)) ?? Data()
    }

    // MARK: - Games Caching

    /// Get cached sorted games for a system, computing and caching if needed
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - games: The RealmSwift List of games from the system
    ///   - sortOption: The current sort option
    /// - Returns: Sorted array of games
    public func cachedGamesForSystem(_ systemId: String, games: LinkingObjects<PVGame>, sortOption: SortOptions) -> [PVGame] {
        /// Invalidate cache if sort option changed
        if lastCacheSortOption != sortOption {
            invalidateGamesCache()
            lastCacheSortOption = sortOption
        }

        /// Return cached games if available
        if let cached = cachedSystemGames[systemId] {
            return cached
        }

        /// Compute sorted games and cache them
        let sorted = sortGames(Array(games), by: sortOption)
        cachedSystemGames[systemId] = sorted
        return sorted
    }

    /// Get cached sorted all games, computing and caching if needed
    /// - Parameters:
    ///   - games: Array of all games
    ///   - sortOption: The current sort option
    /// - Returns: Sorted array of games
    public func cachedAllGamesSorted(games: [PVGame], sortOption: SortOptions) -> [PVGame] {
        /// Invalidate cache if sort option changed
        if lastCacheSortOption != sortOption {
            invalidateGamesCache()
            lastCacheSortOption = sortOption
        }

        /// Return cached games if available
        if let cached = cachedAllGamesSorted {
            return cached
        }

        /// Compute sorted games and cache them
        let sorted = sortGames(games, by: sortOption)
        cachedAllGamesSorted = sorted
        return sorted
    }

    /// Invalidate all game caches
    public func invalidateGamesCache() {
        cachedSystemGames.removeAll()
        cachedAllGamesSorted = nil
        DLOG("RetroGameLibraryViewModel: Games cache invalidated")
    }

    /// Sort games based on sort option
    private func sortGames(_ games: [PVGame], by sortOption: SortOptions) -> [PVGame] {
        switch sortOption {
        case .title:
            return games.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .lastPlayed:
            return games.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .importDate:
            return games.sorted { $0.importDate > $1.importDate }
        case .mostPlayed:
            return games.sorted { $0.playCount > $1.playCount }
        }
    }

    // MARK: - Private Methods

    /// Set up debouncing for search text
    private func setupSearchDebounce() {
        DLOG("RetroGameLibraryViewModel: Setting up search text debouncing")

        // When searchText changes, send the value through the publisher
        $searchText
            .sink { [weak self] value in
                self?.searchTextPublisher.send(value)
                self?.isSearching = !value.isEmpty
            }
            .store(in: &cancellables)

        // Debounce the search text updates to prevent excessive filtering
        searchTextPublisher
            .debounce(for: .seconds(searchDebounceTime), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self = self else { return }

                VLOG("RetroGameLibraryViewModel: Debounced search text updated to: \(value)")

                // Update the debounced search text with animation
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.debouncedSearchText = value
                }
            }
            .store(in: &cancellables)
    }

    /// Set up direct subscription to the import queue
    private func setupImportQueueTimer() {
        ILOG("RetroGameLibraryViewModel: Setting up direct import queue subscription")

        // Get a publisher for the import queue
        // This is more efficient than polling and avoids the infinite loop
        gameImporter.importQueuePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] queue in
                guard let self = self else { return }

                // Always log the queue state for debugging
                if queue.isEmpty {
                    VLOG("RetroGameLibraryViewModel: Import queue is empty")
                } else {
                    let activeItems = queue.filter { !$0.status.isFailure } // Changed to use isFailure
                    ILOG("""
                         RetroGameLibraryViewModel: Import queue has \(queue.count) items
                         Active items: \(activeItems.count)
                         Statuses: \(queue.map { $0.status.description }.joined(separator: ", "))
                         """)
                }

                // Always update the queue items to ensure the view has the latest data
                self.importQueueItems = queue

                // Force a redraw if the queue has any items (not just active ones)
                // This ensures the view updates even if all items are completed or failed
                if !queue.isEmpty {
                    ILOG("RetroGameLibraryViewModel: Queue has items, updating UI")
                    // Update the ID to ensure the view redraws
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.importQueueUpdateID = UUID()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Enums and Supporting Types

/// View mode for the game library

// Enum for view modes
enum ViewMode: String, CaseIterable, Identifiable {
    case grid, list
    var id: Self { self }

    var iconName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

/// State for system move operations
public struct RetroGameLibrarySystemMoveState: Identifiable {
    public var id: String {
        guard !game.isInvalidated else { return "" }
        return "\(game.id)_\(Date().timeIntervalSince1970)"
    }

    let game: PVGame
    let availableSystems: [PVSystem]
    var isPresenting: Bool = true

    public init(game: PVGame, availableSystems: [PVSystem]) {
        self.game = game
        self.availableSystems = availableSystems
    }
}

/// State for continues management
public struct RetroGameLibraryContinuesManagementState: Identifiable {
    public var id: String {
        guard !game.isInvalidated else { return "" }
        return "\(game.id)_\(Date().timeIntervalSince1970)"
    }

    let game: PVGame
    var isPresenting: Bool = true
}
