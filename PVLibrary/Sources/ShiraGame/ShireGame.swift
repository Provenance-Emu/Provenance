//
//  ShiraGame.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

import Foundation
import PVLogging
import PVSQLiteDatabase
import SQLite

public final class ShiraGameDB {
    
    /// Legacy connection
    private let shira: PVSQLiteDatabase
    
    /// SQLSwift connection
    lazy var sqldb: Connection = {
        let sqldb = try! Connection(shairaDB.path, readonly: true)
        return sqldb
    }()
    
    lazy var shairaDB: URL = {
        let bundle = Bundle.module
        guard let sqlFile = bundle.url(forResource: "shiragame", withExtension: "sqlite3") else {
            fatalError("Unable to locate `shiragame.sqlite3`")
        }
        return sqlFile
    }()

    public required init(database: PVSQLiteDatabase? = nil) {
        if let database = database {
            if database.url.lastPathComponent != "shiragame.sqlite3" {
                fatalError("Database must be named 'shiragame.sqlite3'")
            }
            
            shira = database
        } else {
            let url = Bundle.module.url(forResource: "shiragame", withExtension: "sqlite3")!
            do {
                let database = try PVSQLiteDatabase(withURL: url)
                self.shira = database
            } catch {
                fatalError("Failed to open database at \(url): \(error)")
            }
        }
    }
}

/// Artwork Queries
public extension ShiraGameDB {
    
}
