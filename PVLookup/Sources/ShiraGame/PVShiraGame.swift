//
//  ShiraGame.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/27/24.
//

import Foundation
import PVLogging
import SQLite
import Lighter
import ROMMetadataProvider

public final class ShiraGameDB: ROMMetadataProvider {
    public typealias GameMetadata = ShiragameSchema.Game
    public typealias ROMMetadata = ShiragameSchema.Game

    private let db: ShiragameSchema

    public required init(databaseURL: URL) throws {
        self.db = ShiragameSchema(url: databaseURL)
    }

    public func searchROM(byMD5 md5: String) async throws -> GameMetadata? {
        let rom = db.roms.filter(filter: \.md5 == md5).first
//        let rom = try await db.roms.filter(limit: \.md5 == md5).first
//        return try await rom.flatMap { try await db.games.filter(\.id == $0.gameId).first() }
    }

    public func searchROM(byCRC crc: String) async throws -> GameMetadata? {
        let rom = try await db.roms.filter(\.crc == crc).first()
        return try await rom.flatMap { try await db.games.filter(\.id == $0.gameId).first() }
    }

    public func searchROM(bySHA1 sha1: String) async throws -> GameMetadata? {
        let rom = try await db.roms.filter(\.sha1 == sha1).first()
        return try await rom.flatMap { try await db.games.filter(\.id == $0.gameId).first() }
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [GameMetadata]? {
        var query = db.games.join(db.roms, on: \.id == db.roms.gameId)
                             .filter(db.roms.fileName.like("%\(filename)%"))

        if let systemID = systemID {
            query = query.filter(db.games.platformId == String(systemID))
        }

        return try await query.order(db.games.entryName.like("\(filename)%").desc)
                              .all()
    }

    public func getROMMetadata(forGameID gameID: Int) async throws -> [ROMMetadata]? {
        return try await db.roms.filter(\.gameId == gameID).all()
    }

    public func getGameMetadata(byID gameID: Int) async throws -> GameMetadata? {
        return try await db.games.filter(\.id == gameID).first()
    }

    public func getArtworkMappings() async throws -> (romMD5: [String: [String: Any]], romFileNameToMD5: [String: String]) {
        let results = try await db.roms.join(db.games, on: \.gameId == db.games.id)
                                      .all()

        var romMD5: [String: [String: Any]] = [:]
        var romFileNameToMD5: [String: String] = [:]

        for result in results {
            let rom = result.0
            let game = result.1

            if let md5 = rom.md5, !md5.isEmpty {
                let md5Uppercased = md5.uppercased()
                romMD5[md5Uppercased] = [
                    "gameTitle": game.entryName,
                    "boxImageURL": "", // ShiraGame doesn't seem to have this field, adjust as needed
                    "systemID": game.platformId,
                    "systemShortName": game.platformId // Adjust if there's a better field for this
                ]

                if let filename = rom.fileName, !filename.isEmpty {
                    let key = "\(game.platformId):\(filename)"
                    romFileNameToMD5[key] = md5Uppercased
                    romFileNameToMD5[filename] = md5Uppercased
                }

                let systemKey = "\(game.platformId):\(md5Uppercased)"
                romFileNameToMD5[systemKey] = md5Uppercased

                if let crc = rom.crc, !crc.isEmpty {
                    romFileNameToMD5[crc] = md5Uppercased
                }
            }
        }

        return (romMD5, romFileNameToMD5)
    }

    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        var query = db.roms.filter(\.md5 == md5)

        if let filename = filename {
            query = query.filter(or: \.fileName.like("%\(filename)%"))
        }

        let rom = try await query.first()
        if let rom = rom {
            let game = try await db.games.filter(\.id == rom.gameId).first()
            return Int(game?.platformId)
        }
        return nil
    }
}
