//
//  PVSQLiteDatabase.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
//import CSQLite
//import GRDB
@_exported import SQLite


public final class PVSQLiteDatabase {
    
    public enum OpenVGDatabaseQueryError: Error {
        case invalidSystemID
    }

    
    // MARK: - Public

    public required init(withURL url: URL) throws {
        self.url = url
        let connection = try Connection(url.path, readonly: true)
        self.db = connection
//        let configuration = configuration(withURL: url)
//        let queue = try DatabaseQueue(path: ..., configuration: config)
//        self.dbQueue = queue
    }
    
    public func executeQuery(_ sql: String) throws -> [[String:AnyObject]] {
//        try dbQueue.read { db in=
    []
//            if let row = try Row.fetchOne(db, sql: sql, arguments: [1]) {
//                 let name: String = row["name"]
//                 let color: Color = row["color"]
//                 print(name, color)
//             }
//        }
    }
    
    deinit {
        
    }
    
    // MARK: - Private
    let url: URL

    let db: Connection
//    let dbQueue: DatabaseQueue
//    let configuration: Configuration
//
//    private func configuration(withURL url: URL) -> Configuration {
//       let config = Configuration()
//        config.readonly = true
//        config.foreignKeysEnabled = true // Default is already true
//        config.label = "MyDatabase"      // Useful when your app opens multiple databases
//        config.maximumReaderCount = 10   // (DatabasePool only) The default is 5
//
//        let dbQueue = try DatabaseQueue( // or DatabasePool
//            path: url.path,
//            configuration: config)
//        return config
//    }
    lazy var openVGDB: OESQLiteDatabase = {
        let bundle = ThisBundle
        let _openVGDB = try! OESQLiteDatabase(url: bundle.url(forResource: "openvgdb", withExtension: "sqlite")!)
        return _openVGDB
    }()

    lazy var sqldb: Connection = {
        let bundle = ThisBundle
        let sqlFile = bundle.url(forResource: "openvgdb", withExtension: "sqlite")!
        let sqldb = try! Connection(sqlFile.path, readonly: true)
        return sqldb
    }()

    fileprivate let ThisBundle: Bundle = Bundle(for: PVSQLiteDatabase.self)
}

public extension PVSQLiteDatabase {
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
    
    func search(md5: String, systemID: String? = nil) throws -> [[String: Any]]? {
        return try searchDatabase(usingKey: "romHashMD5", value: md5.uppercased(), systemID: systemID)
    }
    
    func search(romFileName: String, systemID: String? = nil) throws -> [[String: Any]]? {
        return try searchDatabase(usingKey: "romFileName", value: romFileName, systemID: systemID)
    }
}

public extension PVSQLiteDatabase {
    func releaseID(forCRCs crcs: Set<String>) -> Int? {
        let roms = Table("ROMs")
        let romID = Expression<Int>("romID")
        let romHashCRC = Expression<String>("romHashCRC")

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

}
