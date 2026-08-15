//
//  ContentProvider.swift
//  TopShelfv2
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import TVServices
import os.log
import PVSupport
import PVLibrary
import RealmSwift

/// TopShelf extension for Provenance that displays the user's game library
class ContentProvider: TVTopShelfContentProvider {

    // MARK: - Properties

    /// Logger for debugging
    private let logger = OSLog(subsystem: "org.provenance-emu.provenance.topshelf", category: "ContentProvider")

    /// Maximum number of games to show in each section
    private let maxGamesPerSection = 10

    /// Maximum number of error messages retained for display. Bounded so a repeatedly
    /// failing extension can't grow this array for the lifetime of the process.
    private let maxErrorMessages = 5

    /// Collection of genuine failures, surfaced to the user by `createErrorContent()`.
    /// Only `recordError(_:)` writes here — routine logging must not.
    private var errorMessages: [String] = []

    /// Toggle between mock and real data (set to true for development/testing)
    #if DEBUG
    private let useMockData = false
    #else
    private let useMockData = false
    #endif

    /// Data driver for accessing game data
    private var dataDriver: TopShelfDataDriver?

    /// Task for tracking the initialization of the data driver
    private var initializationTask: Task<Void, Never>?

    // MARK: - Initialization

    override init() {
        super.init()
        logMessage("ContentProvider initializing")

        // Start the data driver initialization process
        initializationTask = initializeDataDriver()
    }

    // MARK: - Data Driver Setup

    /// Initializes the appropriate data driver based on the useMockData flag
    /// Returns a Task that can be awaited to ensure initialization is complete
    private func initializeDataDriver() -> Task<Void, Never> {
        return Task {
            do {
                logMessage("Starting data driver initialization")

                if useMockData {
                    logMessage("Using mock data driver for development")
                    let mockDriver = MockTopShelfDataDriver()
                    try await mockDriver.initialize()
                    dataDriver = mockDriver
                    logMessage("Mock data driver initialized successfully")
                } else {
                    // Use the real Realm driver without fallback
                    logMessage("Attempting to use Realm data driver")

                    let realmDriver = RealmTopShelfDataDriver()
                    try await realmDriver.initialize()

                    // Test if we can actually get data from the driver
                    let testGames = await realmDriver.getRecentlyAddedGames(limit: 1)

                    if !testGames.isEmpty {
                        // Real database works, use it
                        dataDriver = realmDriver
                        logMessage("Realm data driver initialized and working successfully")
                    } else {
                        // Real database initialized but returned no data
                        // An empty library is a normal state, not a failure — log it only,
                        // so the user gets the friendly "open the app" row instead of an error.
                        logMessage("Realm driver initialized but returned no data")
                        dataDriver = realmDriver // Still use the real driver to show empty state
                    }
                }
            } catch {
                recordError("Failed to initialize data: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - TopShelf Content Loading

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        logMessage("loadTopShelfContent requested")

        // Wait for the initialization task to complete if it's still running
        if let initTask = initializationTask {
            logMessage("Waiting for data driver initialization to complete")
            await initTask.value
            // Clear the task so we don't wait again next time
            initializationTask = nil
        }

        // Check if the data driver was successfully initialized
        guard let dataDriver = dataDriver else {
            recordError("No valid data driver after initialization")
            return createErrorContent()
        }

        // Merge in error messages from the data driver — `recordError` dedupes and caps
        if let realmDriver = dataDriver as? RealmTopShelfDataDriver {
            for message in realmDriver.errorMessages {
                recordError(message)
            }
        }

        // Create sections for different types of games
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        // Add recent save states section (first)
        if let recentSavesSection = await createRecentSavesSection(using: dataDriver) {
            sections.append(recentSavesSection)
            logMessage("Added recent saves section")
        }

        // Add recently played games section
        if let recentlyPlayedSection = await createRecentlyPlayedSection(using: dataDriver) {
            sections.append(recentlyPlayedSection)
            logMessage("Added recently played section")
        }

        // Add favorites section
        if let favoritesSection = await createFavoriteSection(using: dataDriver) {
            sections.append(favoritesSection)
            logMessage("Added favorites section")
        }

        // Add recently added games section
        if let recentlyAddedSection = await createRecentlyAddedSection(using: dataDriver) {
            sections.append(recentlyAddedSection)
            logMessage("Added recently added section")
        }

        // Check if we have any sections
        if sections.isEmpty {
            // Usually just an empty library — log it, and let `createErrorContent()` show
            // the friendly deep-link row alongside any real failures already recorded.
            logMessage("No sections were created")
            return createErrorContent()
        }

        // Create the content with all sections
        let content = TVTopShelfSectionedContent(sections: sections)
        return content
    }

    // MARK: - Section Creation

    /// Creates the Recent Saves section
    private func createRecentSavesSection(using driver: TopShelfDataDriver) async -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let saveStates = await driver.getRecentSaveStates(limit: maxGamesPerSection)

        let items = saveStates.compactMap { saveState -> TVTopShelfSectionedItem? in
            guard saveState.game != nil else { return nil }
            return saveState.topShelfItem()
        }

        if items.isEmpty {
            logMessage("No recent save states found")
            return nil
        }

        let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        collection.title = "Recent Saves"
        return collection
    }

    /// Creates the Recently Played section
    private func createRecentlyPlayedSection(using driver: TopShelfDataDriver) async -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        // Get recently played games from the driver
        let recentlyPlayedGames = await driver.getRecentlyPlayedGames(limit: maxGamesPerSection)

        // Map games to TopShelf items
        let items = recentlyPlayedGames.map { game -> TVTopShelfSectionedItem in
            return game.topShelfItem()
        }

        // If no items, return nil
        if items.isEmpty {
            logMessage("No recently played games found")
            return nil
        }

        // Create collection with title
        let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        collection.title = "Recently Played"
        return collection
    }

    /// Creates the Favorites section
    private func createFavoriteSection(using driver: TopShelfDataDriver) async -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        // Get favorite games from the driver
        let favoriteGames = await driver.getFavoriteGames(limit: maxGamesPerSection)

        // Map games to TopShelf items
        let items = favoriteGames.map { game -> TVTopShelfSectionedItem in
            return game.topShelfItem()
        }

        // If no items, return nil
        if items.isEmpty {
            logMessage("No favorite games found")
            return nil
        }

        // Create collection with title
        let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        collection.title = "Favorites"
        return collection
    }

