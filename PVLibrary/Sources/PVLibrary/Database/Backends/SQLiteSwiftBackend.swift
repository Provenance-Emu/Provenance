//
//  SQLiteSwiftBackend.swift
//
//
//  Created by Joseph Mattiello on 1/11/23.
//

#if canImport(SQLite)
import SQLite
import PVLogging
import Foundation

public struct SQLiteSwiftBackend: DatabaseBackendProtocol {

    fileprivate let sqldb: Connection

    public init(sqliteDBPath url: URL) {
        let sqldb = try! Connection(url.path, readonly: true)
        self.sqldb = sqldb
    }

    public func releaseID(forCRCs crcs: Set<String>) -> Int? {
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
#endif
