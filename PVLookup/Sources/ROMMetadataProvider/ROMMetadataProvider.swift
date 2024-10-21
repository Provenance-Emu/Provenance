import Foundation

public protocol ROMMetadataProvider {
    associatedtype GameMetadata
    associatedtype ROMMetadata

    // Initialize with a database URL
    init(databaseURL: URL) throws

    // Search by hashes
    func searchROM(byMD5 md5: String) async throws -> GameMetadata?
    func searchROM(byCRC crc: String) async throws -> GameMetadata?
    func searchROM(bySHA1 sha1: String) async throws -> GameMetadata?

    // Search by filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [GameMetadata]?

    // Get ROM metadata
    func getROMMetadata(forGameID gameID: Int) async throws -> [ROMMetadata]?

    // Get full game metadata
    func getGameMetadata(byID gameID: Int) async throws -> GameMetadata?

    // Get artwork mappings
    func getArtworkMappings() async throws -> (romMD5: [String: [String: Any]], romFileNameToMD5: [String: String])

    // Get system ID for ROM
    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int?
}
