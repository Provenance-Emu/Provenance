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
import Perception
import SwiftUI
import PVLookupTypes
import RealmSwift

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

        let filename = queueItem.url.lastPathComponent
        let partialPath = (targetSystem.rawValue as NSString).appendingPathComponent(filename)
        let similarName = RomDatabase.altName(queueItem.url, systemIdentifier: targetSystem)

        DLOG("Checking game cache for partialPath: \(partialPath) or similarName: \(similarName)")
        let gamesCache = RomDatabase.gamesCache

        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
           targetSystem.rawValue == existingGame.systemIdentifier {
            DLOG("Found existing game in cache, saving relative path")
            await saveRelativePath(existingGame, partialPath: partialPath, file: queueItem.url)
        } else {
            DLOG("No existing game found, starting import to database")
            try await self.importToDatabaseROM(forItem: queueItem, system: targetSystem, relatedFiles: nil)
        }
    }

//    @MainActor
    func importBIOSIntoDatabase(queueItem: ImportQueueItem) async throws {
        ILOG("Starting BIOS database import for: \(queueItem.url.lastPathComponent)")

        // First move the file to the correct location
        try await gameImporterFileService.moveImportItem(toAppropriateSubfolder: queueItem)
        ILOG("Moved BIOS file to destination: \(queueItem.destinationUrl?.path ?? "unknown")")

        // Now let BIOSWatcher handle the database update
        if let destinationUrl = queueItem.destinationUrl {
            await BIOSWatcher.shared.processBIOSFiles([destinationUrl])
            ILOG("BIOS file processed by BIOSWatcher")
        } else {
            ELOG("No destination URL for BIOS file")
            throw GameImporterError.incorrectDestinationURL
        }
    }

    /// Imports a ROM to the database
