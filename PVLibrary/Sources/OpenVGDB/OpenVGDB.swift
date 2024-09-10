//
//  Database_OpenVGDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

import Foundation
import PVLogging
import SQLite
import PVSQLiteDatabase

public final class OpenVGDB {
    
    #warning("TODO: Convert to SQLSwift")
    /// Legacy connection
    private let vgdb: PVSQLiteDatabase
    
    /// SQLSwift connection
    lazy var sqldb: Connection = {
        let sqldb = try! Connection(openvgdbPath.path, readonly: true)
        return sqldb
    }()
    
    lazy var openvgdbPath: URL = {
        let bundle = Bundle.module
        guard let sqlFile = bundle.url(forResource: "openvgdb", withExtension: "sqlite") else {
            fatalError("Unable to locate `openvgdb.sqlite`")
        }
        return sqlFile
    }()

    public required init(database: PVSQLiteDatabase? = nil) {
        if let database = database {
            if database.url.lastPathComponent != "openvgdb.sqlite" {
                fatalError("Database must be named 'openvgdb.sqlite'")
            }
            
            vgdb = database
        } else {
            let url = Bundle.module.url(forResource: "openvgdb", withExtension: "sqlite")!
            do {
                let database = try PVSQLiteDatabase(withURL: url)
                self.vgdb = database
            } catch {
                fatalError("Failed to open database at \(url): \(error)")
            }
        }
    }
}

/// Artwork Queries
public extension OpenVGDB {
    
    typealias ArtworkMapping = (romMD5: [String:[String: AnyObject]], romFileNameToMD5: [String:String])
    
    
    /// Maps roms to artwork as a quick index
    /// - Returns: a tuple of Rom filename and key to md5, crc etc
    func getArtworkMappings() throws -> ArtworkMapping  {
        let results = try self.getAllReleases()
        var romMD5:[String:[String: AnyObject]] = [:]
        var romFileNameToMD5:[String:String] = [:]
        for res in results {
            if let md5 = res["romHashMD5"] as? String, !md5.isEmpty {
                let md5 : String = md5.uppercased()
                romMD5[md5] = res
                if let systemID = res["systemID"] as? Int {
                    if let filename = res["romFileName"] as? String, !filename.isEmpty {
                        let key : String = String(systemID) + ":" + filename
                        romFileNameToMD5[key]=md5
                        romFileNameToMD5[filename]=md5
                    }
                    let key : String = String(systemID) + ":" + md5
                    romFileNameToMD5[key]=md5
                }
                if let crc = res["romHashCRC"] as? String, !crc.isEmpty {
                    romFileNameToMD5[crc]=md5
                }
            }
        }
        return (romMD5, romFileNameToMD5)
    }
    
    func getAllReleases() throws -> SQLQueryResponse {
        let queryString = """
            SELECT
                release.regionLocalizedID as 'regionID',
                release.releaseCoverBack as 'boxBackURL',
                release.releaseCoverFront as 'boxImageURL',
                release.releaseDate as 'releaseDate',
                release.releaseDescription as 'gameDescription',
                release.releaseDeveloper as 'developer',
                release.releaseGenre as 'genres',
                release.releaseID as 'releaseID',
                release.releasePublisher as 'publisher',
                release.releaseReferenceURL as 'referenceURL',
                release.releaseTitleName as 'gameTitle',
                rom.TEMPRomRegion as 'region',
                rom.romFileName as 'romFileName',
                rom.romHashCRC as 'romHashCRC',
                rom.romHashMD5 as 'romHashMD5',
                rom.romID as 'romID',
                rom.romLanguage as 'language',
                rom.romSerial as 'serial',
                rom.systemID as 'systemID',
                system.systemShortName as 'systemShortName'
            FROM ROMs rom, RELEASES release, SYSTEMS system, REGIONS region
            WHERE rom.romID = release.romID
            AND rom.systemID = system.systemID
            AND release.regionLocalizedID = region.regionID
            """
        let results = try vgdb.execute(query: queryString)
        return results
    }
    
    func system(forRomMD5 md5: String, or filename: String? = nil) throws -> SQLQueryResponse {
        var queryString = "SELECT DISTINCT systemID FROM ROMs WHERE romHashMD5 = '\(md5)'"
        if let filename = filename {
            queryString += " OR romFileName = '\(filename)'"
        }
        
        let results = try vgdb.execute(query: queryString)
        return results
    }
    
    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) throws -> [[String: NSObject]]? {
        let properties = "releaseTitleName as 'gameTitle', releaseCoverFront as 'boxImageURL', TEMPRomRegion as 'region', releaseDescription as 'gameDescription', releaseCoverBack as 'boxBackURL', releaseDeveloper as 'developer', releasePublisher as 'publisher', romSerial as 'serial', releaseDate as 'releaseDate', releaseGenre as 'genres', releaseReferenceURL as 'referenceURL', releaseID as 'releaseID', romLanguage as 'language', regionLocalizedID as 'regionID'"
        
        let likeQuery = "SELECT DISTINCT romFileName, " + properties + ", systemShortName FROM ROMs rom LEFT JOIN RELEASES release USING (romID) LEFT JOIN SYSTEMS system USING (systemID) LEFT JOIN REGIONS region on (regionLocalizedID=region.regionID) WHERE 'releaseTitleName' LIKE \"%%%@%%\" AND systemID IN (%@) ORDER BY case when 'releaseTitleName' LIKE \"%@%%\" then 1 else 0 end DESC"
        let dbSystemID: String = systemIDs.compactMap { "\($0)" }.joined(separator: ",")
        let queryString = String(format: likeQuery, filename, dbSystemID, filename)
        
        let results: [Any]?
        
        do {
            results = try vgdb.execute(query: queryString)
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
            results = try vgdb.execute(query: queryString)
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
            results = try vgdb.execute(query: queryString)
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
}
