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
import Lighter

public final class ShiraGameDB {
    
    /// Legacy connection
    private let shira: PVSQLiteDatabase
    
    /// SQLSwift connection
    lazy var sqldb: Connection = {
        let sqldb = try! Connection(shiraDB.path, readonly: true)
        return sqldb
    }()
    
    lazy var shiraDB: URL = {
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
/// MARK: - ROM Search
public extension ShiraGameDB {
    
    /* Schema
     
     Tables: {game, rom, serial}
     Table: game
        - Rows: {game_id:Int?, platform_id:String, entry_name:String, entry_title:String?, release_title:String?, region:String, part_number:Int?, is_unlicensed:Boolean, is_demo:Boolean, is_system:Boolean, version:String?, status:String?, nameing_convention:String?, source:String
     Table: rom
        - Rows: {file_name:String, mimetype:String?, md5:String?, crc:String?, sha1:String?, size:Int, game_id:Int}
     Table: serial
        - Rows: {serial:String, normalized:String, game_id:Int}
     */
    
    typealias Game = (gameID: Int?, platformID: String, entryName: String,
                             entryTitle: String?, releaseTitle: String?, region: String,
                             partNumber: Int?, isUnlicensed: Bool, isDemo: Bool,
                             isSystem: Bool, version: String?, status: String?,
                             namingConvention: String?, source: String)
    typealias ROM = (fileName: String, mimeType: String?, md5: String?,
                            crc: String?, sha1: String?, size: Int,
                            gameID: Int)
    typealias Serial = (serial: String, normalized: String, gameID: Int)
    
    typealias GameID = Int
    
    func searchROM(byMD5 md5: String) -> GameID? {
        let romTable = Table("rom")
        let gameID = Expression<Int?>(value: "gameID")
        let md5Expresion = Expression<String?>(value: "md5")

        let query = romTable.select(gameID).filter(md5 == md5Expresion)
        
        do {
            guard let result = try sqldb.pluck(query) else { return nil }
            let foundGameID = try result.get(gameID)
            return Int(foundGameID)
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func searchROM(byCRC crc: String) -> GameID? {
        let romTable = Table("rom")
        let gameID = Expression<Int?>(value: "gameID")
        let crcExpression = Expression<String?>(value: "crc")

        let query = romTable.select(gameID).where(crc == crcExpression)
        
        do {
            guard let result = try sqldb.pluck(query) else { return nil }
            let foundGameID = try result.get(gameID)
            return Int(foundGameID)
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func searchROM(bySAH1 sha1: String) -> GameID? {
        let romTable = Table("rom")
        let gameID = Expression<Int?>(value: "gameID")
        let sha1Expression = Expression<String?>(value: "sha1")

        let query = romTable.select(gameID).where(sha1 == sha1Expression)
        
        do {
            guard let result = try sqldb.pluck(query) else { return nil }
            let foundGameID = try result.get(gameID)
            return Int(foundGameID)
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }

    func getROMS(byGameID gameID: Int) -> [ShiraGameDB.ROM]? {
        /// Table
        let gameTable = Table("rom")
        
        /// Game ID to lookup Column
        let gameIDColumn = Expression<Int>(value: "gameID")
        
        /// Columns to get returned
        let fileNAme = Expression<String>(value: "file_name")
        let mimeType = Expression<String?>(value: "mimetype")
        let md5 = Expression<String?>(value: "md5")
        let crc = Expression<String?>(value: "crc")
        let sha1 = Expression<String?>(value: "sha1")
        let size = Expression<Int>(value: "size")
        
        let query = gameTable.select(fileNAme, mimeType, md5, crc, sha1, size).where(gameIDColumn == String(gameID))
        
        do {
            var roms: [ShiraGameDB.ROM] = []
            while let result = try sqldb.pluck(query) {
                let foundFileName: String = try result.get(fileNAme)
                let foundMimeType: String? = try result.get(mimeType)
                let foundMD5: String? = try result.get(md5)
                let foundCRC: String? = try result.get(crc)
                let foundSHA1: String? = try result.get(sha1)
                let foundSize: Int = Int(try result.get(size)) ?? 0
                
                roms.append((fileName: foundFileName,
                             mimeType: foundMimeType,
                             md5: foundMD5,
                             crc: foundCRC,
                             sha1: foundSHA1,
                             size: foundSize,
                             gameID: gameID))
            }
            return roms
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
}

/// MARK: - Game Search
public extension ShiraGameDB {
    func getGame(byID gameID: GameID) -> ShiraGameDB.Game? {
        
        /// Table
        let gameTable = Table("game")
        
        /// Game ID to lookup Column
        let gameIDColumn = Expression<Int>(value: "gameID")
        
        /// Columns to get returned
        let platformID = Expression<String>(value: "platformID")
        let entryName = Expression<String>(value: "entryName")
        let entryTitle = Expression<String?>(value: "entryTitle")
        let releaseTitle = Expression<String?>(value: "releaseTitle")
        let region = Expression<String>(value: "region")
        let part_number = Expression<Int?>(value: "part_number")
        let isUnlicensed = Expression<Bool>(value: "is_unlicensed")
        let isDemo = Expression<Bool>(value: "is_demo")
        let isSystem = Expression<Bool>(value: "is_system")
        let version = Expression<String?>(value: "version")
        let status = Expression<String?>(value: "status")
        let namingConvention = Expression<String?>(value: "naming_convention")
        let source = Expression<String>(value: "source")
        
        let query = gameTable.select(platformID, entryName, entryTitle, releaseTitle, region, part_number, isUnlicensed, isDemo, isSystem, version, status, namingConvention, source).where(gameIDColumn == String(gameID))
        
        do {
            guard let result = try sqldb.pluck(query) else { return nil }
            
            let foundPlatformID: String = try result.get(platformID)
            let foundEntryName: String = try result.get(entryName)
            let foundEntryTitle: String? = try result.get(entryTitle)
            let foundReleaseTitle: String? = try result.get(releaseTitle)
            let foundRegion: String = try result.get(region)
            let foundPartNumber: Int? = Int(try result.get(part_number))
            let foundIsUnlicensed: Bool = Bool(try result.get(isUnlicensed)) ?? false
            let foundIsDemo: Bool = Bool(try result.get(isDemo)) ?? false
            let foundIsSystem: Bool = Bool(try result.get(isSystem)) ?? false
            let foundVersion: String? = try result.get(version)
            let foundStatus: String? = try result.get(status)
            let foundNamingConvention: String? = try result.get(namingConvention)
            let foundSource: String = try result.get(source)
            
            return ShiraGameDB.Game(gameID: gameID,
                                    platformID: foundPlatformID,
                                    entryName: foundEntryName,
                                    entryTitle: foundEntryTitle,
                                    releaseTitle: foundReleaseTitle,
                                    region: foundRegion,
                                    partNumber: foundPartNumber,
                                    isUnlicensed: foundIsUnlicensed,
                                    isDemo: foundIsDemo,
                                    isSystem: foundIsSystem,
                                    version: foundVersion,
                                    status: foundStatus,
                                    namingConvention: foundNamingConvention,
                                    source: foundSource)
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
    
}

/// MARK: - Serial Search
public extension ShiraGameDB {
    func getSerials(byGameID gameID: GameID) -> [ShiraGameDB.Serial]? {
        
        /// Table
        let serialTable = Table("serial")
        
        /// Game ID to lookup Column
        let gameIDColumn = Expression<Int>(value: "gameID")
        
        /// Columns to get returned
        let serial = Expression<String>(value: "serial")
        let normalized = Expression<String>(value: "normalized")
        
        let query = serialTable.select(serial, normalized).where(gameIDColumn == String(gameID))
        
        do {
            var serials: [ShiraGameDB.Serial] = []
            while let result = try sqldb.pluck(query) {
                let foundSerial: String = try result.get(serial)
                let foundNormalized: String = try result.get(normalized)
                
                serials.append((serial: foundSerial,
                                normalized: foundNormalized,
                                gameID: gameID))
            }
            return serials
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getGameID(bySerial serial: String) -> GameID? {
        
        let serialTable = Table("serial")
        
        let serialColumn = Expression<String>(value: "serial")
        
        let gameID = Expression<Int>(value: "gameID")
        
        let query = serialTable.select(gameID).where(serialColumn == serial)
        
        do {
            guard let result = try sqldb.pluck(query) else { return nil }
            let foundGameID = try result.get(gameID)
            return Int(foundGameID)
        } catch {
            ELOG("Query error: \(error.localizedDescription)")
            return nil
        }
    }
}
