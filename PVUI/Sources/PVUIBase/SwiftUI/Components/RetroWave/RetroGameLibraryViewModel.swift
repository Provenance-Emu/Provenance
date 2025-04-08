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
import Perception

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

        // If no data is stored yet, expand all sections by default
        if data.isEmpty {
            DLOG("RetroGameLibraryViewModel: No expanded sections data found, expanding all sections by default")
            expandedSections = Set(allSystems.map { $0.systemIdentifier.rawValue })
            expandedSections.insert("all") // Also expand the "All Games" section
            return
        }

        // Otherwise decode the stored data
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            DLOG("RetroGameLibraryViewModel: Successfully decoded expanded sections: \(decoded)")
            expandedSections = decoded
        } else {
            ELOG("RetroGameLibraryViewModel: Failed to decode expanded sections data")
            // Fallback to expanding all sections
            expandedSections = Set(allSystems.map { $0.systemIdentifier.rawValue })
            expandedSections.insert("all") // Also expand the "All Games" section
        }
    }

    /// Toggle the expanded state of a section
    public func toggleSection(_ systemId: String) {
        DLOG("RetroGameLibraryViewModel: Toggling section: \(systemId)")

        // Use slightly longer animation to reduce perceived flickering
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedSections.contains(systemId) {
                expandedSections.remove(systemId)
                DLOG("RetroGameLibraryViewModel: Section collapsed: \(systemId)")
            } else {
                expandedSections.insert(systemId)
                DLOG("RetroGameLibraryViewModel: Section expanded: \(systemId)")
            }

            // Save the expanded sections to AppStorage
            saveExpandedSections()
        }
    }


    /// Save artwork for a game
    public func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("RetroGameLibraryViewModel: Saving artwork for game: \(game.title)")

        Task {
            do {
                let uniqueID = UUID().uuidString
                let md5: String = game.md5 ?? ""
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

        /// First, find the game by ID from all games
        guard let game = allGames.first(where: { $0.id == gameId }) else {
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


    /// Debouncing properties
    private let searchDebounceTime: TimeInterval = 0.3
    private var searchTextPublisher = PassthroughSubject<String, Never>()

    /// Timer for import queue updates
    private var importQueueTimer: AnyCancellable?

    // MARK: - Initialization

    public init() {
        setupSearchDebounce()
        setupImportQueueTimer()
    }

    // MARK: - Computed Properties

    /// All games in the library
    public var allGames: Results<PVGame> {
        RomDatabase.sharedInstance.all(PVGame.self)
    }

    /// Filtered games based on search text
    public var filteredGames: [PVGame] {
        guard !debouncedSearchText.isEmpty else { return Array(allGames) }

        return allGames.filter { game in
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

        // Get a reference to the Realm
        let realm = try? await Realm()

        // Update the game title
        try? realm?.write {
            game.thaw()?.title = newName
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
            try realm.write {
                guard !game.isInvalidated else { return }
                
                let thawedGame = game.thaw() ?? game
                thawedGame.systemIdentifier = system.identifier
                
                // Update any other system-specific properties if needed
                DLOG("Successfully moved game \(thawedGame.title) to system \(system.name)")
            }
        } catch {
            ELOG("Failed to move game: \(error)")
        }
    }

    /// Save expanded sections to AppStorage
    public func saveExpandedSections() {
        let expandedArray = Array(expandedSections)
        if let encodedData = try? JSONEncoder().encode(expandedArray) {
            // This needs to be handled by the view since AppStorage is a SwiftUI property wrapper
            Task { @MainActor in
                self.objectWillChange.send()
            }
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
                
                // Log queue state when it changes
                if queue.isEmpty {
                    VLOG("RetroGameLibraryViewModel: Import queue is empty")
                } else {
                    let activeItems = queue.filter { $0.status != .failure }
                    ILOG("""
                         RetroGameLibraryViewModel: Import queue has \(queue.count) items
                         Active items: \(activeItems.count)
                         Statuses: \(queue.map { $0.status.description }.joined(separator: ", "))
                         """)
                }
                
                // Check if the queue has changed
                let hasChanged = self.importQueueItems != queue
                
                // Only update if there's a change to avoid unnecessary view updates
                if hasChanged {
                    // Update the queue
                    self.importQueueItems = queue
                    
                    // Force a redraw if the queue has active items
                    let hasActiveItems = !queue.isEmpty && queue.contains(where: { $0.status != .failure })
                    
                    if hasActiveItems {
                        ILOG("RetroGameLibraryViewModel: Queue has active items, updating UI")
                        // Update the ID to ensure the view redraws
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.importQueueUpdateID = UUID()
                        }
                    } else {
                        ILOG("RetroGameLibraryViewModel: Queue changed but no active items")
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
