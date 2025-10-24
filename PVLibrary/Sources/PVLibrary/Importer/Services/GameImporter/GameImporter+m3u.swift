//
//  GameImporter+m3u.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 5/14/25.
//

import RealmSwift
import Foundation

// MARK: M3U
extension GameImporter {
    // MARK: - M3U File Organization

    /// Main method to organize M3U files in the import queue
    internal func organizeM3UFiles(in importQueue: inout [ImportQueueItem]) {
        ILOG("Starting M3U organization...")
        var i = importQueue.count - 1

        while i >= 0 {
            let currentItem = importQueue[i]

            // Skip non-M3U files
            guard currentItem.url.pathExtension.lowercased() == Extensions.m3u.rawValue else {
                i -= 1
                continue
            }

            // Process this M3U file
            processM3UFile(currentItem, atIndex: i, in: &importQueue)

            i -= 1 // Move to the next item
        }

        ILOG("Finished M3U organization.")
    }

    /// Process a single M3U file and its associated files
    private func processM3UFile(_ m3uQueueItem: ImportQueueItem, atIndex index: Int, in importQueue: inout [ImportQueueItem]) {
        let m3uURL = m3uQueueItem.url
        ILOG("Processing M3U: \(m3uURL.lastPathComponent)")

        // Parse the M3U file
        guard let fileNamesInM3U = try? cdRomFileHandler.parseM3U(from: m3uURL) else {
            WLOG("Could not parse M3U file: \(m3uURL.lastPathComponent)")
            return
        }

        if fileNamesInM3U.isEmpty {
            WLOG("M3U file is empty or contains no valid entries: \(m3uURL.lastPathComponent)")
            return
        }

        ILOG("M3U \(m3uURL.lastPathComponent) contains the following files: \(fileNamesInM3U)")

        // Set up the primary game item (always the M3U itself)
        let primaryGameItem = setupPrimaryGameItem(m3uQueueItem)

        // Track items to be removed from the queue
        var indicesToRemove: [Int] = []

        // First scan the directory for all potentially related files
        let m3uDirectory = m3uURL.deletingLastPathComponent()
        scanDirectoryForRelatedFiles(m3uDirectory, primaryGameItem: primaryGameItem)

        // Check if any files listed in the M3U have already been imported to the database
        // This handles the case where the M3U arrives after its associated files
        Task {
            await checkForAlreadyImportedFiles(fileNamesInM3U, primaryGameItem: primaryGameItem, m3uURL: m3uURL)
        }

        // Process all files listed in the M3U
        processFilesListedInM3U(fileNamesInM3U, primaryGameItem: primaryGameItem, m3uURL: m3uURL,
                                importQueue: &importQueue, indicesToRemove: &indicesToRemove)

        // Check for files on disk
        checkForFilesOnDisk(fileNamesInM3U, primaryGameItem: primaryGameItem, m3uURL: m3uURL)

        // Process CUE files to find their BIN files
        processCUEFilesForBINs(primaryGameItem: primaryGameItem)

        // Finalize the primary game item
        finalizePrimaryGameItem(primaryGameItem, m3uURL: m3uURL)

        // Remove subsumed items from queue
        removeSubsumedItems(atIndex: index, indicesToRemove: indicesToRemove, from: &importQueue)

        VLOG("Finished processing M3U: \(m3uURL.lastPathComponent)")
    }

