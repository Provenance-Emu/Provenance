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
        let openVGDBResult = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: upperMD5, systemID: nil)?.first
        DLOG("PVLookup: OpenVGDB result: \(String(describing: openVGDBResult))")

        let libretroDatabaseResult = try libreTroDB.searchMetadata(usingKey: "md5", value: upperMD5, systemID: nil)?.first
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

    public func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        ILOG("PVLookup: Searching for filename: \(filename)")

        // Try primary databases first
        let openVGDBResults = try openVGDB.searchDatabase(usingFilename: filename, systemID: systemID)
        DLOG("PVLookup: OpenVGDB results: \(String(describing: openVGDBResults?.count)) matches")

        let libretroDatabaseResults = try libreTroDB.searchMetadata(usingFilename: filename, systemID: systemID)
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

    public func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) async throws -> [ROMMetadata]? {
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

    // MARK: - MD5 Searching
    
    /// Get SystemIdentifier for a ROM using MD5 or filename
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: SystemIdentifier if found
    public func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        // Try OpenVGDB first
        if let systemID = try openVGDB.system(forRomMD5: md5, or: filename) {
            return systemID
        }

        // Try libretrodb next - using libretrodb's own conversion
        if let systemID = try await libreTroDB.systemIdentifier(forRomMD5: md5, or: filename) {
            return systemID
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
    
    
    /// Search for all possible ROMs for a MD5, with optional narrowing to specific `SystemIdentifier`
    /// - Parameters:
    ///   - md5: md5 hash, preferabbly uppercased though we'll manage that for you
    ///   - systemID: System ID optinally to filter on
    /// - Returns: Optional array of `ROMMetadata`
    public func searchDatabase(usingMD5 md5: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        // Get results from both databases
        let systemIdentifiter: SystemIdentifier? = systemID

        let openVGDBResults = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: md5, systemID: systemIdentifiter)
        let libretroDatabaseResults = try libreTroDB.searchMetadata(usingKey: "md5", value: md5, systemID: systemIdentifiter)

        // If we have results from both, merge them
        if let openVGDBMetadata = openVGDBResults,
           let libretroDatabaseMetadata = libretroDatabaseResults {
            return openVGDBMetadata.merged(with: libretroDatabaseMetadata)
        }

        // Otherwise return whichever one we have
        return openVGDBResults ?? libretroDatabaseResults
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
