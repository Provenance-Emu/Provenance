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

public final class OpenVGDatabase: PVSQLiteDatabase {
    static let shared: OpenVGDatabase = OpenVGDatabase()
    
    init() {
        let bundle = Bundle(for: OpenVGDatabase.self)
        let dbURL = bundle.url(forResource: "openvgdb", withExtension: "sqlite")!
        try! super.init(withURL: dbURL, readonly: true)
    }
}

public class PVSQLiteDatabase {
    
    public enum OpenVGDatabaseQueryError: Error {
        case invalidSystemID
    }

    
    // MARK: - Public

    public init(withURL url: URL, readonly: Bool = true) throws {
        self.url = url
        let connection = try SQLite.Connection(url.path, readonly: readonly)
        self.db = connection
//        let configuration = configuration(withURL: url)
//        let queue = try DatabaseQueue(path: ..., configuration: config)
//        self.dbQueue = queue
    }
    
    public func executeQuery(_ sql: String) throws -> [[String:AnyObject]] {
//        db.prepare(.)
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
    let db: SQLite.Connection
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
            results = try self.executeQuery(queryString)
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
    
    func search(md5: String, systemID: String? = nil) throws -> [[String: NSObject]]? {
        let systemIDInt: Int? = databaseInt(forID: systemID)
        return try searchDatabase(usingKey: "romHashMD5", value: md5.uppercased(), systemID: systemIDInt)
    }
    
    func search(romFileName: String, systemID: String? = nil) throws -> [[String: NSObject]]? {
        let systemIDInt: Int? = databaseInt(forID: systemID)
        return try searchDatabase(usingKey: "romFileName", value: romFileName, systemID: systemIDInt)
    }
    
    private func databaseInt(forID systemID: String?) -> Int? {
        guard let systemID = systemID else { return nil }
        return PVEmulatorConfiguration.databaseID(forSystemID: systemID)
    }
}

public extension PVSQLiteDatabase {
    func releaseID(forCRCs crcs: Set<String>) -> Int? {
        let roms = Table("ROMs")
        let romID = Expression<Int>("romID")
        let romHashCRC = Expression<String>("romHashCRC")

        let query = roms.select(romID).filter(crcs.contains(romHashCRC))

        do {
            let result = try db.pluck(query)
            let foundROMid = try result?.get(romID)
            return foundROMid
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }

}
