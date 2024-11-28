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
    
    
    private func updateGameFields(_ game: PVGame, gameDBRecordInfo: [String : Any], forceRefresh: Bool) -> PVGame {
        //we found the record for the target PVGame
        
        /* Optional results
         gameTitle
         boxImageURL
         region
         gameDescription
         boxBackURL
         developer
         publisher
         year
         genres [comma array string]
         referenceURL
         releaseID
         regionID
         systemShortName
         serial
         */
        
        //this section updates the various fields in the return record.
        if let title = gameDBRecordInfo["gameTitle"] as? String, !title.isEmpty, forceRefresh || game.title.isEmpty {
            // Remove just (Disc 1) from the title. Discs with other numbers will retain their names
            let revisedTitle = title.replacingOccurrences(of: "\\ \\(Disc 1\\)", with: "", options: .regularExpression)
            game.title = revisedTitle
        }
        
        if let boxImageURL = gameDBRecordInfo["boxImageURL"] as? String, !boxImageURL.isEmpty, forceRefresh || game.originalArtworkURL.isEmpty {
            game.originalArtworkURL = boxImageURL
        }
        
        if let regionName = gameDBRecordInfo["region"] as? String, !regionName.isEmpty, forceRefresh || game.regionName == nil {
            game.regionName = regionName
        }
        
        if let regionID = gameDBRecordInfo["regionID"] as? Int, forceRefresh || game.regionID == nil {
            game.regionID = regionID
        }
        
        if let gameDescription = gameDBRecordInfo["gameDescription"] as? String, !gameDescription.isEmpty, forceRefresh || game.gameDescription == nil {
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
        
        if let boxBackURL = gameDBRecordInfo["boxBackURL"] as? String, !boxBackURL.isEmpty, forceRefresh || game.boxBackArtworkURL == nil {
            game.boxBackArtworkURL = boxBackURL
        }
        
        if let developer = gameDBRecordInfo["developer"] as? String, !developer.isEmpty, forceRefresh || game.developer == nil {
            game.developer = developer
        }
        
        if let publisher = gameDBRecordInfo["publisher"] as? String, !publisher.isEmpty, forceRefresh || game.publisher == nil {
            game.publisher = publisher
        }
        
        if let genres = gameDBRecordInfo["genres"] as? String, !genres.isEmpty, forceRefresh || game.genres == nil {
            game.genres = genres
        }
        
        if let releaseDate = gameDBRecordInfo["releaseDate"] as? String, !releaseDate.isEmpty, forceRefresh || game.publishDate == nil {
            game.publishDate = releaseDate
        }
        
        if let referenceURL = gameDBRecordInfo["referenceURL"] as? String, !referenceURL.isEmpty, forceRefresh || game.referenceURL == nil {
            game.referenceURL = referenceURL
        }
        
        if let releaseID = gameDBRecordInfo["releaseID"] as? NSNumber, !releaseID.stringValue.isEmpty, forceRefresh || game.releaseID == nil {
            game.releaseID = releaseID.stringValue
        }
        
        if let systemShortName = gameDBRecordInfo["systemShortName"] as? String, !systemShortName.isEmpty, forceRefresh || game.systemShortName == nil {
            game.systemShortName = systemShortName
        }
        
        if let romSerial = gameDBRecordInfo["serial"] as? String, !romSerial.isEmpty, forceRefresh || game.romSerial == nil {
            game.romSerial = romSerial
        }
        
        return game
    }
    
    @discardableResult
    func getUpdatedGameInfo(for game: PVGame, forceRefresh: Bool = true) -> PVGame {
        game.requiresSync = false
        
        //step 1 - calculate md5 hash if needed
        if game.md5Hash.isEmpty {
            if let _ = romsPath?.appendingPathComponent(game.romPath).path {
                if let md5Hash = calculateMD5(forGame: game) {
                    game.md5Hash = md5Hash
                }
            }
        }
        guard !game.md5Hash.isEmpty else {
            NSLog("Game md5 has was empty")
            return game
        }
        
        //step 2 - check art cache or database id for info based on md5 hash
        var resultsMaybe: [[String: Any]]?
        do {
            if let result = RomDatabase.getArtCache(game.md5Hash.uppercased(), systemIdentifier:game.systemIdentifier) {
                resultsMaybe=[result]
            } else {
                resultsMaybe = try searchDatabase(usingKey: "romHashMD5", value: game.md5Hash.uppercased(), systemID: game.systemIdentifier)
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        
        //step 3 - still didn't find any candidate results, check by file name
        if resultsMaybe == nil || resultsMaybe!.isEmpty { //PVEmulatorConfiguration.supportedROMFileExtensions.contains(game.file.url.pathExtension.lowercased()) {
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
            do {
                if let result = RomDatabase.getArtCacheByFileName(subfileName, systemIdentifier:game.systemIdentifier) {
                    resultsMaybe=[result]
                } else {
                    resultsMaybe = try searchDatabase(usingKey: "romFileName", value: subfileName, systemID: game.systemIdentifier)
                }
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        }
        
        //still got nothing, so just return the partial record we got.
        guard let results = resultsMaybe, !results.isEmpty else {
            // the file maybe exists but was wiped from DB,
            // try to re-import and rescan if can
            // skip re-import during artwork download process
            /*
             let urls = importFiles(atPaths: [game.url])
             if !urls.isEmpty {
             lookupInfo(for: game, overwrite: overwrite)
             return
             } else {
             DLOG("Unable to find ROM \(game.romPath) in DB")
             try? database.writeTransaction {
             game.requiresSync = false
             }
             return
             }
             */
            return game
        }
    
        //this block seems to pick the USA record from the DB if there are multiple options?
        var chosenResultMaybe: [String: Any]? =
        // Search by region id
        results.first { (dict) -> Bool in
            DLOG("region id: \(dict["regionID"] as? Int ?? 0)")
            // Region ids USA = 21, Japan = 13
            return (dict["regionID"] as? Int) == 21
        }
        ?? // If nothing, search by region string, could be a comma sepearted list
        results.first { (dict) -> Bool in
            DLOG("region: \(dict["region"] ?? "nil")")
            // Region ids USA = 21, Japan = 13
            return (dict["region"] as? String)?.uppercased().contains("USA") ?? false
        }
        if chosenResultMaybe == nil {
            if results.count > 1 {
                ILOG("Query returned \(results.count) possible matches. Failed to matcha USA version by string or release ID int. Going to choose the first that exists in the DB.")
            }
            chosenResultMaybe = results.first
        }
        
        game.requiresSync = false
        guard let chosenResult = chosenResultMaybe else {
            NSLog("Unable to find ROM \(game.romPath) in OpenVGDB")
            return game
        }
        
        return updateGameFields(game, gameDBRecordInfo:chosenResult, forceRefresh:forceRefresh)
    }
    
    func releaseID(forCRCs crcs: Set<String>) -> String? {
        return openVGDB?.releaseID(forCRCs: crcs)
    }

    enum DatabaseQueryError: Error {
        case invalidSystemID
    }

    func searchDatabase(usingKey key: String, value: String, systemID: SystemIdentifier) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID.rawValue) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingKey: key, value: value, systemID: systemIDInt)
    }

    func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingKey: key, value: value, systemID: systemIDInt)
    }

    // TODO: This was a quick copy of the general version for filenames specifically
    func searchDatabase(usingFilename filename: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingFilename: filename, systemID: systemIDInt)
    }
    func searchDatabase(usingFilename filename: String, systemIDs: [String]) throws -> [[String: NSObject]]? {
        let systemIDsInts: [Int] = systemIDs.compactMap { PVEmulatorConfiguration.databaseID(forSystemID: $0) }
        guard !systemIDsInts.isEmpty else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try openVGDB?.searchDatabase(usingFilename: filename, systemIDs: systemIDsInts)
    }
   
    /// Saves a game to the database
    func saveGame(_ game:PVGame) async {
        do {
            let database = RomDatabase.sharedInstance
            let realm = try! await RomDatabase.sharedInstance.realm
            
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