    /// Creates the Recently Added section
    private func createRecentlyAddedSection(using driver: TopShelfDataDriver) async -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        // Get recently added games from the driver
        let recentlyAddedGames = await driver.getRecentlyAddedGames(limit: maxGamesPerSection)

        // Map games to TopShelf items
        let items = recentlyAddedGames.map { game -> TVTopShelfSectionedItem in
            return game.topShelfItem()
        }

        // If no items, return nil
        if items.isEmpty {
            logMessage("No recently added games found")
            return nil
        }

        // Create collection with title
        let collection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        collection.title = "Recently Added"
        return collection
    }

    // MARK: - Debug Content

    /// Creates error content for debugging
    private func createErrorContent() -> (any TVTopShelfContent)? {
        // Always lead with the deep-link item: it is the only actionable row in this section,
        // and an empty library is a more common reason to land here than an actual fault.
        var items: [TVTopShelfSectionedItem] = [
            createErrorItem("No content available. Please open the app to add games.")
        ]

        // Follow with any recorded failures
        for message in errorMessages {
            let item = TVTopShelfSectionedItem(identifier: "error_\(UUID().uuidString)")
            item.title = "Error: " + message
            items.append(item)
        }

        // Create a section with the error items
        let section = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: items)
        section.title = "Debugging Information"

        // Create the content with the error section
        let content = TVTopShelfSectionedContent(sections: [section])
        return content
    }

    /// Creates a generic error item
    private func createErrorItem(_ message: String) -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: "error_\(UUID().uuidString)")
        item.title = "Provenance TopShelf Debug: " + message

        // Add a deep link to open the app
        let url = URL(string: "provenance://")!
        item.imageShape = .square
        item.playAction = TVTopShelfAction(url: url)

        return item
    }

    // MARK: - Logging

    /// Timestamp formatter for the on-disk log. Hoisted out of `logMessage(_:)`, which
    /// previously rebuilt one on every write attempt.
    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    /// Destination of the on-disk log, resolved once per process. `static` so the search
    /// over app groups and candidate paths happens a single time, thread-safely, instead
    /// of on every log line.
    private static let logFileURL: URL? = resolveLogFileURL()

    /// Finds the first writable log location across the candidate app groups.
    private static func resolveLogFileURL() -> URL? {
        let fileManager = FileManager.default

        // Try multiple app group IDs to ensure we can write somewhere
        let appGroupIDs = [
            PVAppGroupId,
            "group.org.provenance-emu.provenance",
            "group.org.provenance-emu"
        ]

        for appGroupID in appGroupIDs {
            guard !appGroupID.isEmpty,
                  let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                continue
            }

            let possibleLocations = [
                containerURL.appendingPathComponent("topshelf_log.txt"),
                containerURL.appendingPathComponent("Library/topshelf_log.txt"),
                containerURL.appendingPathComponent("Caches/topshelf_log.txt"),
                containerURL.appendingPathComponent("Documents/topshelf_log.txt")
            ]

            for logFileURL in possibleLocations {
                // Create parent directory if needed
                let parentDir = logFileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: parentDir.path) {
                    do {
                        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
                    } catch {
                        continue // Try next location
                    }
                }

                if fileManager.fileExists(atPath: logFileURL.path) {
                    if fileManager.isWritableFile(atPath: logFileURL.path) {
                        return logFileURL
                    }
                } else if fileManager.createFile(atPath: logFileURL.path, contents: nil) {
                    return logFileURL
                }
            }
        }

        return nil
    }

    /// Logs a message to the system log and appends it to the log file.
    /// This is diagnostics only — it never affects what the user sees on the Top Shelf.
    /// Use `recordError(_:)` for failures that should be surfaced.
    private func logMessage(_ message: String) {
        // Log to system log
        os_log("%{public}@", log: logger, type: .debug, message)

        // Also append to the shared-container log. The file handle is opened and closed
        // within this call, so none is ever held across suspension.
        guard let logFileURL = Self.logFileURL,
              let fileHandle = try? FileHandle(forWritingTo: logFileURL) else {
            return
        }

        defer { try? fileHandle.close() }

        let data = Data("\(Self.logDateFormatter.string(from: Date())): \(message)\n".utf8)

        do {
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } catch {
            os_log("Failed to append to TopShelf log: %{public}@",
                   log: logger, type: .error, error.localizedDescription)
        }
    }

    /// Records a genuine failure: logs it *and* retains it for display in the Top Shelf
    /// error section. Every message here becomes a user-visible "Error: …" row, so only
    /// call it from real failure paths. Routine progress goes to `logMessage(_:)`.
    private func recordError(_ message: String) {
        // Always log, even when the display list is full or already holds this message —
        // the log file is the forensic trail and should stay complete.
        logMessage(message)

        guard errorMessages.count < maxErrorMessages,
              !errorMessages.contains(message) else {
            return
        }

        errorMessages.append(message)
    }
}