    /// Check if any files listed in the M3U have already been imported to the database
    /// This handles the case where the M3U arrives after its associated files
    private func checkForAlreadyImportedFiles(_ fileNames: [String], primaryGameItem: ImportQueueItem, m3uURL: URL) async {
        ILOG("Checking if any files in M3U \(m3uURL.lastPathComponent) have already been imported to the database")

        let realm = RomDatabase.sharedInstance.realm
        var filesToConsolidate: [PVFile] = []
        var gamesWithFilesToConsolidate = Set<PVGame>()

        // First check for exact filename matches
        for fileName in fileNames {
            // Look for files with matching names in the database
            let matchingFiles = realm.objects(PVFile.self).filter("fileName == %@", fileName)

            for file in matchingFiles {
                // Find games that have this file as their main file or in related files
                let gamesWithMainFile = realm.objects(PVGame.self).filter("file == %@", file)
                let gamesWithRelatedFile = realm.objects(PVGame.self).filter("ANY relatedFiles == %@", file)

                // Process games with this file as their main file
                for game in gamesWithMainFile {
                    ILOG("Found file \(fileName) as main file for game: \(game.title ?? "Unknown")")
                    filesToConsolidate.append(file)
                    gamesWithFilesToConsolidate.insert(game)
                }

                // Process games with this file in their related files
                for game in gamesWithRelatedFile {
                    ILOG("Found file \(fileName) as related file for game: \(game.title ?? "Unknown")")
                    filesToConsolidate.append(file)
                    gamesWithFilesToConsolidate.insert(game)
                }
            }
        }

        // If we didn't find any exact matches, look for similar filenames
        if filesToConsolidate.isEmpty {
            // Extract base game name from M3U filename
            let m3uBaseName = m3uURL.deletingPathExtension().lastPathComponent
            var baseNameWithoutDisc = m3uBaseName

            // Remove disc/CD indicators for matching
            let discIndicators = ["disc", "disk", "cd"]
            for indicator in discIndicators {
                if let range = baseNameWithoutDisc.lowercased().range(of: indicator, options: .caseInsensitive) {
                    let index = baseNameWithoutDisc.distance(from: baseNameWithoutDisc.startIndex, to: range.lowerBound)
                    if index > 3 { // Ensure we don't cut off too much of the name
                        baseNameWithoutDisc = String(baseNameWithoutDisc.prefix(index - 1))
                    }
                }
            }

            // Look for games with similar names
            let similarGames = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", baseNameWithoutDisc)

            for game in similarGames {
                ILOG("Found game with similar name: \(game.title ?? "Unknown")")
                gamesWithFilesToConsolidate.insert(game)

                // Add all files from this game to our consolidation list
                if let mainFile = game.file {
                    filesToConsolidate.append(mainFile)
                }

                for relatedFile in game.relatedFiles {
                    filesToConsolidate.append(relatedFile)
                }
            }
        }

        // If we found files to consolidate, update the database
        if !filesToConsolidate.isEmpty {
            await consolidateFilesUnderM3U(primaryGameItem, files: filesToConsolidate, games: Array(gamesWithFilesToConsolidate), m3uURL: m3uURL)
        } else {
            ILOG("No already imported files found for M3U \(m3uURL.lastPathComponent)")
        }
    }

    /// Consolidate already imported files under the M3U game
    private func consolidateFilesUnderM3U(_ primaryGameItem: ImportQueueItem, files: [PVFile], games: [PVGame], m3uURL: URL) async {
        ILOG("Consolidating \(files.count) files under M3U \(m3uURL.lastPathComponent)")

        do {
            // Step 1: Import the M3U file and find the corresponding game
            let game = try await findOrImportM3UGame(primaryGameItem: primaryGameItem, m3uURL: m3uURL)

            // Step 2: Consolidate all files under this game
            try await consolidateFilesUnderGame(game: game, files: files, games: games, m3uURL: m3uURL)

            ILOG("Successfully consolidated files under M3U game: \(game.title ?? "Unknown")")
        } catch {
            ELOG("Error consolidating files under M3U: \(error)")
        }
    }

    /// Import the M3U file and find the corresponding game in the database
    private func findOrImportM3UGame(primaryGameItem: ImportQueueItem, m3uURL: URL) async throws -> PVGame {
        // Import the M3U file itself to create a new game entry
        let importResult = try await gameImporterDatabaseService.importGameIntoDatabase(queueItem: primaryGameItem)

        // Find the game that was just imported using multiple strategies
        let m3uGame = try await findImportedGame(primaryGameItem: primaryGameItem, m3uURL: m3uURL)

        // Store the game ID for reference
        let gameID = m3uGame.id
        primaryGameItem.gameDatabaseID = gameID

        return m3uGame
    }

    /// Find the imported game using multiple search strategies
    private func findImportedGame(primaryGameItem: ImportQueueItem, m3uURL: URL) async throws -> PVGame {
        let m3uFileName = m3uURL.lastPathComponent
        let realm = RomDatabase.sharedInstance.realm
        var m3uGame: PVGame?

        // Strategy 1: Find by filename
        m3uGame = try await findGameByFileName(fileName: m3uFileName, realm: realm)

        // Strategy 2: Find by MD5 and system identifier
        if m3uGame == nil {
            m3uGame = try await findGameByMD5AndSystem(primaryGameItem: primaryGameItem, realm: realm)
        }

        // Strategy 3: Find by title and system identifier
        if m3uGame == nil {
            m3uGame = try await findGameByTitleAndSystem(m3uURL: m3uURL, primaryGameItem: primaryGameItem, realm: realm)
        }

        guard let game = m3uGame else {
            throw NSError(domain: "GameImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to find the imported M3U game in the database"])
        }

