//
//  DatabaseQueryError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import SQLite
import PVLogging

// MARK: - ROM Lookup
public extension GameImporter {

    @discardableResult
    func lookupInfo(for game: PVGame, overwrite: Bool = true) -> PVGame {
        game.requiresSync = false
        if game.md5Hash.isEmpty {
            let offset: UInt64
            switch game.systemIdentifier {
            case "com.provenance.nes":
                offset = 16
            default:
                offset = 0
            }
            let romFullPath = romsPath.appendingPathComponent(game.romPath).path
            if let md5Hash = FileManager.default.md5ForFile(atPath: romFullPath, fromOffset: offset) {
                game.md5Hash = md5Hash
            }
        }
        guard !game.md5Hash.isEmpty else {
            NSLog("Game md5 has was empty")
            return game
        }
        var resultsMaybe: [[String: Any]]?
        do {
            if let result = RomDatabase.sharedInstance.getArtCache(game.md5Hash.uppercased(), systemIdentifier:game.systemIdentifier) {
                resultsMaybe=[result]
            } else {
                resultsMaybe = try searchDatabase(usingKey: "romHashMD5", value: game.md5Hash.uppercased(), systemID: game.systemIdentifier)
            }
        } catch {
            ELOG("\(error.localizedDescription)")
        }
        if resultsMaybe == nil || resultsMaybe!.isEmpty { //PVEmulatorConfiguration.supportedROMFileExtensions.contains(game.file.url.pathExtension.lowercased()) {
            let fileName: String = game.file.url.lastPathComponent
            // Remove any extraneous stuff in the rom name such as (U), (J), [T+Eng] etc
            let nonCharRange: NSRange = (fileName as NSString).rangeOfCharacter(from: GameImporter.charset)
            var gameTitleLen: Int
            if nonCharRange.length > 0, nonCharRange.location > 1 {
                gameTitleLen = nonCharRange.location - 1
            } else {
                gameTitleLen = fileName.count
            }
            let subfileName = String(fileName.prefix(gameTitleLen))
            do {
                if let result = RomDatabase.sharedInstance.getArtCacheByFileName(subfileName, systemIdentifier:game.systemIdentifier) {
                    resultsMaybe=[result]
                } else {
                    resultsMaybe = try searchDatabase(usingKey: "romFileName", value: subfileName, systemID: game.systemIdentifier)
                }
            } catch {
                ELOG("\(error.localizedDescription)")
            }
        }
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
        //write at the end of fininshOrUpdateImport
        //autoreleasepool {
        //        do {
        game.requiresSync = false
        guard let chosenResult = chosenResultMaybe else {
            NSLog("Unable to find ROM \(game.romPath) in OpenVGDB")
            return game
        }
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
        if let title = chosenResult["gameTitle"] as? String, !title.isEmpty, overwrite || game.title.isEmpty {
            // Remove just (Disc 1) from the title. Discs with other numbers will retain their names
            let revisedTitle = title.replacingOccurrences(of: "\\ \\(Disc 1\\)", with: "", options: .regularExpression)
            game.title = revisedTitle
        }

        if let boxImageURL = chosenResult["boxImageURL"] as? String, !boxImageURL.isEmpty, overwrite || game.originalArtworkURL.isEmpty {
            game.originalArtworkURL = boxImageURL
        }

        if let regionName = chosenResult["region"] as? String, !regionName.isEmpty, overwrite || game.regionName == nil {
            game.regionName = regionName
        }

        if let regionID = chosenResult["regionID"] as? Int, overwrite || game.regionID.value == nil {
            game.regionID.value = regionID
        }

        if let gameDescription = chosenResult["gameDescription"] as? String, !gameDescription.isEmpty, overwrite || game.gameDescription == nil {
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

        if let boxBackURL = chosenResult["boxBackURL"] as? String, !boxBackURL.isEmpty, overwrite || game.boxBackArtworkURL == nil {
            game.boxBackArtworkURL = boxBackURL
        }

        if let developer = chosenResult["developer"] as? String, !developer.isEmpty, overwrite || game.developer == nil {
            game.developer = developer
        }

        if let publisher = chosenResult["publisher"] as? String, !publisher.isEmpty, overwrite || game.publisher == nil {
            game.publisher = publisher
        }

        if let genres = chosenResult["genres"] as? String, !genres.isEmpty, overwrite || game.genres == nil {
            game.genres = genres
        }

        if let releaseDate = chosenResult["releaseDate"] as? String, !releaseDate.isEmpty, overwrite || game.publishDate == nil {
            game.publishDate = releaseDate
        }

        if let referenceURL = chosenResult["referenceURL"] as? String, !referenceURL.isEmpty, overwrite || game.referenceURL == nil {
            game.referenceURL = referenceURL
        }

        if let releaseID = chosenResult["releaseID"] as? NSNumber, !releaseID.stringValue.isEmpty, overwrite || game.releaseID == nil {
            game.releaseID = releaseID.stringValue
        }

        if let systemShortName = chosenResult["systemShortName"] as? String, !systemShortName.isEmpty, overwrite || game.systemShortName == nil {
            game.systemShortName = systemShortName
        }

        if let romSerial = chosenResult["serial"] as? String, !romSerial.isEmpty, overwrite || game.romSerial == nil {
            game.romSerial = romSerial
        }
        //            } catch {
        //                ELOG("Failed to update game \(game.title) : \(error.localizedDescription)")
        //            }
        //}
        return game
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
//        let semaphore = DispatchSemaphore(value: 0)
//        let task = URLSession.shared.dataTask(with: request) { dataMaybe, urlResponseMaybe, error in
//            if let error = error {
//                ELOG("Network error: \(error.localizedDescription)")
//            } else {
//                if let urlResponse = urlResponseMaybe as? HTTPURLResponse,
//                   urlResponse.statusCode == 200 {
//                    imageData = dataMaybe
//                }
//            }
//            semaphore.signal()
//        }
//        task.resume()
//        _ = semaphore.wait(timeout: .distantFuture)
        func artworkCompletion(artworkURL: String) {
            if self.finishedArtworkHandler != nil {
                DispatchQueue.main.sync(execute: { () -> Void in
                    ILOG("Calling finishedArtworkHandler \(artworkURL)")
                    self.finishedArtworkHandler!(artworkURL)
                })
            } else {
                ELOG("finishedArtworkHandler == nil")
            }
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
#else
            if let artwork = UIImage(data: data) {
                do {
                    let localURL = try PVMediaCache.writeImage(toDisk: artwork, withKey: url)
                    let file = PVImageFile(withURL: localURL, relativeRoot: .iCloud)
                    game.originalArtworkFile = file
                } catch { ELOG("\(error.localizedDescription)") }
            }
#endif
        }
        artworkCompletion(artworkURL: url)
        return game
    }

    func releaseID(forCRCs crcs: Set<String>) -> String? {
        let roms = Table("ROMs")
        let romID = Expression<Int>(value: "romID")
        let romHashCRC = Expression<String>(value: "romHashCRC")

        let query = roms.select(romID).filter(crcs.contains(romHashCRC))

        do {
            let result = try sqldb.pluck(query)
            let foundROMid = try result?.get(romID)
            return foundROMid
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }

    enum DatabaseQueryError: Error {
        case invalidSystemID
    }

    func searchDatabase(usingKey key: String, value: String, systemID: SystemIdentifier) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID.rawValue) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try searchDatabase(usingKey: key, value: value, systemID: systemIDInt)
    }

