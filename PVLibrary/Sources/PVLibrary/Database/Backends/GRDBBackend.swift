//
//  GRDBBackend.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation
#if canImport(GRDB)
import GRDB

public struct GRDBBackend: DatabaseBackendProtocol {
    private let dbPool: DatabasePool

    public init(sqliteDBPath url: URL) {
        var config: Configuration = GRDB.Configuration.init()
        config.readonly = true
        config.label = "OpenVGDB"
        #if DEBUG
            // Enable verbose debugging in DEBUG builds only
        config.publicStatementArguments = true
        #endif

        let _openVGDBPool = try! DatabasePool(path: url.path, configuration: config)
        self.dbPool = _openVGDBPool
    }

    public func releaseID(forCRCs crcs: Set<String>) -> Int? {
//        let keys: [[String:String]] = crcs.reduce([[String:String]]()) { roms, crc in
//            var roms = roms
//            roms.append(["romHashCRC" : crc])
//        }
//        try openVGDB.read { db in
//            let roms = try OpenVGDB.Roms.fetchAll(db, keys: keys)
//        }

        return nil
    }

}
#endif
