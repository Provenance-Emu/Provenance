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
    
    /// Collection of error messages for debugging
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
                        logMessage("Realm driver initialized but returned no data")
                        errorMessages.append("Realm database contains no games")
                        dataDriver = realmDriver // Still use the real driver to show empty state
                    }
                }
            } catch {
                logMessage("Failed to initialize data driver: \(error.localizedDescription)")
                errorMessages.append("Failed to initialize data: \(error.localizedDescription)")
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
            logMessage("No valid data driver after initialization")
            return createErrorContent()
        }
        
        // Check for error messages from the data driver
        if let realmDriver = dataDriver as? RealmTopShelfDataDriver, !realmDriver.errorMessages.isEmpty {
            // Add data driver error messages to our error messages
            for message in realmDriver.errorMessages {
                if !errorMessages.contains(message) {
                    errorMessages.append(message)
                    logMessage("Data driver error: \(message)")
                }
            }
        }
        
        // Create sections for different types of games
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        
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
            logMessage("No sections were created")
            return createErrorContent()
        }
        
        // Create the content with all sections
        let content = TVTopShelfSectionedContent(sections: sections)
        return content
    }
    
    // MARK: - Section Creation
    
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
        // Create a section for error messages
        var errorItems: [TVTopShelfSectionedItem] = []
        
        // Add each error message as an item
        for message in errorMessages {
            let item = TVTopShelfSectionedItem(identifier: "error_\(UUID().uuidString)")
            item.title = "Error: " + message
            errorItems.append(item)
        }
        
        // If no error messages, add a generic one
        let items: [TVTopShelfSectionedItem] = errorItems.isEmpty ? 
            [createErrorItem("No content available. Please open the app to add games.")] : 
            errorItems
        
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
    
    /// Logs a message to the system log and writes it to the log file
    private func logMessage(_ message: String) {
        // Log to system log
        os_log("%{public}@", log: logger, type: .debug, message)
        
        // Also write to a file in the shared container
        let fileManager = FileManager.default
        
        // Try multiple app group IDs to ensure we can write somewhere
        let appGroupIDs = [
            PVAppGroupId,
            "group.org.provenance-emu.provenance",
            "group.org.provenance-emu"
        ]
        
        var logCreated = false
        
        for appGroupID in appGroupIDs {
            guard !appGroupID.isEmpty else { continue }
            
            if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                // Try writing to multiple locations to ensure at least one works
                let possibleLocations = [
                    containerURL.appendingPathComponent("topshelf_log.txt"),
                    containerURL.appendingPathComponent("Library/topshelf_log.txt"),
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
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let timestamp = dateFormatter.string(from: Date())
                    
                    let logMessage = "\(timestamp): \(message)\n"
                    
                    do {
                        if fileManager.fileExists(atPath: logFileURL.path) {
                            // Append to existing file
                            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                                defer { fileHandle.closeFile() }
                                fileHandle.seekToEndOfFile()
                                if let data = logMessage.data(using: .utf8) {
                                    fileHandle.write(data)
                                    logCreated = true
                                    break
                                }
                            }
                        } else {
                            // Create new file
                            try logMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
                            logCreated = true
                            break
                        }
                    } catch {
                        // Try next location
                        continue
                    }
                }
                
                if logCreated {
                    break // Successfully wrote to a log file
                }
            }
        }
        
        // Add the message to the error messages array for display in the UI
        errorMessages.append(message)
    }
}
