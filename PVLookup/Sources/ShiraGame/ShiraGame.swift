import Foundation
import PVLogging
import Lighter
import ROMMetadataProvider
import PVLookupTypes
import Systems

public final class ShiraGame: ROMMetadataProvider, @unchecked Sendable {
    private let db: ShiragameSchema

    public init() {
        // Ensure database is extracted
        try! ShiraGameManager.prepareDatabaseIfNeeded()

        // Initialize database using the generated schema
        self.db = ShiragameSchema(url: ShiraGameManager.databasePath)
    }

    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        // Normalize MD5 to uppercase
        let normalizedMD5 = md5.uppercased()

        // First find the ROM
        let roms = try db.roms.filter(filter: { $0.md5 == normalizedMD5 })
        guard let rom = roms.first else { return nil }

        // Then find the corresponding game
        let games = try db.games.filter(filter: { $0.id == rom.gameId })
        guard let game = games.first else { return nil }

        return convertToROMMetadata(game: game, rom: rom)
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Find ROMs matching filename
        let roms = try db.roms.filter(filter: { $0.fileName.contains(filename) })
        if roms.isEmpty { return nil }

        // Find corresponding games
        let gameIds = Set(roms.map { $0.gameId })
        var games = try db.games.filter(filter: { game in
            if let id = game.id {
                return gameIds.contains(id)
            }
            return false
        })

        if let systemID = systemID {
            games = games.filter { $0.platformId == String(systemID) }
        }

        return games.compactMap { game in
            guard let rom = roms.first(where: { $0.gameId == game.id }) else { return nil }
            return convertToROMMetadata(game: game, rom: rom)
        }
    }

    @available(*, deprecated)
    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        if let identifier = try await systemIdentifier(forRomMD5: md5, or: filename) {
            return identifier.openVGDBID
        }
        return nil
    }

    public func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        let normalizedMD5 = md5.uppercased()

        // Try MD5 first
        if let rom = try db.roms.filter(filter: { $0.md5 == normalizedMD5 }).first,
           let game = try db.games.filter(filter: { $0.id == rom.gameId }).first {
            return SystemIdentifier.fromShiraGameID(game.platformId)
        }

        // Try filename if MD5 fails
        if let filename = filename,
           let rom = try db.roms.filter(filter: { $0.fileName.contains(filename) }).first,
           let game = try db.games.filter(filter: { $0.id == rom.gameId }).first {
            return SystemIdentifier.fromShiraGameID(game.platformId)
        }

        return nil
    }

    // MARK: - Private Helpers

    private func convertToROMMetadata(game: ShiragameSchema.Game, rom: ShiragameSchema.Rom) -> ROMMetadata {
        let systemIdentifier = SystemIdentifier.fromShiraGameID(game.platformId) ?? .Unknown

        return ROMMetadata(
            gameTitle: game.entryName,
            boxImageURL: nil,  // ShiraGame doesn't provide artwork
            region: game.region,
            gameDescription: nil,
            boxBackURL: nil,
            developer: nil,
            publisher: nil,
            serial: nil,
            releaseDate: nil,
            genres: nil,
            referenceURL: nil,
            releaseID: nil,
            language: nil,
            regionID: nil,
            systemID: systemIdentifier,  // Now passing SystemIdentifier directly
            systemShortName: game.platformId,
            romFileName: rom.fileName,
            romHashCRC: rom.crc,
            romHashMD5: rom.md5,
            romID: Int(game.id ?? 0),
            isBIOS: game.isSystem
        )
    }
}
