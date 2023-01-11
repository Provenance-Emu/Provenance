//
//  OpenVGDB.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation

public struct OpenVGDBDatabase {
    fileprivate static let ThisBundle: Bundle = Bundle.module //Bundle(for: GameImporter.self)
    fileprivate static let openVGDBURL: URL = {
        let bundle = Bundle.module //Bundle(for: GameImporter.self)
        let url = bundle.url(forResource: "openvgdb", withExtension: "sqlite")!
        return url
    }()

#if false
    let databaseBackend: DatabaseBackendProtocol = GRDBBackend(sqliteDBPath: OpenVGDBDatabase.openVGDBURL)
#else
    let databaseBackend: DatabaseBackendProtocol = SQLiteSwiftBackend(sqliteDBPath: OpenVGDBDatabase.openVGDBURL)
#endif

    func releaseID(forCRCs crcs: Set<String>) -> Int? {
        return databaseBackend.releaseID(forCRCs: crcs)
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
            results = try openVGDB.executeQuery(queryString)
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
            results = try openVGDB.executeQuery(queryString)
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
            results = try openVGDB.executeQuery(queryString)
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

        // Helper
    public func systemId(forROMCandidate rom: ImportCandidateFile) -> String? {
        guard let md5 = rom.md5 else {
            ELOG("MD5 was blank")
            return nil
        }

        let fileName: String = rom.filePath.lastPathComponent
        let queryString = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)' OR romFileName = '\(fileName)'"

        do {
                // var results: [[String: NSObject]]? = nil
            let results = try openVGDB.executeQuery(queryString)
            if
                let match = results.first,
                let databaseID = match["systemID"] as? Int,
                let systemID = PVEmulatorConfiguration.systemID(forDatabaseID: databaseID) {
                return systemID
            } else {
                ILOG("Could't match \(rom.filePath.lastPathComponent) based off of MD5 {\(md5)}")
                return nil
            }
        } catch {
            DLOG("Unable to find rom by MD5: \(error.localizedDescription)")
            return nil
        }
    }
}
