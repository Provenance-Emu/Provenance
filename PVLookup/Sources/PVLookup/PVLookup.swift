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
import TheGamesDB
#if canImport(ShiraGame)
import ShiraGame
#endif
import PVSystems
import PVLogging

/// Main lookup service that combines ROM metadata and artwork lookup capabilities
public actor PVLookup: ROMMetadataProvider, ArtworkLookupOnlineService, ArtworkLookupOfflineService {


    // MARK: - Singleton
    public static let shared = PVLookup()

    // MARK: - Properties
    private var openVGDB: OpenVGDB?
    private var libreTroDB: libretrodb?
    private var theGamesDB: TheGamesDB?
    private var isInitializing = false
    private var initializationTask: Task<Void, Error>?

#if canImport(ShiraGame)
    private var shiraGame: ShiraGame?
#endif

    // MARK: - Initialization
    private init() {
        // Initialize properties
        startInitialization()
    }

    private nonisolated func startInitialization() {
        Task { [weak self] in
            await self?.initializeDatabases()
        }
    }

    private func initializeDatabases() async {
        guard !isInitializing else {
            DLOG("Database initialization already in progress")
            return
        }

        ILOG("Starting database initialization...")
        isInitializing = true

        // Initialize OpenVGDB
        do {
            DLOG("Initializing OpenVGDB...")
            let db = try await OpenVGDB()
            self.openVGDB = db
            DLOG("OpenVGDB initialized successfully")
        } catch {
            ELOG("Failed to initialize OpenVGDB: \(error)")
        }

        // Initialize LibretroDB
        do {
            DLOG("Initializing LibretroDB...")
            let db = try await libretrodb()
            self.libreTroDB = db
            DLOG("LibretroDB initialized successfully")
        } catch {
            ELOG("Failed to initialize LibretroDB: \(error)")
        }

        // Initialize TheGamesDB
        do {
            DLOG("Initializing TheGamesDB...")
            let db = try await TheGamesDB()
            self.theGamesDB = db
            DLOG("TheGamesDB initialized successfully")
        } catch {
            ELOG("Failed to initialize TheGamesDB: \(error)")
        }

#if canImport(ShiraGame)
        // Initialize ShiraGame
        do {
            let game = try await ShiraGame()
            self.shiraGame = game
        } catch {
            ELOG("Failed to initialize ShiraGame: \(error)")
        }
#endif

        isInitializing = false
        ILOG("Database initialization complete")
    }

    // Helper to ensure databases are initialized
    internal func ensureDatabasesInitialized() async throws {
        if isInitializing {
            // Wait a bit for initialization to complete
            try await Task.sleep(for: .seconds(1))
        }

        // If any database isn't initialized, do it now
        if openVGDB == nil || libreTroDB == nil || theGamesDB == nil {
            await initializeDatabases()
        }
    }

    // Helper to safely access OpenVGDB
    private func getOpenVGDB() async -> OpenVGDB? {
        if openVGDB == nil, !isInitializing {
            isInitializing = true
            do {
                let db = try await OpenVGDB()
                self.openVGDB = db
            } catch {
                ELOG("Failed to initialize OpenVGDB: \(error)")
            }
            isInitializing = false
        }
        return openVGDB
    }

    // Helper to safely access TheGamesDB
    private func getTheGamesDB() async -> TheGamesDB? {
        if theGamesDB == nil, !isInitializing {
            isInitializing = true
            do {
                let db = try await TheGamesDB()
                self.theGamesDB = db
            } catch {
                ELOG("Failed to initialize TheGamesDB: \(error)")
            }
            isInitializing = false
        }
        return theGamesDB
    }

    // MARK: - Isolated Properties
    nonisolated private var isolatedOpenVGDB: OpenVGDB? {
        get async {
            await openVGDB
        }
    }

    nonisolated private var isolatedLibretroDB: libretrodb? {
        get async {
            await libreTroDB
        }
    }

    nonisolated private var isolatedTheGamesDB: TheGamesDB? {
        get async {
            await getTheGamesDB()
        }
    }

    // MARK: - ROMMetadataProvider Implementation
    public func searchROM(byMD5 md5: String) async throws -> ROMMetadata? {
        ILOG("PVLookup: Searching for MD5: \(md5)")
        let upperMD5 = md5.uppercased()

        // Try OpenVGDB first
        if let openVGDB = await getOpenVGDB(),
           let metadata = try await openVGDB.searchROM(byMD5: upperMD5) {
            return metadata
        }

        // Try LibretroDB
        if let libreTroDB = await isolatedLibretroDB,
           let libretroDatabaseResult = try libreTroDB.searchMetadata(usingKey: "md5", value: upperMD5, systemID: nil)?.first {
            return libretroDatabaseResult
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
        var results: [ROMMetadata] = []

        // Try OpenVGDB
        if let openVGDB = await isolatedOpenVGDB,
           let openVGDBResults = try await openVGDB.searchDatabase(usingFilename: filename, systemID: systemID) {
            results.append(contentsOf: openVGDBResults)
        }

        // Try LibretroDB
        if let libreTroDB = await isolatedLibretroDB,
           let libretroDatabaseResults = try libreTroDB.searchMetadata(usingFilename: filename, systemID: systemID) {
            results.append(contentsOf: libretroDatabaseResults)
        }

        if !results.isEmpty {
            DLOG("PVLookup: Returning \(results.count) merged results from primary databases")
            return results
        }

        #if canImport(ShiraGame)
        // Only try ShiraGame if we found nothing in primary databases
        ILOG("PVLookup: No results from primary databases, trying ShiraGame...")
        return try await getShiraGame()?.searchDatabase(usingFilename: filename, systemID: systemID)
        #else
        return nil
        #endif
    }

    public func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) async throws -> [ROMMetadata]? {
        var results: [ROMMetadata] = []

        // Try OpenVGDB
        if let openVGDB = await isolatedOpenVGDB,
           let openVGDBResults = try openVGDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs) {
            results.append(contentsOf: openVGDBResults)
        }

        // Try LibretroDB
        if let libreTroDB = await isolatedLibretroDB,
           let libretroDatabaseResults = try libreTroDB.searchDatabase(usingFilename: filename, systemIDs: systemIDs) {
            results.append(contentsOf: libretroDatabaseResults)
        }

        return results.isEmpty ? nil : results
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
        try await ensureDatabasesInitialized()

        var mergedMD5: [String: [String: String]] = [:]
        var mergedFilenames: [String: String] = [:]

        // Try OpenVGDB
        if let openVGDB = await isolatedOpenVGDB {
            let openVGDBMappings = try openVGDB.getArtworkMappings()
            mergedMD5.merge(openVGDBMappings.romMD5) { _, new in new }
            mergedFilenames.merge(openVGDBMappings.romFileNameToMD5) { _, new in new }
        }

        // Try LibretroDB
        if let libreTroDB = await isolatedLibretroDB {
            let libretroDBArtwork = try libreTroDB.getArtworkMappings()
            mergedMD5.merge(libretroDBArtwork.romMD5) { _, new in new }
            mergedFilenames.merge(libretroDBArtwork.romFileNameToMD5) { _, new in new }
        }

        // Try TheGamesDB
        if let theGamesDB = await getTheGamesDB() {
            let theGamesDBMappings = try await theGamesDB.getArtworkMappings()
            mergedMD5.merge(theGamesDBMappings.romMD5) { _, new in new }
            mergedFilenames.merge(theGamesDBMappings.romFileNameToMD5) { _, new in new }
        }

        // Verify we got some mappings
        if mergedMD5.isEmpty && mergedFilenames.isEmpty {
            WLOG("No artwork mappings found from any database")
        }

        return ArtworkMappings(
            romMD5: mergedMD5,
            romFileNameToMD5: mergedFilenames
        )
    }

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        try await ensureDatabasesInitialized()

        var urls: [URL] = []

        // Try OpenVGDB
        if let openVGDB = await isolatedOpenVGDB,
           let openVGDBUrls = try openVGDB.getArtworkURLs(forRom: rom) {
            urls.append(contentsOf: openVGDBUrls)
        }

        // Try LibretroDB
        if let libreTroDB = await isolatedLibretroDB,
           let libretroDBArtworkUrls = try await libreTroDB.getArtworkURLs(forRom: rom) {
            urls.append(contentsOf: libretroDBArtworkUrls)
        }

        // Try TheGamesDB
        if let theGamesDB = await getTheGamesDB(),
           let theGamesDBUrls = try await theGamesDB.getArtworkURLs(forRom: rom) {
            urls.append(contentsOf: theGamesDBUrls)
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
        if let openVGDB = await isolatedOpenVGDB,
           let systemID = try await openVGDB.system(forRomMD5: md5, or: filename),
           let Identifier = SystemIdentifier.fromOpenVGDBID(systemID) {
            return Identifier
        }

        // Try libretrodb next
        if let libreTroDB = await isolatedLibretroDB,
           let systemID = try await libreTroDB.systemIdentifier(forRomMD5: md5, or: filename) {
            return systemID
        }

        #if canImport(ShiraGame)
        // Try ShiraGame as a backup
        if let shiraGame = await getShiraGame(),
           let systemID = try await shiraGame.system(forRomMD5: md5, or: filename),
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
        var resultsByMD5: [String: ROMMetadata] = [:]  // Track results by MD5
        let upperMD5 = md5.uppercased()

        // Try OpenVGDB first (preferred source)
        if let openVGDB = await isolatedOpenVGDB,
           let openVGDBResults = try openVGDB.searchDatabase(usingKey: "romHashMD5", value: upperMD5, systemID: systemID) {
            for result in openVGDBResults {
                if let resultMD5 = result.romHashMD5?.uppercased() {
                    resultsByMD5[resultMD5] = result
                }
            }
        }

        // Try LibretroDB and merge with existing results
        if let libreTroDB = await isolatedLibretroDB,
           let libretroDatabaseResults = try libreTroDB.searchMetadata(usingKey: "md5", value: upperMD5, systemID: systemID) {
            for result in libretroDatabaseResults {
                if let resultMD5 = result.romHashMD5?.uppercased() {
                    if let existing = resultsByMD5[resultMD5] {
                        // Use existing merge functionality
                        resultsByMD5[resultMD5] = existing.merged(with: result)
                    } else {
                        // New result
                        resultsByMD5[resultMD5] = result
                    }
                }
            }
        }

        let results = Array(resultsByMD5.values)
        return results.isEmpty ? nil : results
    }

    /// Search for artwork by game name across all services
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        try await ensureDatabasesInitialized()

        var results: [ArtworkMetadata] = []

        // Try OpenVGDB
        if let openVGDBArtwork = try await openVGDB?.searchArtwork(
            byGameName: name,
            systemID: systemID,
            artworkTypes: artworkTypes
        ) {
            results.append(contentsOf: openVGDBArtwork)
        }

        // Try LibretroDB
        if let libretroDBArtwork = try await libreTroDB?.searchArtwork(
            byGameName: name,
            systemID: systemID,
            artworkTypes: artworkTypes
        ) {
            results.append(contentsOf: libretroDBArtwork)
        }

        // Try TheGamesDB
        if let theGamesDB = await getTheGamesDB(),
           let theGamesDBartwork = try await theGamesDB.searchArtwork(
            byGameName: name,
            systemID: systemID,
            artworkTypes: artworkTypes
        ) {
            results.append(contentsOf: theGamesDBartwork)
        }

        // Sort artwork by type priority
        let sortedArtwork = sortArtworkByType(results)

        // Cache results
        if !sortedArtwork.isEmpty {
            let cacheKey = ArtworkSearchKey(
                gameName: name,
                systemID: systemID,
                artworkTypes: artworkTypes ?? .defaults
            )
            await ArtworkSearchCache.shared.set(key: cacheKey, results: sortedArtwork)
        }

        return sortedArtwork.isEmpty ? nil : sortedArtwork
    }

    /// Get artwork for a specific game ID across all services
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        var allArtwork: [ArtworkMetadata] = []

        // Try OpenVGDB
        if let openVGDBArtwork = try await openVGDB?.getArtwork(
            forGameID: gameID,
            artworkTypes: artworkTypes
        ) {
            allArtwork.append(contentsOf: openVGDBArtwork)
        }

        // Try LibretroDB
        if let libretroDBArtwork = try await libreTroDB?.getArtwork(
            forGameID: gameID,
            artworkTypes: artworkTypes
        ) {
            allArtwork.append(contentsOf: libretroDBArtwork)
        }

        // Try TheGamesDB
        if let theGamesDB = await getTheGamesDB(),
           let theGamesDBartwork = try await theGamesDB.getArtwork(
            forGameID: gameID,
            artworkTypes: artworkTypes
        ) {
            allArtwork.append(contentsOf: theGamesDBartwork)
        }

        // Sort artwork by type priority
        let sortedArtwork = sortArtworkByType(allArtwork)

        return sortedArtwork.isEmpty ? nil : sortedArtwork
    }

    /// Helper function to sort artwork by type priority
    private func sortArtworkByType(_ artwork: [ArtworkMetadata]) -> [ArtworkMetadata] {
        let priority: [ArtworkType] = [
            .boxFront,    // Front cover is highest priority
            .boxBack,     // Back cover next
            .screenshot,  // Screenshots
            .titleScreen, // Title screens
            .clearLogo,  // Clear logos
            .banner,     // Banners
            .fanArt,     // Fan art
            .manual,     // Manuals
            .other       // Other types last
        ]

        return artwork.sorted { a, b in
            let aIndex = priority.firstIndex(of: a.type) ?? priority.count
            let bIndex = priority.firstIndex(of: b.type) ?? priority.count
            return aIndex < bIndex
        }
    }

#if canImport(ShiraGame)
    // Helper to safely access ShiraGame
    private func getShiraGame() async -> ShiraGame? {
        if shiraGame == nil, !isInitializing {
            isInitializing = true
            do {
                let game = try await ShiraGame()
                self.shiraGame = game
            } catch {
                ELOG("Failed to initialize ShiraGame: \(error)")
            }
            isInitializing = false
        }
        return shiraGame
    }
#endif
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
