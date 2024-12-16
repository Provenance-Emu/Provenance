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
#if canImport(ShiraGame)
import ShiraGame
#endif
import PVSystems
import PVLogging

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

    /// Get possible URLs for a ROM
    func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]?
}

/// Main lookup service that combines ROM metadata and artwork lookup capabilities
public actor PVLookup: ROMMetadataProvider, ArtworkLookupService {
    // MARK: - Singleton
    public static let shared = PVLookup()

    // MARK: - Properties
    private let openVGDB: OpenVGDB
    private let libreTroDB: libretrodb
#if canImport(ShiraGame)
    private var shiraGame: ShiraGame?
    private var isInitializing = false
    private var initializationTask: Task<Void, Error>?

    private func ensureInitialization() async {
        if initializationTask == nil {
            initializationTask = Task { [self] in
                await self.initializeShiraGame()
            }
        }
    }

    private func initializeShiraGame() async {
        guard !isInitializing && shiraGame == nil else { return }

        do {
            isInitializing = true
            shiraGame = try await ShiraGame()
        } catch {
            ELOG("Failed to initialize ShiraGame: \(error)")
        }
        isInitializing = false
    }

    // Helper to safely access ShiraGame
    private func getShiraGame() async -> ShiraGame? {
        await ensureInitialization()

        // If still initializing, wait for initialization
        if isInitializing, let task = initializationTask {
            // Wait for initialization to complete
            _ = await task.result
        }
        return shiraGame
    }
#endif

    // MARK: - Initialization
    private init() {
        self.openVGDB = OpenVGDB()
        self.libreTroDB = libretrodb()
    }

    // MARK: - ROMMetadataProvider Implementation
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        ILOG("PVLookup: Searching for MD5: \(md5)")

        // Normalize MD5 case for each database's preference
        let upperMD5 = md5.uppercased()

        // Try primary databases first
        let openVGDBResult = try await searchDatabase(usingKey: "romHashMD5", value: upperMD5, systemID: nil)?.first
        DLOG("PVLookup: OpenVGDB result: \(String(describing: openVGDBResult))")

        let libretroDatabaseResult = try await libreTroDB.searchMetadata(usingKey: "romHashMD5", value: upperMD5, systemID: nil)?.first
        DLOG("PVLookup: LibretroDB result: \(String(describing: libretroDatabaseResult))")

        // If we have results from primary databases, merge them
        if openVGDBResult != nil || libretroDatabaseResult != nil {
            var result = openVGDBResult ?? libretroDatabaseResult!

            // Merge if we have both
            if let openVGDBData = openVGDBResult {
                result = openVGDBData
                if let libretroDatabaseData = libretroDatabaseResult {
                    result = result.merged(with: libretroDatabaseData)
                }
            }

            return result
        }

        #if canImport(ShiraGame)
        // Only try ShiraGame if we found nothing in primary databases
        ILOG("PVLookup: No results from primary databases, trying ShiraGame...")
        let shiraGameResult = try await getShiraGame()?.searchROM(byMD5: md5.lowercased())
        DLOG("PVLookup: ShiraGame result: \(String(describing: shiraGameResult))")

        return shiraGameResult
        #else
        return nil
        #endif
    }

    @available(*, deprecated, message: "Use searchROM(byMD5:) instead")
    public func searchDatabase(usingKey key: String, value: String, systemID: Int?) async throws -> [ROMMetadata]? {
        // Get results from both databases
        let openVGDBResults = try openVGDB.searchDatabase(usingKey: key, value: value, systemID: systemID)
        let libretroDatabaseResults = try await libreTroDB.searchMetadata(usingKey: key, value: value, systemID: systemID)

        // If we have results from both, merge them
        if let openVGDBMetadata = openVGDBResults,
           let libretroDatabaseMetadata = libretroDatabaseResults {
            return openVGDBMetadata.merged(with: libretroDatabaseMetadata)
        }

        // Otherwise return whichever one we have
        return openVGDBResults ?? libretroDatabaseResults
    }

    public func searchDatabase(usingFilename filename: String, systemID: Int?) async throws -> [ROMMetadata]? {
        ILOG("PVLookup: Searching for filename: \(filename)")

        // Try primary databases first
        let openVGDBResults = try openVGDB.searchDatabase(usingFilename: filename, systemID: systemID)
        DLOG("PVLookup: OpenVGDB results: \(String(describing: openVGDBResults?.count)) matches")

        let libretroDatabaseResults = try await libreTroDB.searchMetadata(usingFilename: filename, systemID: systemID)
        DLOG("PVLookup: LibretroDB results: \(String(describing: libretroDatabaseResults?.count)) matches")

        // If we have results from primary databases, merge them
        if openVGDBResults != nil || libretroDatabaseResults != nil {
            var results = openVGDBResults ?? []

            if let libretroDatabaseData = libretroDatabaseResults {
                results = results.merged(with: libretroDatabaseData)
            }

            DLOG("PVLookup: Returning \(results.count) merged results from primary databases")
            return results.isEmpty ? nil : results
        }

#if canImport(ShiraGame)
        // Only try ShiraGame if we found nothing in primary databases
        ILOG("PVLookup: No results from primary databases, trying ShiraGame...")
        let shiraGameResults = try await getShiraGame()?.searchDatabase(usingFilename: filename, systemID: systemID)
        DLOG("PVLookup: ShiraGame results: \(String(describing: shiraGameResults?.count)) matches")

        return shiraGameResults
#else
        return nil
#endif
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
    internal func system(forRomMD5 md5: String, or filename: String?) async throws -> Int? {
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

        #if canImport(ShiraGame)
        // Try ShiraGame as a backup - using ShiraGame's own conversion
        if let systemID = try await getShiraGame()?.system(forRomMD5: md5, or: filename),
           let identifier = SystemIdentifier.fromShiraGameID(String(systemID)) {
            return identifier
        }
        #endif

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

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        var urls: [URL] = []

        // Try OpenVGDB
        if let openVGDBUrls = try openVGDB.getArtworkURLs(forRom: rom) {
            urls.append(contentsOf: openVGDBUrls)
        }

        // Try LibretroDB
        if let libretroDBArtworkUrls = try await libreTroDB.getArtworkURLs(forRom: rom) {
            urls.append(contentsOf: libretroDBArtworkUrls)
        }

        return urls.isEmpty ? nil : urls
    }

    // MARK: - Database Search Methods
    public func searchDatabase(usingMD5 md5: String, systemID: Int?) async throws -> [ROMMetadata]? {
        return try await searchDatabase(usingKey: "romHashMD5", value: md5, systemID: systemID)
    }
}

// MARK: - Database Type Enums
public enum LocalDatabases: CaseIterable {
    case openVGDB
    case libretro
    #if canImport(ShiraGame)
    case shiraGame
    #endif
}

public enum RemoteDatabases: CaseIterable {
    case theGamesDB
}