//    @MainActor
    internal func importToDatabaseROM(forItem queueItem: ImportQueueItem, system: SystemIdentifier, relatedFiles: [URL]?) async throws {

        guard let destinationUrl = queueItem.destinationUrl else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        DLOG("Starting database ROM import for: \(queueItem.url.lastPathComponent)")
        let filename = queueItem.url.lastPathComponent
        let filenameSansExtension = queueItem.url.deletingPathExtension().lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
        let destinationDir = (system.rawValue as NSString)
        let partialPath: String = (system.rawValue as NSString).appendingPathComponent(filename)

        DLOG("Creating game object with title: \(title), partialPath: \(partialPath)")

        guard let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.rawValue) else {
            throw GameImporterError.noSystemMatched
        }

        let file = PVFile(withURL: destinationUrl, relativeRoot: .iCloud)
        let game = PVGame(withFile: file, system: system)
        game.romPath = partialPath
        game.title = title
        game.requiresSync = true
        var relatedPVFiles = [PVFile]()
        let files = RomDatabase.getFileSystemROMCache(for: system).keys
        let name = RomDatabase.altName(queueItem.url, systemIdentifier: system.identifier)

        DLOG("Searching for related files with name: \(name)")

        await files.asyncForEach { url in
            let relativeName = RomDatabase.altName(url, systemIdentifier: system.identifier)
            DLOG("Checking file \(url.lastPathComponent) with relative name: \(relativeName)")
            if relativeName == name {
                DLOG("Found matching related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent), relativeRoot: .iCloud))
            }
        }

        if let relatedFiles = relatedFiles {
            DLOG("Processing \(relatedFiles.count) additional related files")
            for url in relatedFiles {
                DLOG("Adding related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent), relativeRoot: .iCloud))
            }
        }

        guard let md5 = calculateMD5(forGame: game)?.uppercased() else {
            ELOG("Couldn't calculate MD5 for game \(partialPath)")
            throw GameImporterError.couldNotCalculateMD5
        }
        DLOG("Calculated MD5: \(md5)")

        game.relatedFiles.append(objectsIn: relatedPVFiles)
        game.md5Hash = md5
        try await finishUpdateOrImport(ofGame: game)
    }

    /// Saves the relative path for a given game
    func saveRelativePath(_ existingGame: PVGame, partialPath:String, file:URL) async {
        if RomDatabase.gamesCache[partialPath] == nil {
            await RomDatabase.addRelativeFileCache(file, game:existingGame)
        }
    }

    /// Finishes the update or import of a game
    internal func finishUpdateOrImport(ofGame game: PVGame) async throws {
        // Only process if rom doensn't exist in DB
        if RomDatabase.gamesCache[game.romPath] != nil {
            throw GameImporterError.romAlreadyExistsInDatabase
        }
        var game:PVGame = game
        if game.requiresSync {
            game = try await getUpdatedGameInfo(for: game, forceRefresh: true)
        }
        if game.originalArtworkFile == nil {
            game = await getArtwork(forGame: game)
        }
        try self.saveGame(game)
    }

    @discardableResult
    func getArtwork(forGame game: PVGame) async -> PVGame {
        var url = game.originalArtworkURL
        if url.isEmpty {
            return game
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

    //MARK: Utility


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

            // Try to find USA version first (Region ID 21)
            chosenResult = results.first { metadata in
                return metadata.regionID == 21 // USA region ID
            } ?? results.first { metadata in
                // Fallback: try matching by region string containing "USA"
                return metadata.region?.uppercased().contains("USA") ?? false
            }

            // If no USA version found, use the first result
            if chosenResult == nil {
                if results.count > 1 {
                    ILOG("Query returned \(results.count) possible matches. Failed to match USA version. Using first result.")
                }
                chosenResult = results.first
            }

            game.requiresSync = false
            guard let metadata = chosenResult else {
                WLOG("Unable to find ROM \(game.romPath) in OpenVGDB")
                return game
            }

            return updateGameFields(game, metadata: metadata, forceRefresh: forceRefresh)
        } catch {
            WLOG("Error looking up game metadata: \(error.localizedDescription)")
            game.requiresSync = false  // Mark as synced so we don't try again
            return game
        }
    }

    enum DatabaseQueryError: Error {
        case invalidSystemID
    }

//    func searchDatabase(usingKey key: String, value: String, systemID: String) async throws -> [ROMMetadata]? {
//        guard let system = SystemIdentifier(rawValue: systemID) else {
//            throw DatabaseQueryError.invalidSystemID
//        }
//
//        return try await lookup.searchDatabase(usingKey: key, value: value, systemID: system)
//    }

    func searchDatabase(usingFilename filename: String, systemID: String) async throws -> [ROMMetadata]? {
        guard let system = SystemIdentifier(rawValue: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try await lookup.searchDatabase(usingFilename: filename, systemID: system)
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
    func saveGame(_ game: PVGame) throws {
        let database = RomDatabase.sharedInstance
        let realm = try Realm()

        // Get system reference
        guard let system = realm.object(ofType: PVSystem.self, forPrimaryKey: game.systemIdentifier) else {
            ELOG("System not found in database: \(game.systemIdentifier)")
            throw GameImporterError.noSystemMatched
        }
        game.system = system

        do {
            try database.writeTransaction {
                database.realm.create(PVGame.self, value: game, update: .modified)
            }
            RomDatabase.addGamesCache(game)
        } catch {
            ELOG("Failed to save game: \(error.localizedDescription)")
            ELOG("Game details - systemID: \(game.systemIdentifier), romPath: \(game.romPath)")
            throw GameImporterError.failedToMoveROM(error)
        }
    }

    /// Calculates the MD5 hash for a given game
    @objc
    public func calculateMD5(forGame game: PVGame) -> String? {
        var offset: UInt = 0

        //this seems to be spread in many places, not sure why.  it might be doable to put this in the queue item, but for now, trying to consolidate.
        //I have no history or explanation for why we need the 16 offset for SNES/NES
        // the legacy code was actually inconsistently applied, so there's a good chance this causes some bugs (or fixes some)
        if game.systemIdentifier == SystemIdentifier.SNES.rawValue {
            offset = SystemIdentifier.SNES.offset
        } else if game.systemIdentifier == SystemIdentifier.NES.rawValue {
            offset = SystemIdentifier.NES.offset
        } else if let system = SystemIdentifier(rawValue: game.systemIdentifier) {
            offset = system.offset
        }

        let romPath = romsPath?.appendingPathComponent(game.romPath, isDirectory: false)
        if let romPath = romPath {
            let fm = FileManager.default
            if !fm.fileExists(atPath: romPath.path) {
                ELOG("Cannot find file at path: \(romPath)")
                return nil
            }
            return fm.md5ForFile(at: romPath, fromOffset: offset)
        }

        return nil
    }

    func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        return try await lookup.searchDatabase(usingFilename: filename, systemID: systemID)
    }

    func getArtworkMappings() async throws -> ArtworkMapping {
        return try await lookup.getArtworkMappings()
    }
}
