//
//  File.swift
//  PVLibrary
//
//  Created by David Proskin on 11/5/24.
//

import Foundation
import PVSupport
import RealmSwift
import PVCoreLoader
import AsyncAlgorithms
import PVPlists
import PVLookup
import PVSystems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm
import PVHashing
import CommonCrypto
import Perception
import SwiftUI
import PVLookupTypes

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

public protocol GameImporterDatabaseServicing {
    typealias GameType = PVGame

    func setRomsPath(url:URL)
    func importGameIntoDatabase(queueItem: ImportQueueItem) async throws
    func importBIOSIntoDatabase(queueItem: ImportQueueItem) async throws
    func getUpdatedGameInfo(for game: GameType, forceRefresh: Bool) async throws -> GameType
    func getArtwork(forGame game: GameType) async -> GameType
}

extension CharacterSet {
    var GameImporterDatabaseServiceCharset: CharacterSet {
        _GameImporterDatabaseServiceCharset
    }
}
fileprivate let _GameImporterDatabaseServiceCharset: CharacterSet = {
    var c = CharacterSet.punctuationCharacters
    c.remove(charactersIn: ",-+&.'")
    return c
}()

class GameImporterDatabaseService : GameImporterDatabaseServicing {


    var romsPath:URL?
    private let lookup: PVLookup
    private let gameImporterFileService: GameImporterFileServicing

    init(lookup: PVLookup = .shared,
         gameImporterFileService: GameImporterFileServicing = GameImporterFileService()) {
        self.lookup = lookup
        self.gameImporterFileService = gameImporterFileService
    }

    func setRomsPath(url: URL) {
        romsPath = url
    }

//    @MainActor
    internal func importGameIntoDatabase(queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType != .bios else {
            return
        }

        guard let targetSystem = await queueItem.targetSystem() else {
            throw GameImporterError.systemNotDetermined
        }

        //TODO: is it an error if we don't have the destination url at this point?
        guard let destUrl = queueItem.destinationUrl else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        DLOG("Attempting to import game: \(destUrl.lastPathComponent) for system: \(targetSystem.libretroDatabaseName)")

        #if !os(tvOS)
        // Check if this file is currently being recovered from iCloud (async — avoids semaphore deadlock)
        if await iCloudDriveSync.isFileBeingRecovered(queueItem.url.path) {
            ILOG("File \(queueItem.url.lastPathComponent) is currently being recovered from iCloud. Delaying import.")

            // Re-queue this item with a delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                do {
                    try await importGameIntoDatabase(queueItem: queueItem)
                } catch {
                    ELOG("Error re-importing game after delay: \(error)")
                }
            }
            return
        }
        #endif

        let filename = queueItem.url.lastPathComponent
        let partialPath = (targetSystem.rawValue as NSString).appendingPathComponent(filename)
        let similarName = RomDatabase.altName(queueItem.url, systemIdentifier: targetSystem)

        DLOG("Checking game cache for partialPath: \(partialPath) or similarName: \(similarName)")
        let gamesCache = RomDatabase.gamesCache

        // Check if the file is already in the correct location and has a database entry
        let isInCorrectLocation = destUrl.path == queueItem.url.path

        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
           targetSystem.rawValue == existingGame.systemIdentifier {
            DLOG("Found existing game in cache: \(existingGame.title)")

            // If the game already has a valid file and is in the correct location, we can skip further processing
            if isInCorrectLocation && existingGame.file != nil {
                ILOG("Game \(existingGame.title) already has a database entry with a valid file and is in the correct location, skipping import")
                return
            }

            // Otherwise, just update the relative path
            DLOG("Updating relative path for existing game")
            await saveRelativePath(existingGame, partialPath: partialPath, file: queueItem.url)
            return
        } else {
            // Check if this is a duplicate by MD5 hash (async to avoid blocking)
            if let md5 = (await queueItem.md5Async())?.uppercased() {
                let matchingGame: PVGame? = try? await RealmContext.withRealm { realm in
                    realm.objects(PVGame.self)
                        .filter("md5Hash == %@", md5)
                        .first?
                        .freeze()
                }

                if let existingGameWithSameMD5 = matchingGame,
                   targetSystem.rawValue == existingGameWithSameMD5.systemIdentifier {
                    ILOG("Found existing game with same MD5 hash: \(existingGameWithSameMD5.title), updating relative path")
                    await saveRelativePath(existingGameWithSameMD5, partialPath: partialPath, file: queueItem.url)
                    return
                }
            }

            DLOG("No existing game found, starting import to database")
            // Pass resolved associated files (bin/cue for m3u, etc.) so they are persisted as
            // related files even when the filesystem cache is stale after a fresh import.
            let resolvedFiles = queueItem.resolvedAssociatedFileURLs.isEmpty ? nil : queueItem.resolvedAssociatedFileURLs
            try await self.importToDatabaseROM(forItem: queueItem, system: targetSystem, relatedFiles: resolvedFiles)
        }
    }