        return game
    }

    /// Find a game by filename
    private func findGameByFileName(fileName: String, realm: Realm) async throws -> PVGame? {
        // Look for PVFiles with matching URL and find their associated games
        let files = realm.objects(PVFile.self).filter("fileName == %@", fileName)

        for file in files {
            // Check games with this file as main file
            let gamesWithMainFile = realm.objects(PVGame.self).filter("file == %@", file)
            if let game = gamesWithMainFile.first {
                return game
            }

            // Check games with this file in related files
            let gamesWithRelatedFile = realm.objects(PVGame.self).filter("ANY relatedFiles == %@", file)
            if let game = gamesWithRelatedFile.first {
                return game
            }
        }

        return nil
    }

    /// Find a game by MD5 and system identifier
    private func findGameByMD5AndSystem(primaryGameItem: ImportQueueItem, realm: Realm) async throws -> PVGame? {
        guard let md5 = primaryGameItem.md5, !primaryGameItem.systems.isEmpty else {
            return nil
        }

        // Try each system identifier
        for systemID in primaryGameItem.systems {
            let games = realm.objects(PVGame.self).filter("md5Hash == %@ AND systemIdentifier == %@", md5, systemID.rawValue)
            if let game = games.first {
                return game
            }
        }

        return nil
    }

    /// Find a game by title and system identifier
    private func findGameByTitleAndSystem(m3uURL: URL, primaryGameItem: ImportQueueItem, realm: Realm) async throws -> PVGame? {
        guard !primaryGameItem.systems.isEmpty else {
            return nil
        }

        let title = m3uURL.deletingPathExtension().lastPathComponent

        // Try each system identifier
        for systemID in primaryGameItem.systems {
            let games = realm.objects(PVGame.self).filter("title == %@ AND systemIdentifier == %@", title, systemID.rawValue)
            if let game = games.first {
                return game
            }
        }

        return nil
    }

    /// Consolidate all files under the M3U game
    private func consolidateFilesUnderGame(game: PVGame, files: [PVFile], games: [PVGame], m3uURL: URL) async throws {
        let gameID = game.id

        let realm = RomDatabase.sharedInstance.realm

        try realm.write {
            // First, update the file paths to be in the same directory as the M3U
            let m3uDirectory = m3uURL.deletingLastPathComponent()

            for file in files {
                // Skip files already associated with this game
                if isFileAssociatedWithGame(file: file, game: game) {
                    continue
                }

                // Move the file to the M3U directory if needed
                moveFileToM3UDirectory(file: file, m3uDirectory: m3uDirectory)

                // Update file associations
                updateFileAssociations(file: file, game: game, gameID: gameID, realm: realm)
            }

            // Update the M3U game's metadata
            updateGameMetadata(game: game, games: games)

            // Clean up empty games
            cleanupEmptyGames(games: games, gameID: gameID, realm: realm)
        }
    }

    /// Check if a file is already associated with the game
    private func isFileAssociatedWithGame(file: PVFile, game: PVGame) -> Bool {
        let isMainFile = game.file == file
        let isRelatedFile = game.relatedFiles.contains(file)
        return isMainFile || isRelatedFile
    }

    /// Move a file to the M3U directory if needed
    private func moveFileToM3UDirectory(file: PVFile, m3uDirectory: URL) {
        // Get the current file URL
        guard let currentURL = file.url else { return }

        // Create the destination URL in the M3U directory
        let destinationURL = m3uDirectory.appendingPathComponent(currentURL.lastPathComponent)

        // Move the file if it's not already in the right location
        if currentURL != destinationURL && FileManager.default.fileExists(atPath: currentURL.path) {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Handle filename conflict
                    handleFileNameConflict(file: file, currentURL: currentURL, destinationURL: destinationURL, m3uDirectory: m3uDirectory)
                } else {
                    // Simple move
                    try FileManager.default.moveItem(at: currentURL, to: destinationURL)
                    // Update the file's partial path to reflect the new location
                    let newPartialPath = file.relativeRoot.createRelativePath(fromURL: destinationURL)
                    file.partialPath = newPartialPath
                    ILOG("Moved file from \(currentURL.path) to \(destinationURL.path)")
                }
            } catch {
                ELOG("Error moving file: \(error)")
            }
        }
    }
    
    /// Remove subsumed items from the queue
    internal func removeSubsumedItems(atIndex index: Int, indicesToRemove: [Int], from importQueue: inout [ImportQueueItem]) {
        // Sort indices in descending order to safely remove elements from the array
        let sortedIndicesToRemove = indicesToRemove.sorted(by: >)
        for indexToRemove in sortedIndicesToRemove {
            if indexToRemove < importQueue.count { // Safety check
                // Don't remove the M3U item itself - it's our primary game item now
                if indexToRemove == index {
                    continue
                }
                let removedItem = importQueue.remove(at: indexToRemove)
                ILOG("Removed \(removedItem.url.lastPathComponent) from queue as it was subsumed by M3U processing")
            }
        }
    }
}
