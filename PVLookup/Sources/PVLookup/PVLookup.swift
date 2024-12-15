//
//  PVLookup.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation
import OpenVGDB
import ROMMetadataProvider
import PVLookupTypes
import libretrodb
import ShiraGame
import Systems

/// Protocol for basic ROM metadata lookup operations
public protocol ROMMetadataLookup {
    /// Search database using a filename
    func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Search database using a specific key/value pair
    func searchDatabase(usingKey key: String, value: String, systemID: Int?) async throws -> [ROMMetadata]?

    /// Search database using filename across multiple systems
    func searchDatabase(usingFilename filename: String, systemIDs: [Int]) async throws -> [ROMMetadata]?

    /// Get system ID for a ROM using MD5 or filename
    func system(forRomMD5 md5: String, or filename: String?) async throws -> Int?
}

/// Protocol specifically for artwork lookup operations
public protocol ArtworkLookupService {
    /// Get artwork mappings for ROMs
    func getArtworkMappings() async throws -> ArtworkMapping
}

/// Main lookup service that combines ROM metadata and artwork lookup capabilities
public actor PVLookup: ROMMetadataProvider, ArtworkLookupService {
    // MARK: - Singleton
    public static let shared = PVLookup()

    // MARK: - Properties
    private let openVGDB: OpenVGDB
    private let libreTroDB: libretrodb
    private let shiraGame: ShiraGame

    // MARK: - Initialization
    private init() {
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
        self.shiraGame = ShiraGame()
    }

    // MARK: - ROMMetadataProvider Implementation
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        // Try OpenVGDB first
        let openVGDBResult = try await searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)?.first

        // Get libretrodb result
        let libretroDatabaseResult = try libreTroDB.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: nil)?.first

        // Get ShiraGame result
        let shiraGameResult = try await shiraGame.searchROM(byMD5: md5)

        // Merge results with priority: OpenVGDB > libretrodb > ShiraGame
        if let openVGDBMetadata = openVGDBResult,
           let libretroDatabaseMetadata = libretroDatabaseResult,
           let shiraGameMetadata = shiraGameResult {
            return openVGDBMetadata
                .merged(with: libretroDatabaseMetadata)
                .merged(with: shiraGameMetadata)
        }

        // Otherwise return whichever one we have
        return openVGDBResult ?? libretroDatabaseResult ?? shiraGameResult
    }

    public func searchDatabase(usingKey key: String, value: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Get results from both databases
        let openVGDBResults = try openVGDB.searchDatabase(usingKey: key, value: value, systemID: systemID)
        let libretroDatabaseResults = try libreTroDB.searchDatabase(usingKey: key, value: value, systemID: systemID)

        // If we have results from both, merge them
        if let openVGDBMetadata = openVGDBResults,
           let libretroDatabaseMetadata = libretroDatabaseResults {
            return openVGDBMetadata.merged(with: libretroDatabaseMetadata)
        }

        // Otherwise return whichever one we have
        return openVGDBResults ?? libretroDatabaseResults
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Get results from each database
        let openVGDBResults = try openVGDB.searchDatabase(usingFilename: filename, systemID: systemID)
        let libretroDatabaseResults = try await libreTroDB.searchDatabase(usingFilename: filename, systemID: systemID)
        let shiraGameResults = try await shiraGame.searchDatabase(usingFilename: filename, systemID: systemID)

        // Merge results with priority: OpenVGDB > libretrodb > ShiraGame
        var mergedResults = openVGDBResults ?? []

        if let libretroDatabaseResults = libretroDatabaseResults {
            mergedResults = mergedResults.merged(with: libretroDatabaseResults)
        }

        if let shiraGameResults = shiraGameResults {
            mergedResults = mergedResults.merged(with: shiraGameResults)
        }

        return mergedResults.isEmpty ? nil : mergedResults
    }

    public func searchDatabase(usingFilename filename: String, systemIDs: [Int]) async throws -> [ROMMetadata]? {
        let openVGDBResults = try openVGDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs)
        let libretroDatabaseResults = try libreTroDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs)

        if let openVGDBMetadata = openVGDBResults,
           let libretroDatabaseMetadata = libretroDatabaseResults {
            return openVGDBMetadata.merged(with: libretroDatabaseMetadata)
        }

        return openVGDBResults ?? libretroDatabaseResults
    }

    /// Get system ID for a ROM using MD5 or filename
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: OpenVGDB system ID if found
    @available(*, deprecated, message: "Use systemIdentifier(forRomMD5:or:) instead")
    public func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
        if let identifier = try await systemIdentifier(forRomMD5: md5, or: filename) {
            return identifier.openVGDBID
        }
        return nil
    }

    /// Get SystemIdentifier for a ROM using MD5 or filename
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: SystemIdentifier if found
    public func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        // Try OpenVGDB first
        if let systemID = try openVGDB.system(forRomMD5: md5, or: filename),
           let identifier = SystemIdentifier.fromOpenVGDBID(systemID) {
            return identifier
        }

        // Try libretrodb next - using libretrodb's own conversion
        if let systemID = try await libreTroDB.system(forRomMD5: md5, or: filename),
           let identifier = SystemIdentifier.fromLibretroDatabaseID(systemID) {
            return identifier
        }

        // Try ShiraGame as a backup - using ShiraGame's own conversion
        if let systemID = try await shiraGame.system(forRomMD5: md5, or: filename),
           let identifier = SystemIdentifier.fromShiraGameID(String(systemID)) {
            return identifier
        }

        return nil
    }

    // MARK: - ArtworkLookupService Implementation
    public func getArtworkMappings() async throws -> ArtworkMapping {
        // Try OpenVGDB first
        let openVGDBMappings = try openVGDB.getArtworkMappings()

        // Then get libretrodb mappings
        let libretroDBArtwork = try libreTroDB.getArtworkMappings()

        // Merge the mappings
        let mergedMD5 = openVGDBMappings.romMD5.merging(libretroDBArtwork.romMD5) { (_, new) in new }
        let mergedFilenames = openVGDBMappings.romFileNameToMD5.merging(libretroDBArtwork.romFileNameToMD5) { (_, new) in new }

        return ArtworkMappings(romMD5: mergedMD5, romFileNameToMD5: mergedFilenames)
    }

    // MARK: - Database Search Methods
    public func searchDatabase(usingMD5 md5: String, systemID: Int?) async throws -> [ROMMetadata]? {
        return try await searchDatabase(usingKey: "romHashMD5", value: md5, systemID: systemID)
    }
}

// MARK: - Database Type Enums
public enum LocalDatabases: CaseIterable {
    case openVGDB
}

public enum RemoteDatabases: CaseIterable {
    case theGamesDB
}