//    @MainActor
    func importBIOSIntoDatabase(queueItem: ImportQueueItem) async throws {
        ILOG("Starting BIOS database import for: \(queueItem.url.lastPathComponent)")

        // FileService will move/copy the file and post notifications for each new file location.
        try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: queueItem)
        // ILOG("Moved BIOS file to destination: \(queueItem.destinationUrl?.path ?? "unknown")")

        // BIOSWatcher is now notified by GameImporterFileService directly after each successful copy.
        // No longer need to call processBIOSFiles from here.
        ILOG("BIOS file handling delegated to GameImporterFileService for \(queueItem.url.lastPathComponent). Notifications are handled therein.")
    }

    /// Imports a ROM to the database
//    @MainActor
    internal func importToDatabaseROM(forItem queueItem: ImportQueueItem, system systemID: SystemIdentifier, relatedFiles: [URL]?) async throws {

        guard let destinationUrl = queueItem.destinationUrl else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        DLOG("Starting database ROM import for: \(queueItem.url.lastPathComponent)")
        let filename = queueItem.url.lastPathComponent
        let filenameSansExtension = queueItem.url.deletingPathExtension().lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
        let destinationDir = (systemID.rawValue as NSString)
        let partialPath: String = (systemID.rawValue as NSString).appendingPathComponent(filename)

        DLOG("Creating game object with title: \(title), partialPath: \(partialPath)")

        // Fetch system data on main thread to get related file info
        let (files, name) = try await RealmContext.withBackgroundRealm { realm -> ([URL], String) in
            guard let system = realm.object(ofType: PVSystem.self, forPrimaryKey: systemID.rawValue) else {
                throw GameImporterError.noSystemMatched
            }

            let filesCache = RomDatabase.getFileSystemROMCache(for: system)
            let files = Array(filesCache.keys)
            let name = RomDatabase.altName(queueItem.url, systemIdentifier: systemID)

            return (files, name)
        }

        // Create game as unmanaged object - system will be linked in saveGame
        let file = PVFile(withURL: destinationUrl)
        let game = PVGame()
        game.file = file
        game.systemIdentifier = systemID.rawValue
        game.romPath = partialPath
        game.title = title
        game.requiresSync = true

        DLOG("Searching for related files with name: \(name) among \(files.count) cached files")

        // Optimize: Use synchronous processing instead of asyncForEach to avoid hang
        // and reduce logging overhead for better performance
        var relatedPVFiles = [PVFile]()
        let startTime = Date()
        var matchedCount = 0

        for url in files {
            let relativeName = RomDatabase.altName(url, systemIdentifier: systemID)
            if relativeName == name {
                matchedCount += 1
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
                // Only log matches to reduce overhead
                DLOG("Found matching related file: \(url.lastPathComponent)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        DLOG("Completed related file search in \(String(format: "%.2f", duration))s: found \(matchedCount) matches out of \(files.count) files")

        if let relatedFiles = relatedFiles {
            DLOG("Processing \(relatedFiles.count) additional related files")
            for url in relatedFiles {
                DLOG("Adding related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent))) //, relativeRoot: .iCloud))
            }
        }

        DLOG("About to calculate MD5 for game: \(partialPath)")
        let md5StartTime = Date()
        guard let md5 = await calculateMD5(forGame: game)?.uppercased() else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            throw GameImporterError.couldNotCalculateMD5
        }
        let md5Duration = Date().timeIntervalSince(md5StartTime)
        DLOG("Calculated MD5: \(md5) in \(String(format: "%.2f", md5Duration))s")

        // Deduplicate by filename to prevent the same disc file being added twice
        // (once from the filesystem cache and once from resolvedAssociatedFileURLs)
        var seenFilenames = Set<String>()
        let uniqueRelatedFiles = relatedPVFiles.filter { file in
            let key = file.url?.lastPathComponent.lowercased() ?? file.partialPath.lowercased()
            return seenFilenames.insert(key).inserted
        }
        DLOG("About to append \(uniqueRelatedFiles.count) related files to game (deduped from \(relatedPVFiles.count))")
        game.relatedFiles.append(objectsIn: uniqueRelatedFiles)
        game.md5Hash = md5

        // Capture all game properties BEFORE finishUpdateOrImport (which adds game to Realm)
        // After that, game becomes managed and can't be accessed from background threads
        let gameID = game.id
        let gameTitle = game.title ?? "Unknown"
        let gameRomPath = game.romPath
        let gameMd5Hash = game.md5Hash
        let needsArtwork = game.originalArtworkFile == nil && game.originalArtworkURL.isEmpty

        DLOG("About to call finishUpdateOrImport for game: \(partialPath)")
        let finishStartTime = Date()
        try await finishUpdateOrImport(ofGame: game)
        let finishDuration = Date().timeIntervalSince(finishStartTime)
        DLOG("Completed finishUpdateOrImport for game: \(partialPath) in \(String(format: "%.2f", finishDuration))s")

        queueItem.gameDatabaseID = gameID
        // Use the system identifier from the parameter
        let systemIdentifier = systemID.rawValue

        if needsArtwork {
            // Extract filename from romPath (format: "systemID/filename" or just "filename")
            let filename: String = {
                if !gameRomPath.isEmpty {
                    let components = gameRomPath.components(separatedBy: "/")
                    let rawFilename = components.count > 1 ? (components.last ?? gameRomPath) : gameRomPath
                    // Remove file extension (artwork databases don't store extensions)
                    return (rawFilename as NSString).deletingPathExtension
                }
                return ""
            }()

            let systemID = SystemIdentifier(rawValue: systemIdentifier)
            let md5Hash = gameMd5Hash.uppercased()

            ILOG("GameImporterDatabaseService: Queuing artwork search for game \(gameTitle) (ID: \(gameID))")
            // Queue with all metadata - no Realm lookup needed, all values extracted before await
            await ArtworkSearchQueue.shared.queueGameForArtworkSearch(
                gameID: gameID,
                title: gameTitle,
                filename: filename,
                systemID: systemID,
                md5Hash: md5Hash
            )
        } else {
            VLOG("GameImporterDatabaseService: Skipping artwork queue for \(gameTitle) - already has artwork")
        }

        DLOG("Successfully completed database import for: \(partialPath)")
    }

    /// Saves the relative path for a given game and updates cloud sync status if needed
    func saveRelativePath(_ existingGame: PVGame, partialPath:String, file:URL) async {
        if RomDatabase.gamesCache[partialPath] == nil {
            await RomDatabase.addRelativeFileCache(file, game:existingGame)
        }

        // Fix for race condition: If game was created from CloudKit before local scan,
        // update the isDownloaded status and ensure PVFile is properly linked.
        // This also repairs stale cloud-era file metadata when a matching ROM is imported locally.
        ILOG("[LOCAL SCAN FIX] Reconciling game with local file: \(existingGame.title)")
        do {
            let realm = RomDatabase.sharedInstance.realm

            // Get a live (thawed) version of the game for modification
            let liveGame: PVGame?
            if existingGame.isFrozen {
                liveGame = existingGame.thaw()
            } else if let gameFromRealm = realm.object(ofType: PVGame.self, forPrimaryKey: existingGame.md5Hash) {
                liveGame = gameFromRealm
            } else {
                liveGame = existingGame
            }

            guard let gameToUpdate = liveGame else {
                ELOG("[LOCAL SCAN FIX] Could not get live game reference for: \(existingGame.title)")
                return
            }

            try realm.write {
                // Update or create PVFile reference
                if gameToUpdate.file == nil {
                    let pvFile = PVFile(withURL: file)
                    gameToUpdate.file = pvFile
                    ILOG("[LOCAL SCAN FIX] Created PVFile for game: \(gameToUpdate.title)")
                } else if let existingFile = gameToUpdate.file {
                    // Update the partial path if it's different
                    if existingFile.partialPath != partialPath {
                        existingFile.partialPath = partialPath
                        ILOG("[LOCAL SCAN FIX] Updated partialPath for game: \(gameToUpdate.title)")
                    }
                }

                /// Keep legacy launch and validation code paths aligned with the resolved local file.
                if gameToUpdate.romPath != partialPath {
                    gameToUpdate.romPath = partialPath
                    ILOG("[LOCAL SCAN FIX] Updated romPath for game: \(gameToUpdate.title)")
                }

                // Mark as downloaded since we found the file locally
                if !gameToUpdate.isDownloaded {
                    ILOG("[LOCAL SCAN FIX] Marked game as downloaded: \(gameToUpdate.title)")
                }
                gameToUpdate.isDownloaded = true
            }

            // Dual-write: mirror romPath update into SwiftData (epic #2510).
            // Only Sendable Strings are captured, so Task.detached is safe here.
            let md5 = gameToUpdate.md5Hash
            Task.detached(priority: .utility) {
                await GameImporterSwiftDataBridge.shared?.updateRelativePath(
                    md5: md5,
                    partialPath: partialPath
                )
            }
        } catch {
            ELOG("[LOCAL SCAN FIX] Failed to update game \(existingGame.title): \(error.localizedDescription)")
        }
    }

    /// Finishes the update or import of a game
    internal func finishUpdateOrImport(ofGame game: PVGame) async throws {
        DLOG("finishUpdateOrImport: Starting for game: \(game.romPath)")

        // Only process if rom doensn't exist in DB
        DLOG("finishUpdateOrImport: Checking if game already exists in cache")
        if RomDatabase.gamesCache[game.romPath] != nil {
            DLOG("finishUpdateOrImport: Game already exists in database cache: \(game.romPath)")
            throw GameImporterError.romAlreadyExistsInDatabase
        }

        var game:PVGame = game

        /// Defer slow metadata lookup to background task - don't block import
        if game.requiresSync {
            DLOG("finishUpdateOrImport: Deferring getUpdatedGameInfo to background task for: \(game.romPath)")
            let gameID = game.id
            let lookupService = self.lookup
            Task.detached(priority: .utility) {
                do {
                    // Step 1: Fetch game from Realm (sync)
                    let frozenGame: PVGame? = try await RealmContext.withBackgroundRealm { realm in
                        realm.object(ofType: PVGame.self, forPrimaryKey: gameID)?.freeze()
                    }
                    guard let frozenGame = frozenGame else {
                        DLOG("finishUpdateOrImport: Game \(gameID) not found for deferred metadata update")
                        return
                    }

                    // Step 2: Do async metadata lookup
                    let tempService = GameImporterDatabaseService(lookup: lookupService, gameImporterFileService: GameImporterFileService())
                    let updatedGame = try await tempService.getUpdatedGameInfo(for: frozenGame, forceRefresh: true)

                    var finalGame = updatedGame
                    if !updatedGame.originalArtworkURL.isEmpty && updatedGame.originalArtworkFile == nil {
                        DLOG("finishUpdateOrImport: Metadata update found artwork URL, downloading for: \(updatedGame.romPath)")
                        finalGame = await tempService.getArtwork(forGame: updatedGame)
                    }

                    // Step 3: Write back to Realm and mirror to SwiftData (epic #2510).
                    let frozenForSwiftData: PVGame = try await RealmContext.withBackgroundRealm { realm in
                        try realm.write {
                            realm.add(finalGame, update: .modified)
                        }
                        return finalGame.isFrozen ? finalGame : finalGame.freeze()
                    }
                    await GameImporterSwiftDataBridge.shared?.saveGame(frozenForSwiftData)

                    // Re-index in Spotlight with updated metadata/artwork (#2980)
                    #if canImport(CoreSpotlight) && !os(tvOS)
                    await tempService.indexGameInSpotlight(frozenForSwiftData)
                    #endif
                    DLOG("finishUpdateOrImport: Completed deferred getUpdatedGameInfo for: \(finalGame.romPath)")
                } catch {
                    WLOG("finishUpdateOrImport: Failed deferred metadata update: \(error.localizedDescription)")
                }
            }
        } else {
            DLOG("finishUpdateOrImport: Skipping getUpdatedGameInfo (requiresSync = false)")
        }

        /// Handle artwork: download if URL exists (async, non-blocking), or queue for search if not
        if !game.originalArtworkURL.isEmpty {
            /// Game has artwork URL (from OpenVGDB) - download it asynchronously in background
            let gameID = game.id
            let artworkURL = game.originalArtworkURL
            DLOG("finishUpdateOrImport: Game has artwork URL, scheduling async download for: \(game.romPath)")
            Task.detached(priority: .utility) {
                do {
                    // Step 1: Fetch and validate game from Realm (sync)
                    let frozenGame: PVGame? = try await RealmContext.withBackgroundRealm { realm in
                        guard let gameToUpdate = realm.object(ofType: PVGame.self, forPrimaryKey: gameID) else {
                            DLOG("finishUpdateOrImport: Game \(gameID) not found for artwork download")
                            return nil
                        }
                        guard gameToUpdate.originalArtworkFile == nil,
                              gameToUpdate.originalArtworkURL == artworkURL else {
                            DLOG("finishUpdateOrImport: Game \(gameID) already has artwork or URL changed")
                            return nil
                        }
                        return gameToUpdate.freeze()
                    }
                    guard let frozenGame = frozenGame else { return }

                    // Step 2: Download artwork (async)
                    let tempService = GameImporterDatabaseService(lookup: PVLookup.shared, gameImporterFileService: GameImporterFileService())
                    let updatedGame = await tempService.getArtwork(forGame: frozenGame)

                    // Step 3: Write back to Realm and mirror to SwiftData (epic #2510).
                    let frozenArtwork: PVGame = try await RealmContext.withBackgroundRealm { realm in
                        try realm.write {
                            realm.add(updatedGame, update: .modified)
                        }
                        return updatedGame.isFrozen ? updatedGame : updatedGame.freeze()
                    }
                    await GameImporterSwiftDataBridge.shared?.saveGame(frozenArtwork)

                    // Re-index in Spotlight with new artwork thumbnail (#2980)
                    #if canImport(CoreSpotlight) && !os(tvOS)
                    await tempService.indexGameInSpotlight(frozenArtwork)
                    #endif
                    DLOG("finishUpdateOrImport: Completed async artwork download for: \(updatedGame.romPath)")
                } catch {
                    WLOG("finishUpdateOrImport: Failed async artwork download: \(error.localizedDescription)")
                }
            }
        } else {
            /// Game has no artwork URL - will be handled by ArtworkSearchQueue after import completes
            DLOG("finishUpdateOrImport: Game has no artwork URL, will be queued for enhanced artwork search")
        }

        let romPath = game.romPath

        DLOG("finishUpdateOrImport: About to save game to database: \(romPath)")
        let saveStartTime = Date()
        try await self.saveGame(game)
        let saveDuration = Date().timeIntervalSince(saveStartTime)
        DLOG("finishUpdateOrImport: Successfully saved game: \(romPath) in \(String(format: "%.2f", saveDuration))s")
    }

    @discardableResult
    func getArtwork(forGame game: PVGame) async -> PVGame {
        // Check for existing custom artwork first
        let md5 = game.md5Hash
        if !md5.isEmpty {
            DLOG("Checking for existing custom artwork for game with MD5: \(md5)")

            // Try to find existing custom artwork with this MD5
            if let customArtworkKey = PVMediaCache.findExistingCustomArtwork(forMD5: md5) {
                DLOG("Found existing custom artwork with key: \(customArtworkKey)")

                // If we found a custom artwork key, set it as the customArtworkURL
                if let localURL = PVMediaCache.filePath(forKey: customArtworkKey) {
                    DLOG("Setting custom artwork URL: \(localURL.path)")
                    game.customArtworkURL = customArtworkKey
                }
            } else {
                DLOG("No existing custom artwork found for game with MD5: \(md5)")
            }
        }

        // Continue with original artwork handling
        var url = game.originalArtworkURL

        // If no artwork URL, try searching PVLookup for artwork
        if url.isEmpty {
            ILOG("GameImporterDatabaseService: No artwork URL, searching PVLookup for artwork")
            do {
                // Try searching by game title and system
                let gameTitle = game.title
                if !gameTitle.isEmpty {
                    let systemID = SystemIdentifier(rawValue: game.systemIdentifier)
                    ILOG("GameImporterDatabaseService: Searching artwork for game: \(gameTitle), system: \(systemID?.rawValue ?? "nil")")

                    if let artworkResults = try await lookup.searchArtwork(
                        byGameName: gameTitle,
                        systemID: systemID,
                        artworkTypes: .defaults
                    ), let firstArtwork = artworkResults.first {
                        url = firstArtwork.url.absoluteString
                        ILOG("GameImporterDatabaseService: Found artwork URL from PVLookup search: \(url)")
                        game.originalArtworkURL = url
                    } else {
                        // Try without system constraint as fallback
                        ILOG("GameImporterDatabaseService: No artwork found with system constraint, trying without system")
                        if let fallbackResults = try await lookup.searchArtwork(
                            byGameName: gameTitle,
                            systemID: nil,
                            artworkTypes: .defaults
                        ), let firstArtwork = fallbackResults.first {
                            url = firstArtwork.url.absoluteString
                            ILOG("GameImporterDatabaseService: Found artwork URL from fallback search: \(url)")
                            game.originalArtworkURL = url
                        }
                    }
                }

                // If still no URL, try using ROM metadata if we have MD5
                if url.isEmpty, !game.md5Hash.isEmpty {
                    ILOG("GameImporterDatabaseService: Trying artwork search using ROM metadata from MD5")
                    if let romMetadata = try? await lookup.searchROM(byMD5: game.md5Hash),
                       let artworkURLs = try? await lookup.getArtworkURLs(forRom: romMetadata),
                       !artworkURLs.isEmpty {
                        url = artworkURLs.first!.absoluteString
                        ILOG("GameImporterDatabaseService: Found artwork URL from ROM metadata: \(url)")
                        game.originalArtworkURL = url
                    }
                }
            } catch {
                WLOG("GameImporterDatabaseService: Error searching PVLookup for artwork: \(error.localizedDescription)")
            }

            // If still no URL found, return early
            if url.isEmpty {
                ILOG("GameImporterDatabaseService: No artwork URL found after PVLookup search")
                return game
            }
        }
        if PVMediaCache.fileExists(forKey: url) {
            if let localURL = PVMediaCache.filePath(forKey: url) {
                let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                game.originalArtworkFile = file
                return game
            }
        }
        DLOG("Starting Artwork download for \(url)")
        // Note: Evil hack for bad domain in DB
        url = url.replacingOccurrences(of: "gamefaqs1.cbsistatic.com/box/", with: "gamefaqs.gamespot.com/a/box/")
        guard let artworkURL = URL(string: url) else {
            ELOG("url is invalid url <\(url)>")
            return game
        }
        let request = URLRequest(url: artworkURL)
        var imageData:Data?

        if let response = try? await URLSession.shared.data(for: request), (response.1  as? HTTPURLResponse)?.statusCode == 200 {
            imageData = response.0
        }

        if let data = imageData {
#if os(macOS)
            if let artwork = NSImage(data: data) {
                do {
                    let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
                    let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                    game.originalArtworkFile = file
                } catch { ELOG("\(error.localizedDescription)") }
            }
#elseif !os(watchOS)
            if let artwork = UIImage(data: data) {
                do {
                    let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
                    let file = PVImageFile(withURL: localURL, relativeRoot: .documents)
                    game.originalArtworkFile = file
                } catch { ELOG("\(error.localizedDescription)") }
            }
#endif
        }
        return game
    }

    /// Updates game fields with metadata
    private func updateGameFields(_ game: PVGame, metadata: ROMMetadata, forceRefresh: Bool) -> PVGame {
        // Update title, removing (Disc 1) from the title. Discs with other numbers will retain their names
        if !metadata.gameTitle.isEmpty, forceRefresh || game.title.isEmpty {
            let revisedTitle = metadata.gameTitle.replacingOccurrences(of: "\\ \\(Disc 1\\)", with: "", options: .regularExpression)
            game.title = revisedTitle
        }

        // Update box art URL
        if let boxImageURL = metadata.boxImageURL, !boxImageURL.isEmpty, forceRefresh || game.originalArtworkURL.isEmpty {
            game.originalArtworkURL = boxImageURL
        }

        // Update region name
        if let region = metadata.region, !region.isEmpty, forceRefresh || game.regionName == nil {
            game.regionName = region
        }

        // Update region ID
        if let regionID = metadata.regionID, forceRefresh || game.regionID == nil {
            game.regionID = regionID
        }

        // Update game description with HTML decoding and formatting
        if let gameDescription = metadata.gameDescription, !gameDescription.isEmpty, forceRefresh || game.gameDescription == nil {
            let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
            if let data = gameDescription.data(using: .isoLatin1) {
                do {
                    let htmlDecodedGameDescription = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
                    game.gameDescription = htmlDecodedGameDescription.string.replacingOccurrences(of: "(\\.|\\!|\\?)([A-Z][A-Za-z\\s]{2,})", with: "$1\n\n$2", options: .regularExpression)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        }

        // Update box back artwork URL
        if let boxBackURL = metadata.boxBackURL, !boxBackURL.isEmpty, forceRefresh || game.boxBackArtworkURL == nil {
            game.boxBackArtworkURL = boxBackURL
        }

        // Update developer info
        if let developer = metadata.developer, !developer.isEmpty, forceRefresh || game.developer == nil {
            game.developer = developer
        }

        // Update publisher info
        if let publisher = metadata.publisher, !publisher.isEmpty, forceRefresh || game.publisher == nil {
            game.publisher = publisher
        }

        // Update genres
        if let genres = metadata.genres, !genres.isEmpty, forceRefresh || game.genres == nil {
            game.genres = genres
        }

        // Update release date
        if let releaseDate = metadata.releaseDate, !releaseDate.isEmpty, forceRefresh || game.publishDate == nil {
            game.publishDate = releaseDate
        }

        // Update reference URL
        if let referenceURL = metadata.referenceURL, !referenceURL.isEmpty, forceRefresh || game.referenceURL == nil {
            game.referenceURL = referenceURL
        }

        // Update release ID
        if let releaseID = metadata.releaseID, !releaseID.isEmpty, forceRefresh || game.releaseID == nil {
            game.releaseID = releaseID
        }

        // Update system short name
        if let systemShortName = metadata.systemShortName, !systemShortName.isEmpty, forceRefresh || game.systemShortName == nil {
            game.systemShortName = systemShortName
        }

        // Update ROM serial
        if let romSerial = metadata.serial, !romSerial.isEmpty, forceRefresh || game.romSerial == nil {
            game.romSerial = romSerial
        }

        return game
    }

    @discardableResult
    func getUpdatedGameInfo(for game: PVGame, forceRefresh: Bool = true) async throws -> PVGame {
        do {
            var resultsMaybe: [ROMMetadata]?

            // Try MD5 lookup
            resultsMaybe = try? await lookup.searchDatabase(usingMD5: game.md5Hash, systemID: nil)

            // Try filename lookup if MD5 failed
            if resultsMaybe == nil || resultsMaybe!.isEmpty {
                let fileName = game.file?.url?.lastPathComponent ?? game.title
                // Remove any extraneous stuff in the rom name
                let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: _GameImporterDatabaseServiceCharset)
                var gameTitleLen: Int
                if nonCharRange.length > 0, nonCharRange.location > 1 {
                    gameTitleLen = nonCharRange.location - 1
                } else {
                    gameTitleLen = fileName.count
                }
                let subfileName = String(fileName.prefix(gameTitleLen))

                // Convert system identifier to database ID
                let system = SystemIdentifier(rawValue: game.systemIdentifier)
                resultsMaybe = try? await lookup.searchDatabase(usingFilename: subfileName, systemID: system)
            }

            // If no results found, just return the original game
            guard let results = resultsMaybe, !results.isEmpty else {
                ILOG("No metadata found for game: \(game.title)")
                game.requiresSync = false  // Mark as synced so we don't try again
                return game
            }

            var chosenResult: ROMMetadata?

            // Prioritize results with artwork URLs, then try to find USA version
            // First, try to find USA version with artwork URL (Region ID 21)
            chosenResult = results.first { metadata in
                return metadata.regionID == 21 && metadata.boxImageURL != nil && !metadata.boxImageURL!.isEmpty
            } ?? results.first { metadata in
                // Fallback: USA version by region string with artwork URL
                return (metadata.region?.uppercased().contains("USA") ?? false) && metadata.boxImageURL != nil && !metadata.boxImageURL!.isEmpty
            } ?? results.first { metadata in
                // Fallback: Any result with artwork URL (prioritize artwork over region)
                return metadata.boxImageURL != nil && !metadata.boxImageURL!.isEmpty
            } ?? results.first { metadata in
                // Fallback: USA version without artwork requirement
                return metadata.regionID == 21
            } ?? results.first { metadata in
                // Fallback: USA version by region string
                return metadata.region?.uppercased().contains("USA") ?? false
            }

            // If still no result chosen, use the first result
            if chosenResult == nil {
                if results.count > 1 {
                    ILOG("Query returned \(results.count) possible matches. Using first result.")
                }
                chosenResult = results.first
            }

            game.requiresSync = false
            guard let metadata = chosenResult else {
                WLOG("Unable to find ROM \(game.romPath) in OpenVGDB")
                return game
            }

            // Search for artwork URLs using PVLookup if metadata doesn't have artwork URL
            var updatedGame = updateGameFields(game, metadata: metadata, forceRefresh: forceRefresh)

            // If no artwork URL from metadata, try PVLookup's artwork search
            if updatedGame.originalArtworkURL.isEmpty || (forceRefresh && metadata.boxImageURL == nil) {
                ILOG("GameImporterDatabaseService: No artwork URL in metadata, searching PVLookup for artwork URLs")
                do {
                    // Try to get artwork URLs from PVLookup using the ROM metadata
                    if let artworkURLs = try await lookup.getArtworkURLs(forRom: metadata), !artworkURLs.isEmpty {
                        // Use the first artwork URL found
                        let artworkURL = artworkURLs.first!.absoluteString
                        ILOG("GameImporterDatabaseService: Found artwork URL from PVLookup: \(artworkURL)")
                        updatedGame.originalArtworkURL = artworkURL
                    } else {
                        // Fallback: Try searching by game name if we have a title
                        let gameTitle = metadata.gameTitle.isEmpty ? game.title : metadata.gameTitle
                        if !gameTitle.isEmpty {
                            let systemID = SystemIdentifier(rawValue: game.systemIdentifier)
                            ILOG("GameImporterDatabaseService: Trying artwork search by game name: \(gameTitle)")
                            if let artworkResults = try? await lookup.searchArtwork(
                                byGameName: gameTitle,
                                systemID: systemID,
                                artworkTypes: .defaults
                            ), let firstArtwork = artworkResults.first {
                                let artworkURL = firstArtwork.url.absoluteString
                                ILOG("GameImporterDatabaseService: Found artwork URL from name search: \(artworkURL)")
                                updatedGame.originalArtworkURL = artworkURL
                            }
                        }
                    }
                } catch {
                    WLOG("GameImporterDatabaseService: Error searching for artwork URLs: \(error.localizedDescription)")
                }
            }

            return updatedGame
        } catch {
            WLOG("Error looking up game metadata: \(error.localizedDescription)")
            game.requiresSync = false  // Mark as synced so we don't try again
            return game
        }
    }

    enum DatabaseQueryError: Error {
        case invalidSystemID
    }

    func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        return try await lookup.searchDatabase(usingFilename: filename, systemID: systemID)
    }

    private func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) async throws -> [ROMMetadata]? {
        // Create a query that searches across multiple systems
        var results: [ROMMetadata] = []
        for systemID in systemIDs {
            if let systemResults = try await lookup.searchDatabase(usingFilename: filename, systemID: systemID) {
                results.append(contentsOf: systemResults)
            }
        }
        return results.isEmpty ? nil : results
    }

    private func searchDatabase(usingMD5 md5: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        return try await lookup.searchDatabase(usingMD5: md5, systemID: systemID)
    }

    /// Saves a game to the database
    /// Saves a game to the database (Realm + SwiftData dual-write)
    func saveGame(_ game: PVGame) async throws {
        let frozenGame: PVGame = try await RealmContext.withBackgroundRealm { realm in
            guard let system = realm.object(ofType: PVSystem.self, forPrimaryKey: game.systemIdentifier) else {
                let systemIdentifier = game.systemIdentifier
                ELOG("System not found in database: \(systemIdentifier)")
                throw GameImporterError.noSystemMatched
            }
            game.system = system

            do {
                try realm.write {
                    realm.add(game, update: .modified)
                }
                // Freeze before exiting the Realm context — cache and SwiftData both need a frozen snapshot.
                let frozen = game.freeze()
                RomDatabase.addGamesCache(frozen)
                return frozen
            } catch {
                ELOG("Failed to save game: \(error.localizedDescription)")
                let systemIdentifier = game.systemIdentifier
                let romPath = game.romPath
                ELOG("Game details - systemID: \(systemIdentifier), romPath: \(romPath)")
                throw GameImporterError.failedToMoveROM(error)
            }
        }
        // Dual-write: mirror into SwiftData after Realm context exits (epic #2510).
        await GameImporterSwiftDataBridge.shared?.saveGame(frozenGame)

        // Index the newly-imported game in Spotlight so it surfaces immediately
        // in Siri / Spotlight search without waiting for the next full reindex.
        #if canImport(CoreSpotlight) && (os(iOS) || os(macOS) || targetEnvironment(macCatalyst))
        await indexGameInSpotlight(frozenGame)
        #endif
    }

    #if canImport(CoreSpotlight) && (os(iOS) || os(macOS) || targetEnvironment(macCatalyst))
    /// Index a single game in CoreSpotlight so it appears in Siri / Spotlight search.
    private func indexGameInSpotlight(_ game: PVGame) async {
        guard !game.md5Hash.isEmpty else {
            WLOG("Spotlight: Skipping game with empty md5Hash: \(game.title)")
            return
        }

        let attributeSet = game.spotlightContentSet
        let uniqueIdentifier = game.spotlightUniqueIdentifier

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: SpotlightHelper.domainIdentifier,
            attributeSet: attributeSet
        )

        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            DLOG("Spotlight: Indexed game '\(game.title)' (\(uniqueIdentifier))")
        } catch {
            ELOG("Spotlight: Error indexing game '\(game.title)': \(error)")
        }
    }
    #endif

    /// Calculates the MD5 hash for a given game
    ///
    /// NES ROM Hashing Notes:
    /// - NES ROMs commonly use the iNES format (16-byte header) or NES 2.0 format (also 16-byte header)
    /// - UNIF format (.unf/.unif) is headerless and should NOT have the offset applied
    /// - OpenVGDB/No-Intro typically store hashes of the raw PRG+CHR data without headers
    /// - The 16-byte offset skips the iNES/NES 2.0 header to hash only the ROM payload
    /// - See: https://wiki.nesdev.com/w/index.php/INES for iNES header format
    ///
    /// - Parameter game: The game to calculate MD5 for
    /// - Returns: The uppercase MD5 hash string, or nil if calculation failed
    @objc
    public func calculateMD5(forGame game: PVGame) async -> String? {
        var offset: UInt = 0
        let systemID = SystemIdentifier(rawValue: game.systemIdentifier)

        // Apply 16-byte offset for iNES header if the file appears to have one
        // This ensures we hash only the PRG+CHR ROM data, matching No-Intro/OpenVGDB expectations
        if systemID == .NES {
            if let romPath = game.file?.url, hasINESHeader(at: romPath) {
                offset = 16
                ILOG("Detected iNES/NES 2.0 header for \(romPath.lastPathComponent), applying 16-byte MD5 offset")
            }
        }

        // SNES .smc files may have a 512-byte copier header - detect and skip if present
        let isSNES = systemID == .SNES
        let isSMC = game.file?.url?.pathExtension.lowercased() == "smc"

        let romPath = game.file?.url

        if let romPath = romPath {
            let fm = FileManager.default
            if !fm.fileExists(atPath: romPath.path) {
                ELOG("Cannot find file at path: \(romPath)")
                return nil
            }

            // Use N64 ROM normalizer for Nintendo 64 games to handle byte-swapping
            if systemID == .N64 {
                return await N64ROMNormalizer.md5ForN64ROMAsync(at: romPath, fromOffset: offset)
            }

            // For SNES .smc files, detect and skip 512-byte copier header if present
            if isSNES && isSMC {
                if let snesOffset = detectSNESCopierHeaderOffset(for: romPath) {
                    offset = snesOffset
                }
            }

            return await calculateMD5Async(at: romPath, fromOffset: offset)
        }

        return nil
    }

    /// Detects if a SNES .smc file has a 512-byte copier header.
    /// - Parameter url: URL of the .smc file
    /// - Returns: 512 if a copier header is detected, 0 if the file is headerless (clean No-Intro ROM),
    ///           or nil if the file cannot be accessed.
    private func detectSNESCopierHeaderOffset(for url: URL) -> UInt? {
        SNESHeaderDetector.detectOffset(for: url)
    }

    /// Checks if a file has a valid iNES or NES 2.0 header (16 bytes)
    ///
    /// iNES header format (first 4 bytes):
    /// - Bytes 0-3: "NES" followed by MS-DOS EOF marker (0x1A)
    ///
    /// This distinguishes iNES/NES 2.0 files from UNIF format (.unf/.unif) which are headerless
    ///
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file has a valid iNES/NES 2.0 header
    internal func hasINESHeader(at url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? fileHandle.close() }

        // Read first 4 bytes to check for iNES magic number: "NES\x1A"
        guard let headerData = try? fileHandle.read(upToCount: 4),
              headerData.count == 4 else {
            return false
        }

        let headerBytes = [UInt8](headerData)
        return headerBytes[0] == 0x4E && // 'N'
               headerBytes[1] == 0x45 && // 'E'
               headerBytes[2] == 0x53 && // 'S'
               headerBytes[3] == 0x1A    // DOS EOF marker
    }

    /// Async MD5 calculation that yields control periodically to prevent blocking the import queue
    private func calculateMD5Async(at url: URL, fromOffset offset: UInt) async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                do {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    defer { try? fileHandle.close() }

                    try fileHandle.seek(toOffset: UInt64(offset))

                    var md5Context = CC_MD5_CTX()
                    CC_MD5_Init(&md5Context)

                    let chunkSize = 1024 * 32 // 32KB chunks
                    var iterationCount = 0

                    while true {
                        let data = try fileHandle.read(upToCount: chunkSize)

                        guard let data = data, !data.isEmpty else {
                            break
                        }

                        data.withUnsafeBytes { bytes in
                            CC_MD5_Update(&md5Context, bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count))
                        }

                        // Yield control every 100 iterations (~3.2MB) to prevent blocking
                        iterationCount += 1
                        if iterationCount % 100 == 0 {
                            await Task.yield()
                        }

                        // Break if we read less than the chunk size (end of file)
                        if data.count < chunkSize {
                            break
                        }
                    }

                    // Finalize MD5
                    var md5Digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
                    CC_MD5_Final(&md5Digest, &md5Context)

                    let md5String = md5Digest.map { String(format: "%02x", $0) }.joined().uppercased()
                    continuation.resume(returning: md5String)

                } catch {
                    ELOG("Error calculating MD5 for file \(url.path): \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func getArtworkMappings() async throws -> ArtworkMapping {
        return try await lookup.getArtworkMappings()
    }
}
