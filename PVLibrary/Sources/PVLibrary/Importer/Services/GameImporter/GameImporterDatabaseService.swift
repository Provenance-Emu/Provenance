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
import Systems
import PVMediaCache
import PVFileSystem
import PVLogging
import PVPrimitives
import PVRealm
import Perception
import SwiftUI

public protocol GameImporterDatabaseServicing {
    // TODO: Make me more generic
//    associatedtype GameType: PVGameLibraryEntry
    typealias GameType = PVGame // PVGameLibraryEntry

    func setOpenVGDB(_ vgdb: OpenVGDB)
    func setRomsPath(url:URL)
    func importGameIntoDatabase(queueItem: ImportQueueItem) async throws
    func importBIOSIntoDatabase(queueItem: ImportQueueItem) async throws
    func getUpdatedGameInfo(for game: GameType, forceRefresh: Bool) -> GameType
    func getArtwork(forGame game: GameType) async -> GameType
}

extension CharacterSet {
    var GameImporterDatabaseServiceCharset: CharacterSet {
        GameImporterDatabaseServiceCharset
    }
}
fileprivate let GameImporterDatabaseServiceCharset: CharacterSet = {
    var c = CharacterSet.punctuationCharacters
    c.remove(charactersIn: ",-+&.'")
    return c
}()

class GameImporterDatabaseService : GameImporterDatabaseServicing {


    var romsPath:URL?
    var openVGDB: OpenVGDB?
    init() {

    }

    func setRomsPath(url: URL) {
        romsPath = url
    }

    func setOpenVGDB(_ vgdb: OpenVGDB) {
        openVGDB = vgdb
    }

    internal func importGameIntoDatabase(queueItem: ImportQueueItem) async throws {
        guard queueItem.fileType != .bios else {
            return
        }

        guard let targetSystem = queueItem.targetSystem() else {
            throw GameImporterError.systemNotDetermined
        }

        //TODO: is it an error if we don't have the destination url at this point?
        guard let destUrl = queueItem.destinationUrl else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        DLOG("Attempting to import game: \(destUrl.lastPathComponent) for system: \(targetSystem.name)")

        let filename = queueItem.url.lastPathComponent
        let partialPath = (targetSystem.identifier as NSString).appendingPathComponent(filename)
        let similarName = RomDatabase.altName(queueItem.url, systemIdentifier: targetSystem.identifier)

        DLOG("Checking game cache for partialPath: \(partialPath) or similarName: \(similarName)")
        let gamesCache = RomDatabase.gamesCache

        if let existingGame = gamesCache[partialPath] ?? gamesCache[similarName],
           targetSystem.identifier == existingGame.systemIdentifier {
            DLOG("Found existing game in cache, saving relative path")
            await saveRelativePath(existingGame, partialPath: partialPath, file: queueItem.url)
        } else {
            DLOG("No existing game found, starting import to database")
            try await self.importToDatabaseROM(forItem: queueItem, system: targetSystem as! AnySystem, relatedFiles: nil)
        }
    }

    internal func importBIOSIntoDatabase(queueItem: ImportQueueItem) async throws {
        guard let destinationUrl = queueItem.destinationUrl,
            let md5 = queueItem.md5?.uppercased() else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        // Get all BIOS entries that match this MD5
        let matchingBIOSEntries:[PVBIOS] = PVEmulatorConfiguration.biosArray.filter { biosEntry in
            let frozenBiosEntry = biosEntry.isFrozen ? biosEntry : biosEntry.freeze()
            return frozenBiosEntry.expectedMD5.uppercased() == md5
        }

        for biosEntry in matchingBIOSEntries {
            // Get the first matching system
                let frozenBiosEntry = biosEntry.isFrozen ? biosEntry : biosEntry.freeze()

                // Update BIOS entry in Realm
                try await MainActor.run {
                    let realm = try Realm()
                    try realm.write {
                        if let thawedBios = frozenBiosEntry.thaw() {
                            let biosFile = PVFile(withURL: destinationUrl)
                            thawedBios.file = biosFile
                        }
                    }
                }
        }

        return
    }

    /// Imports a ROM to the database
    internal func importToDatabaseROM(forItem queueItem: ImportQueueItem, system: AnySystem, relatedFiles: [URL]?) async throws {

        guard let _ = queueItem.destinationUrl else {
            //how did we get here, throw?
            throw GameImporterError.incorrectDestinationURL
        }

        DLOG("Starting database ROM import for: \(queueItem.url.lastPathComponent)")
        let filename = queueItem.url.lastPathComponent
        let filenameSansExtension = queueItem.url.deletingPathExtension().lastPathComponent
        let title: String = PVEmulatorConfiguration.stripDiscNames(fromFilename: filenameSansExtension)
        let destinationDir = (system.identifier as NSString)
        let partialPath: String = (system.identifier as NSString).appendingPathComponent(filename)

        DLOG("Creating game object with title: \(title), partialPath: \(partialPath)")

        guard let system = RomDatabase.sharedInstance.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.identifier) else {
            throw GameImporterError.noSystemMatched
        }