    func searchDatabase(usingKey key: String, value: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try searchDatabase(usingKey: key, value: value, systemID: systemIDInt)
    }

    // TODO: This was a quick copy of the general version for filenames specifically
    func searchDatabase(usingFilename filename: String, systemID: String) throws -> [[String: NSObject]]? {
        guard let systemIDInt = PVEmulatorConfiguration.databaseID(forSystemID: systemID) else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try searchDatabase(usingFilename: filename, systemID: systemIDInt)
    }
    func searchDatabase(usingFilename filename: String, systemIDs: [String]) throws -> [[String: NSObject]]? {
        let systemIDsInts: [Int] = systemIDs.compactMap { PVEmulatorConfiguration.databaseID(forSystemID: $0) }
        guard !systemIDsInts.isEmpty else {
            throw DatabaseQueryError.invalidSystemID
        }

        return try searchDatabase(usingFilename: filename, systemIDs: systemIDsInts)
    }
    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) throws -> [[String: NSObject]]? {
        let properties = "releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publisher', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', romLanguage as 'language', regionLocalizedID as 'regionID'"

        let likeQuery = "SELECT DISTINCT romFileName, " + properties + ", systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE 'releaseTitleName' LIKE \"%%%@%%\" AND systemID IN (%@) ORDER BY case when 'releaseTitleName' LIKE \"%@%%\" then 1 else 0 end DESC"
        let dbSystemID: String = systemIDs.compactMap { "\($0)" }.joined(separator: ",")
        let queryString = String(format: likeQuery, filename, dbSystemID, filename)

        let results: [Any]?

        do {
            results = try openVGDB.execute(query: queryString)
        } catch {
            ELOG("Failed to execute query: \(error.localizedDescription)")
            throw error
        }

        if let validResult = results as? [[String: NSObject]], !validResult.isEmpty {
            return validResult
        } else {
            return nil
        }
    }
    func searchDatabase(usingFilename filename: String, systemID: Int? = nil) throws -> [[String: NSObject]]? {
        let properties = "releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publisher', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', romLanguage as 'language', regionLocalizedID as 'regionID'"

        let queryString: String
        if let systemID = systemID {
            let likeQuery = "SELECT DISTINCT romFileName, " + properties + ", systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE 'releaseTitleName' LIKE \"%%%@%%\" AND systemID=\"%@\" ORDER BY case when 'releaseTitleName' LIKE \"%@%%\" then 1 else 0 end DESC"
            let dbSystemID: String = String(systemID)
            queryString = String(format: likeQuery, filename, dbSystemID, filename)
        } else {
            let likeQuery = "SELECT DISTINCT romFileName, " + properties + ", systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE 'releaseTitleName' LIKE \"%%%@%%\" ORDER BY case when 'releaseTitleName' LIKE \"%@%%\" then 1 else 0 end DESC"
            queryString = String(format: likeQuery, filename, filename)
        }

        let results: [Any]?

        do {
            results = try openVGDB.execute(query: queryString)
        } catch {
            ELOG("Failed to execute query: \(error.localizedDescription)")
            throw error
        }

        if let validResult = results as? [[String: NSObject]], !validResult.isEmpty {
            return validResult
        } else {
            return nil
        }
    }

    func searchDatabase(usingKey key: String, value: String, systemID: Int? = nil) throws -> [[String: NSObject]]? {
        var results: [Any]?

        let properties = "releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publisher', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', romLanguage as 'language', regionLocalizedID as 'regionID'"

        let exactQuery = "SELECT DISTINCT " + properties + ", TEMPsystemShortName as 'systemShortName', systemID as 'systemID' FROM ROMs rom LEFT JOIN RELEASES release USING (romID) WHERE %@ = '%@'"

        let likeQuery = "SELECT DISTINCT romFileName, " + properties + ", systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE %@ LIKE \"%%%@%%\" AND systemID=\"%@\" ORDER BY case when %@ LIKE \"%@%%\" then 1 else 0 end DESC"

        let queryString: String
        if let systemID = systemID {
            let dbSystemID: String = String(systemID)
            queryString = String(format: likeQuery, key, value, dbSystemID, key, value)
        } else {
            queryString = String(format: exactQuery, key, value)
        }

        do {
            results = try openVGDB.execute(query: queryString)
        } catch {
            ELOG("Failed to execute query: \(error.localizedDescription)")
            throw error
        }

        if let validResult = results as? [[String: NSObject]], !validResult.isEmpty {
            return validResult
        } else {
            return nil
        }
    }

    static var charset: CharacterSet = {
        var c = CharacterSet.punctuationCharacters
        c.remove(charactersIn: ",-+&.'")
        return c
    }()
}