        let file = PVFile(withURL: queueItem.destinationUrl!)
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
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
            }
        }

        if let relatedFiles = relatedFiles {
            DLOG("Processing \(relatedFiles.count) additional related files")
            for url in relatedFiles {
                DLOG("Adding related file: \(url.lastPathComponent)")
                relatedPVFiles.append(PVFile(withPartialPath: destinationDir.appendingPathComponent(url.lastPathComponent)))
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
            game = getUpdatedGameInfo(for: game, forceRefresh: true)
        }
        if game.originalArtworkFile == nil {
            game = await getArtwork(forGame: game)
        }
        await self.saveGame(game)
    }

    @discardableResult
    func getArtwork(forGame game: PVGame) async -> PVGame {
        var url = game.originalArtworkURL
        if url.isEmpty {
            return game
        }
        if PVMediaCache.fileExists(forKey: url) {
            if let localURL = PVMediaCache.filePath(forKey: url) {
                let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
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
                    let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
                    game.originalArtworkFile = file
                } catch { ELOG("\(error.localizedDescription)") }
            }
#elseif !os(watchOS)
            if let artwork = UIImage(data: data) {
                do {
                    let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
                    let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
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
    func getUpdatedGameInfo(for game: PVGame, forceRefresh: Bool = true) -> PVGame {
        var resultsMaybe: [ROMMetadata]?

        // Step 1 - Try to find by MD5 (using existing MD5 only since it's the primary key)
        do {
            resultsMaybe = try openVGDB?.searchDatabase(usingKey: "romHashMD5", value: game.md5Hash)
        } catch {
            ELOG("\(error.localizedDescription)")
        }

        // Step 2 - Try to find by CRC if MD5 search failed
        if resultsMaybe == nil || resultsMaybe!.isEmpty {
            if !game.crc.isEmpty {
                do {
                    resultsMaybe = try openVGDB?.searchDatabase(usingKey: "romHashCRC", value: game.crc)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        }

        // Step 3 - Try by filename if still no results
        if resultsMaybe == nil || resultsMaybe!.isEmpty {
            let fileName: String = game.file.url.lastPathComponent
            // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
            let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: GameImporterDatabaseServiceCharset)
            var gameTitleLen: Int
            if nonCharRange.length > 0, nonCharRange.location > 1 {
                gameTitleLen = nonCharRange.location - 1
            } else {
                gameTitleLen = fileName.count
            }
            let subfileName = String(fileName.prefix(gameTitleLen))

            // Convert system identifier to database ID
            if let system = SystemIdentifier(rawValue: game.systemIdentifier) {
                do {
                    resultsMaybe = try openVGDB?.searchDatabase(usingFilename: subfileName, systemID: system.openVGDBID)
                } catch {
                    ELOG("\(error.localizedDescription)")
                }
            }
        }

        // If no results found at all, return the original game
        guard let results = resultsMaybe, !results.isEmpty else {
            return game
        }

        // Try to find USA version first (Region ID 21)
        var chosenResult: ROMMetadata? = results.first { metadata in
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
            NSLog("Unable to find ROM \(game.romPath) in OpenVGDB")
            return game
        }

        return updateGameFields(game, metadata: metadata, forceRefresh: forceRefresh)
    }

    enum DatabaseQueryError: Error {
        case invalidSystemID
    }

    func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [ROMMetadata]? {
        guard let system = SystemIdentifier(rawValue: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingKey: key, value: value, systemID: system.openVGDBID)
    }

    func searchDatabase(usingFilename filename: String, systemID: String) throws -> [ROMMetadata]? {
        guard let system = SystemIdentifier(rawValue: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingFilename: filename, systemID: system.openVGDBID)
    }

    // TODO: This was a quick copy of the general version for filenames specifically
    func searchDatabase(usingFilename filename: String, systemIDs: [String]) throws -> [ROMMetadata]? {
        // Convert string system IDs to OpenVGDB database IDs
        let systemIDInts: [Int] = systemIDs.compactMap { systemID in
            guard let system = SystemIdentifier(rawValue: systemID) else {
                return nil
            }
            return system.openVGDBID
        }

        guard !systemIDInts.isEmpty else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingFilename: filename, systemIDs: systemIDInts)
    }

    /// Saves a game to the database
    func saveGame(_ game:PVGame) {
        do {
            let database = RomDatabase.sharedInstance
            let realm = RomDatabase.sharedInstance.realm

            if let system = realm.object(ofType: PVSystem.self, forPrimaryKey: game.systemIdentifier) {
                game.system = system
            }
            try database.writeTransaction {
                database.realm.create(PVGame.self, value:game, update:.modified)
            }
            RomDatabase.addGamesCache(game)
        } catch {
            ELOG("Couldn't add new game \(error.localizedDescription)")
        }
    }

    /// Calculates the MD5 hash for a given game
    @objc
    public func calculateMD5(forGame game: PVGame) -> String? {
        var offset: UInt64 = 0

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
            return fm.md5ForFile(atPath: romPath.path, fromOffset: offset)
        }

        return nil
    }
}
