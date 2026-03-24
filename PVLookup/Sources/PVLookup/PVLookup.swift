//
//  PVLookup.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation
import ROMMetadataProvider
import PVLookupTypes
#if canImport(OpenVGDB)
import OpenVGDB
#endif
#if canImport(libretrodb)
import libretrodb
#endif
#if canImport(TheGamesDB)
import TheGamesDB
#endif
#if canImport(ShiraGame)
import ShiraGame
#endif
import PVSystems
import PVLogging


// MARK: - Database Type Enums
public enum LocalDatabases: CaseIterable {
    #if canImport(OpenVGDB)
    case openVGDB
    #endif
    #if canImport(libretrodb)
    case libretro
    #endif
    #if canImport(ShiraGame)
    case shiraGame
    #endif
    #if canImport(TheGamesDB)
    case theGamesDB
    #endif
}


/// Main lookup service that combines ROM metadata and artwork lookup capabilities
public actor PVLookup: ROMMetadataProvider, ArtworkLookupOnlineService, ArtworkLookupOfflineService {


    // MARK: - Singleton
    public static let shared = PVLookup()

    // MARK: - Properties
    private var databases: [LocalDatabases] = [.libretro, .openVGDB, .theGamesDB]
    private var isInitializing = false
    private var initializationTask: Task<Void, Error>?

    private struct CacheEntry<Value> {
        var value: Value?
        var lastAccess: TimeInterval
    }

    private enum CachedLookup<Value> {
        case hit(Value)
        case miss
    }

    private struct FilenameCacheKey: Hashable {
        let filename: String
        let systemIdentifier: String?
    }

    private var md5Cache: [String: CacheEntry<ROMMetadata>] = [:]
    private let md5CacheLimit = 512
    private var filenameCache: [FilenameCacheKey: CacheEntry<[ROMMetadata]>] = [:]
    private let filenameCacheLimit = 256
    private var serialCache: [String: CacheEntry<ROMMetadata>] = [:]
    private let serialCacheLimit = 256

    // MARK: - Databases
#if canImport(OpenVGDB)
    private var openVGDB: OpenVGDB?
#endif
#if canImport(libretrodb)
    private var libreTroDB: libretrodb?
#endif
#if canImport(TheGamesDB)
    private var theGamesDB: TheGamesDB?
#endif
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
#if canImport(OpenVGDB)
        // Initialize OpenVGDB
        do {
            DLOG("Initializing OpenVGDB...")
            let db = try await OpenVGDB()
            self.openVGDB = db
            DLOG("OpenVGDB initialized successfully")
        } catch {
            ELOG("Failed to initialize OpenVGDB: \(error)")
        }
#endif
#if canImport(libretrodb)
        // Initialize LibretroDB
        do {
            DLOG("Initializing LibretroDB...")
            let db = try await libretrodb()
            self.libreTroDB = db
            DLOG("LibretroDB initialized successfully")
        } catch {
            ELOG("Failed to initialize LibretroDB: \(error)")
        }
#endif

#if canImport(TheGamesDB)
        // Initialize TheGamesDB
        do {
            DLOG("Initializing TheGamesDB...")
            let db = try await TheGamesDB()
            self.theGamesDB = db
            DLOG("TheGamesDB initialized successfully")
        } catch {
            ELOG("Failed to initialize TheGamesDB: \(error)")
        }
#endif

#if canImport(ShiraGame)
        // Initialize ShiraGame
        do {
            DLOG("Initializing ShiraGame DB...")
            let game = try await ShiraGame()
            self.shiraGame = game
            DLOG("ShiraGame DB initialized successfully")
        } catch {
            ELOG("Failed to initialize ShiraGame: \(error)")
        }
#endif

        isInitializing = false
        ILOG("Database initialization complete")
    }

    // MARK: - Cache Helpers

    private func cachedMD5Result(for key: String) -> CachedLookup<ROMMetadata>? {
        guard var entry = md5Cache[key] else { return nil }
        entry.lastAccess = Date().timeIntervalSinceReferenceDate
        md5Cache[key] = entry
        if let value = entry.value {
            return .hit(value)
        } else {
            return .miss
        }
    }

    private func cacheMD5Result(_ value: ROMMetadata?, for key: String) {
        md5Cache[key] = CacheEntry(value: value, lastAccess: Date().timeIntervalSinceReferenceDate)
        pruneMD5CacheIfNeeded()
    }

    private func pruneMD5CacheIfNeeded() {
        guard md5Cache.count > md5CacheLimit else { return }
        let overflow = md5Cache.count - md5CacheLimit
        let keysByAge = md5Cache
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
            .prefix(overflow)
            .map { $0.key }

        for key in keysByAge {
            md5Cache.removeValue(forKey: key)
        }
    }

    private func cachedFilenameResult(for key: FilenameCacheKey) -> CachedLookup<[ROMMetadata]>? {
        guard var entry = filenameCache[key] else { return nil }
        entry.lastAccess = Date().timeIntervalSinceReferenceDate
        filenameCache[key] = entry
        if let value = entry.value {
            return .hit(value)
        } else {
            return .miss
        }
    }

    private func cacheFilenameResult(_ value: [ROMMetadata]?, for key: FilenameCacheKey) {
        filenameCache[key] = CacheEntry(value: value, lastAccess: Date().timeIntervalSinceReferenceDate)
        pruneFilenameCacheIfNeeded()
    }

    private func pruneFilenameCacheIfNeeded() {
        guard filenameCache.count > filenameCacheLimit else { return }
        let overflow = filenameCache.count - filenameCacheLimit
        let keysByAge = filenameCache
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
            .prefix(overflow)
            .map { $0.key }

        for key in keysByAge {
            filenameCache.removeValue(forKey: key)
        }
    }

    private func cachedSerialResult(for key: String) -> CachedLookup<ROMMetadata>? {
        guard var entry = serialCache[key] else { return nil }
        entry.lastAccess = Date().timeIntervalSinceReferenceDate
        serialCache[key] = entry
        if let value = entry.value {
            return .hit(value)
        } else {
            return .miss
        }
    }

    private func cacheSerialResult(_ value: ROMMetadata?, for key: String) {
        serialCache[key] = CacheEntry(value: value, lastAccess: Date().timeIntervalSinceReferenceDate)
        pruneSerialCacheIfNeeded()
    }

    private func pruneSerialCacheIfNeeded() {
        guard serialCache.count > serialCacheLimit else { return }
        let overflow = serialCache.count - serialCacheLimit
        let keysByAge = serialCache
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
            .prefix(overflow)
            .map { $0.key }

        for key in keysByAge {
            serialCache.removeValue(forKey: key)
        }
    }

    // Helper to ensure databases are initialized
    internal func ensureDatabasesInitialized() async throws {
        if isInitializing {
            // Wait a bit for initialization to complete
            try await Task.sleep(nanoseconds: 1_000_000_000)
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
        /// Start time for overall search
        let searchStartTime = Date()
        ILOG("PVLookup: Starting ROM search for MD5: \(md5)")
        let upperMD5 = md5.uppercased()

        if let cached = cachedMD5Result(for: upperMD5) {
            switch cached {
            case .hit(let metadata):
                ILOG("PVLookup: Returning cached ROM metadata for MD5: \(upperMD5)")
                return metadata
            case .miss:
                ILOG("PVLookup: Cached ROM miss for MD5: \(upperMD5)")
                return nil
            }
        }

        /// Run OpenVGDB and LibretroDB searches in parallel
        var openVGDBMetadata: ROMMetadata?
        var libretroDBMetadata: ROMMetadata?
        await withTaskGroup(of: (Int, ROMMetadata?).self) { group in
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB search took \(String(format: "%.3f", duration))s")
                }
                guard let openVGDB = await self.getOpenVGDB() else { return (0, nil) }
                return (0, try? await openVGDB.searchROM(byMD5: upperMD5))
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB search took \(String(format: "%.3f", duration))s")
                }
                guard let libreTroDB = await self.isolatedLibretroDB else { return (1, nil) }
                return (1, try? await libreTroDB.searchROM(byMD5: upperMD5))
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBMetadata = result
                case 1: libretroDBMetadata = result
                default: break
                }
            }
        }

        /// Await and merge results from primary databases

        if let mergedResult = openVGDBMetadata?.merged(with: libretroDBMetadata) ?? libretroDBMetadata?.merged(with: openVGDBMetadata) ?? openVGDBMetadata ?? libretroDBMetadata {
            cacheMD5Result(mergedResult, for: upperMD5)
            let duration = Date().timeIntervalSince(searchStartTime)
            ILOG("PVLookup: Found result in primary databases (took \(String(format: "%.3f", duration))s)")
            return mergedResult
        }

        /// If no results and ShiraGame is enabled, try it as last resort
        if databases.contains(.shiraGame) {
            ILOG("PVLookup: No results from primary databases, trying ShiraGame...")
            let shiraStartTime = Date()
            defer {
                let duration = Date().timeIntervalSince(shiraStartTime)
                DLOG("ShiraGame search took \(String(format: "%.3f", duration))s")
            }

            let shiraGameResult = try? await getShiraGame()?.searchROM(byMD5: md5.lowercased())
            cacheMD5Result(shiraGameResult, for: upperMD5)
            DLOG("PVLookup: ShiraGame result: \(String(describing: shiraGameResult))")

            let totalDuration = Date().timeIntervalSince(searchStartTime)
            ILOG("PVLookup: Total search completed in \(String(format: "%.3f", totalDuration))s")
            return shiraGameResult
        }

        cacheMD5Result(nil, for: upperMD5)
        let totalDuration = Date().timeIntervalSince(searchStartTime)
        ILOG("PVLookup: No results found (search took \(String(format: "%.3f", totalDuration))s)")
        return nil
    }

    /// Search for a ROM by CRC32 hash.
    /// CRC32 can be read from ZIP, 7z, RAR, and LZH archive central directories without decompressing,
    /// making this a fast path for identifying ROMs inside archives.
    public func searchROM(byCRC crc: String) async throws -> ROMMetadata? {
        let upperCRC = crc.uppercased()
        ILOG("PVLookup: Starting ROM search for CRC: \(upperCRC)")

        if let openVGDB = await getOpenVGDB() {
            do {
                if let result = try await openVGDB.searchROM(byCRC: upperCRC) {
                    return result
                }
            } catch {
                ELOG("PVLookup: CRC search failed for \(upperCRC): \(error.localizedDescription)")
            }
        }
        return nil
    }

    /// Search for a ROM by disc serial / product code.
    /// Queries OpenVGDB (romSerial column) and LibretroDB (serial_id column) in parallel,
    /// merges results, and caches the answer to prevent duplicate DB round-trips.
    public func searchROM(bySerial serial: String, systemID: SystemIdentifier?) async throws -> ROMMetadata? {
        let cacheKey = "\(serial.uppercased()):\(systemID?.rawValue ?? "")"
        ILOG("PVLookup: Starting ROM search for serial: \(serial)")

        if let cached = cachedSerialResult(for: cacheKey) {
            switch cached {
            case .hit(let metadata):
                ILOG("PVLookup: Returning cached serial result for: \(serial)")
                return metadata
            case .miss:
                ILOG("PVLookup: Cached serial miss for: \(serial)")
                return nil
            }
        }

        var openVGDBResult: ROMMetadata?
        var libretroDBResult: ROMMetadata?

        await withTaskGroup(of: (Int, ROMMetadata?).self) { group in
            group.addTask {
                guard let openVGDB = await self.getOpenVGDB() else { return (0, nil) }
                return (0, try? await openVGDB.searchROM(bySerial: serial, systemID: systemID))
            }
            group.addTask {
                guard let libreTroDB = await self.isolatedLibretroDB else { return (1, nil) }
                return (1, try? await libreTroDB.searchROM(bySerial: serial, systemID: systemID))
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBResult = result
                case 1: libretroDBResult = result
                default: break
                }
            }
        }

        let merged = openVGDBResult?.merged(with: libretroDBResult)
            ?? libretroDBResult?.merged(with: openVGDBResult)
            ?? openVGDBResult
            ?? libretroDBResult

        cacheSerialResult(merged, for: cacheKey)
        ILOG("PVLookup: Serial search result for \(serial): \(merged?.gameTitle ?? "nil")")
        return merged
    }

    /// Search database by CRC32, returning all matches.
    public func searchDatabase(usingCRC crc: String, systemID: SystemIdentifier? = nil) async throws -> [ROMMetadata]? {
        let upperCRC = crc.uppercased()

        if let openVGDB = await getOpenVGDB() {
            return try await openVGDB.searchByCRC(upperCRC, systemID: systemID)
        }
        return nil
    }

    public func searchDatabase(usingFilename filename: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        /// Start time for overall search
        let searchStartTime = Date()
        ILOG("PVLookup: Starting database search for filename: \(filename), systemID: \(String(describing: systemID))")
        let normalizedFilename = filename.lowercased()
        let cacheKey = FilenameCacheKey(filename: normalizedFilename, systemIdentifier: systemID?.rawValue)

        if let cached = cachedFilenameResult(for: cacheKey) {
            switch cached {
            case .hit(let metadata):
                ILOG("PVLookup: Returning cached filename search for \(filename) (\(systemID?.rawValue ?? "any"))")
                return metadata
            case .miss:
                ILOG("PVLookup: Cached filename miss for \(filename) (\(systemID?.rawValue ?? "any"))")
                return nil
            }
        }

        /// Check which databases are enabled before starting parallel tasks
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)
        let shouldSearchShiraGame = databases.contains(.shiraGame)
        let shouldSearchTheGamesDB = databases.contains(.theGamesDB)

        /// Run all database searches in parallel
        var openVGDBResults: [ROMMetadata] = []
        var libretroDatabaseResults: [ROMMetadata] = []
        var shiraGameResults: [ROMMetadata] = []
        var theGamesDBResults: [ROMMetadata] = []
        await withTaskGroup(of: (Int, [ROMMetadata]).self) { group in
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchOpenVGDB,
                   let results = try? await self.openVGDB?.searchDatabase(usingFilename: filename, systemID: systemID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (0, results)
                }
                return (0, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchLibretro,
                   let results = try? await self.isolatedLibretroDB?.searchMetadata(usingFilename: filename, systemID: systemID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (1, results)
                }
                return (1, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("ShiraGame search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchShiraGame,
                   let results = try? await self.shiraGame?.searchDatabase(usingFilename: filename, systemID: systemID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("ShiraGame search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (2, results)
                }
                return (2, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchTheGamesDB,
                   let results = try? await self.isolatedTheGamesDB?.searchGames(name: filename, platformId: systemID?.theGamesDBID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (3, results)
                }
                return (3, [])
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBResults = result
                case 1: libretroDatabaseResults = result
                case 2: shiraGameResults = result
                case 3: theGamesDBResults = result
                default: break
                }
            }
        }

        /// Combine results
        let results = openVGDBResults + libretroDatabaseResults + shiraGameResults + theGamesDBResults

        let totalDuration = Date().timeIntervalSince(searchStartTime)
        cacheFilenameResult(results.isEmpty ? nil : results, for: cacheKey)
        if results.isEmpty {
            ILOG("PVLookup: No results found (search took \(String(format: "%.3f", totalDuration))s)")
            return nil
        } else {
            ILOG("PVLookup: Found \(results.count) total results (search took \(String(format: "%.3f", totalDuration))s)")
            return results
        }
    }

    public func searchDatabase(usingFilename filename: String, systemIDs: [SystemIdentifier]) async throws -> [ROMMetadata]? {
        var results: [ROMMetadata] = []

        // Search each system ID
        for systemID in systemIDs {
            if let systemResults = try await searchDatabase(usingFilename: filename, systemID: systemID) {
                results.append(contentsOf: systemResults)
            }
        }

        // Add TheGamesDB search for all requested systems
        let theGamesDBPlatformIds = systemIDs.compactMap { $0.theGamesDBID }
        for platformId in theGamesDBPlatformIds {
            if let theGamesDBResults = try theGamesDB?.searchGames(name: filename, platformId: platformId) {
                let metadata = theGamesDBResults.compactMap { game -> ROMMetadata? in
                    let gameTitle = game.gameTitle
                     let systemID = game.systemID
                    guard systemIDs.contains(systemID) else {
                        return nil
                    }

                    return ROMMetadata(
                        gameTitle: gameTitle,
                        systemID: systemID,
                        romFileName: filename,
                        source: "TheGamesDB"
                    )
                }
                results.append(contentsOf: metadata)
            }
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

        /// Check which databases are enabled
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)
        let shouldSearchTheGamesDB = databases.contains(.theGamesDB)

        /// Run artwork mapping queries in parallel
        var openVGDB: ArtworkMapping?
        var libreTroDB: ArtworkMapping?
        var theGamesDB: ArtworkMapping?
        await withTaskGroup(of: (Int, ArtworkMapping?).self) { group in
            group.addTask {
                guard shouldSearchOpenVGDB else { return (0, nil) }
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork mappings took \(String(format: "%.3f", duration))s")
                }
                guard let openVGDB = await self.isolatedOpenVGDB else { return (0, nil) }
                return (0, try? openVGDB.getArtworkMappings())
            }
            group.addTask {
                guard shouldSearchLibretro else { return (1, nil) }
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork mappings took \(String(format: "%.3f", duration))s")
                }
                guard let libreTroDB = await self.isolatedLibretroDB else { return (1, nil) }
                return (1, try? libreTroDB.getArtworkMappings())
            }
            group.addTask {
                guard shouldSearchTheGamesDB else { return (2, nil) }
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork mappings took \(String(format: "%.3f", duration))s")
                }
                guard let theGamesDB = await self.getTheGamesDB() else { return (2, nil) }
                return (2, try? await theGamesDB.getArtworkMappings())
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDB = result
                case 1: libreTroDB = result
                case 2: theGamesDB = result
                default: break
                }
            }
        }

        /// Merge results
        var mergedMD5: [String: [String: String]] = [:]
        var mergedFilenames: [String: String] = [:]

        if let openVGDB {
            mergedMD5.merge(openVGDB.romMD5) { _, new in new }
            mergedFilenames.merge(openVGDB.romFileNameToMD5) { _, new in new }
        }

        if let libreTroDB {
            mergedMD5.merge(libreTroDB.romMD5) { _, new in new }
            mergedFilenames.merge(libreTroDB.romFileNameToMD5) { _, new in new }
        }

        if let theGamesDB {
            mergedMD5.merge(theGamesDB.romMD5) { _, new in new }
            mergedFilenames.merge(theGamesDB.romFileNameToMD5) { _, new in new }
        }

        /// Verify we got some mappings
        if mergedMD5.isEmpty && mergedFilenames.isEmpty {
            WLOG("No artwork mappings found from any database")
        }

        return ArtworkMappings(
            romMD5: mergedMD5,
            romFileNameToMD5: mergedFilenames
        )
    }

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        // Early validation
        guard !rom.gameTitle.isEmpty, rom.systemID != .Unknown else {
            return nil
        }

        try await ensureDatabasesInitialized()

        let searchStartTime = Date()
        ILOG("PVLookup: Starting artwork URL search for ROM: \(rom.gameTitle)")

        /// Check which databases are enabled
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)
        let shouldSearchTheGamesDB = databases.contains(.theGamesDB)

        /// Run artwork URL queries in parallel
        var openVGDBUrls: [URL] = []
        var libretroDBArtworkUrls: [URL] = []
        var theGamesDBUrls: [URL] = []
        await withTaskGroup(of: (Int, [URL]).self) { group in
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork URLs lookup took \(String(format: "%.3f", duration))s")
                }
                if shouldSearchOpenVGDB,
                   let openVGDB = await self.isolatedOpenVGDB,
                   let urls = try? openVGDB.getArtworkURLs(forRom: rom) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB found \(urls.count) artwork URLs (\(String(format: "%.3f", duration))s)")
                    return (0, urls)
                }
                return (0, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork URLs lookup took \(String(format: "%.3f", duration))s")
                }
                if shouldSearchLibretro,
                   let libreTroDB = await self.isolatedLibretroDB,
                   let urls = try? await libreTroDB.getArtworkURLs(forRom: rom) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB found \(urls.count) artwork URLs (\(String(format: "%.3f", duration))s)")
                    return (1, urls)
                }
                return (1, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork URLs lookup took \(String(format: "%.3f", duration))s")
                }
                if shouldSearchTheGamesDB,
                   let theGamesDB = await self.getTheGamesDB(),
                   let urls = try? await theGamesDB.getArtworkURLs(forRom: rom) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB found \(urls.count) artwork URLs (\(String(format: "%.3f", duration))s)")
                    return (2, urls)
                }
                return (2, [])
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBUrls = result
                case 1: libretroDBArtworkUrls = result
                case 2: theGamesDBUrls = result
                default: break
                }
            }
        }

        /// Await and combine all results
        let urls = openVGDBUrls + libretroDBArtworkUrls + theGamesDBUrls

        let totalDuration = Date().timeIntervalSince(searchStartTime)
        if urls.isEmpty {
            ILOG("PVLookup: No artwork URLs found (search took \(String(format: "%.3f", totalDuration))s)")
            return nil
        } else {
            ILOG("PVLookup: Found \(urls.count) total artwork URLs (search took \(String(format: "%.3f", totalDuration))s)")
            return urls
        }
    }

    // MARK: - MD5 Searching

    /// Get SystemIdentifier for a ROM using MD5 or filename
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback
    /// - Returns: SystemIdentifier if found
    public func systemIdentifier(forRomMD5 md5: String, or filename: String?) async throws -> SystemIdentifier? {
        return try await systemIdentifier(forRomMD5: md5, or: filename, constrainedToSystems: nil)
    }

    /// Get SystemIdentifier for a ROM using MD5 or filename, constrained to specific systems
    /// - Parameters:
    ///   - md5: MD5 hash of the ROM
    ///   - filename: Optional filename as fallback (only used if extension is known/limited systems)
    ///   - constrainedToSystems: Optional array of systems to search within (nil = search all systems)
    ///   - allowFilenameSearch: Whether to search by filename (should be false for unknown extensions)
    /// - Returns: SystemIdentifier if found
    public func systemIdentifier(
        forRomMD5 md5: String,
        or filename: String?,
        constrainedToSystems: [SystemIdentifier]?,
        allowFilenameSearch: Bool = true
    ) async throws -> SystemIdentifier? {
        let upperMD5 = md5.uppercased()
        var identifier: SystemIdentifier?

        #if canImport(OpenVGDB)
        // Try OpenVGDB first
        if let openVGDB = await isolatedOpenVGDB {
            // If constrained, try each system individually
            if let constrainedSystems = constrainedToSystems, !constrainedSystems.isEmpty {
                for systemID in constrainedSystems {
                    // Search by MD5 with system constraint
                    if let results = try? await openVGDB.searchByMD5(upperMD5, systemID: systemID),
                       let firstResult = results.first {
                        identifier = firstResult.systemID
                        break
                    }

                    // If filename search allowed and no MD5 match, try filename
                    if identifier == nil && allowFilenameSearch,
                       let filename = filename,
                       let results = try? await openVGDB.searchDatabase(usingFilename: filename, systemID: systemID),
                       let firstResult = results.first {
                        identifier = firstResult.systemID
                        break
                    }
                }
            } else {
                // Unconstrained search (original behavior)
                if let systemID = try await openVGDB.system(forRomMD5: upperMD5, or: filename),
                   let systemIdentifier = SystemIdentifier.fromOpenVGDBID(systemID) {
                    identifier = systemIdentifier
                }
            }
        }
        #endif

        #if canImport(libretrodb)
        // If no result from OpenVGDB, try LibretroDB
        if identifier == nil {
            if let constrainedSystems = constrainedToSystems, !constrainedSystems.isEmpty {
                for systemID in constrainedSystems {
                    // Search by MD5 with system constraint
                    if let results = try? await isolatedLibretroDB?.searchMetadata(usingKey: "md5", value: upperMD5, systemID: systemID),
                       let firstResult = results.first {
                        identifier = firstResult.systemID
                        break
                    }

                    // If filename search allowed and no MD5 match, try filename
                    if identifier == nil && allowFilenameSearch,
                       let filename = filename,
                       let results = try? await isolatedLibretroDB?.searchMetadata(usingFilename: filename, systemID: systemID),
                       let firstResult = results.first {
                        identifier = firstResult.systemID
                        break
                    }
                }
            } else {
                // Unconstrained search
                if let libreTroDB = await isolatedLibretroDB {
                    if let systemID = try await libreTroDB.systemIdentifier(forRomMD5: upperMD5, or: filename) {
                        identifier = systemID
                    }
                }
            }
        }
        #endif

        #if canImport(ShiraGame)
        // If still no result, try ShiraGame (only if constrained search didn't find anything)
        if identifier == nil {
            if let constrainedSystems = constrainedToSystems, !constrainedSystems.isEmpty {
                // Only search ShiraGame if we have a limited set and MD5 match is important
                // ShiraGame doesn't support system constraints, so skip it for constrained searches
            } else if let shiraGame = await getShiraGame() {
                if let systemID = try await shiraGame.system(forRomMD5: upperMD5, or: filename),
                   let shiraIdentifier = SystemIdentifier.fromShiraGameID(String(systemID)) {
                    identifier = shiraIdentifier
                }
            }
        }
        #endif

        DLOG("System identifier result for MD5: \(upperMD5), filename: \(filename ?? "nil"), constrained: \(constrainedToSystems?.map { $0.rawValue }.joined(separator: ",") ?? "none"): \(String(describing: identifier))")
        return identifier
    }


    /// Search for all possible ROMs for a MD5, with optional narrowing to specific `SystemIdentifier`
    /// - Parameters:
    ///   - md5: md5 hash, preferabbly uppercased though we'll manage that for you
    ///   - systemID: System ID optinally to filter on
    /// - Returns: Optional array of `ROMMetadata`
    public func searchDatabase(usingMD5 md5: String, systemID: SystemIdentifier?) async throws -> [ROMMetadata]? {
        let searchStartTime = Date()
        let upperMD5 = md5.uppercased()
        ILOG("PVLookup: Starting database search for MD5: \(upperMD5), systemID: \(String(describing: systemID))")

        /// Check which databases are enabled
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)

        /// Run database searches in parallel
        var openVGDB: [ROMMetadata] = []
        var libreTroDB: [ROMMetadata] = []
        await withTaskGroup(of: (Int, [ROMMetadata]).self) { group in
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB MD5 search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchOpenVGDB,
                   let openVGDB = await self.isolatedOpenVGDB,
                   let results = try? openVGDB.searchDatabase(usingKey: "romHashMD5", value: upperMD5, systemID: systemID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB MD5 search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (0, results)
                }
                return (0, [])
            }
            group.addTask {
                let startTime = Date()
                defer {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB MD5 search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                if shouldSearchLibretro,
                   let libreTroDB = await self.isolatedLibretroDB,
                   let results = try? await libreTroDB.searchMetadata(usingKey: "md5", value: upperMD5, systemID: systemID) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB MD5 search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (1, results)
                }
                return (1, [])
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDB = result
                case 1: libreTroDB = result
                default: break
                }
            }
        }

        /// Merge results with MD5 deduplication
        var resultsByMD5: [String: ROMMetadata] = [:]

        for result in openVGDB {
            if let resultMD5 = result.romHashMD5?.uppercased() {
                resultsByMD5[resultMD5] = result
            }
        }

        for result in libreTroDB {
            if let resultMD5 = result.romHashMD5?.uppercased() {
                if let existing = resultsByMD5[resultMD5] {
                    resultsByMD5[resultMD5] = existing.merged(with: result)
                } else {
                    resultsByMD5[resultMD5] = result
                }
            }
        }

        let results = Array(resultsByMD5.values)

        let totalDuration = Date().timeIntervalSince(searchStartTime)
        if results.isEmpty {
            ILOG("PVLookup: No results found for MD5 search (took \(String(format: "%.3f", totalDuration))s)")
            return nil
        } else {
            ILOG("PVLookup: Found \(results.count) total results for MD5 search (took \(String(format: "%.3f", totalDuration))s)")
            return results
        }
    }

    /// Search for artwork by game name across all services
    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        try await ensureDatabasesInitialized()

        let searchStartTime = Date()
        ILOG("PVLookup: Starting artwork search for game: \(name), systemID: \(String(describing: systemID))")

        /// Check which databases are enabled
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)
        let shouldSearchTheGamesDB = databases.contains(.theGamesDB)

        /// Run artwork searches in parallel
        var openVGDBArtwork: [ArtworkMetadata] = []
        var libretroDBArtwork: [ArtworkMetadata] = []
        var theGamesDBartwork: [ArtworkMetadata] = []
        await withTaskGroup(of: (Int, [ArtworkMetadata]).self) { group in
            group.addTask {
                guard shouldSearchOpenVGDB else {
                    ILOG("shouldSearchOpenVGDB false, skipping...")
                    return (0, [])
                }
                let startTime = Date()
                if let results = try? await self.openVGDB?.searchArtwork(
                    byGameName: name,
                    systemID: systemID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (0, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (0, [])
            }
            group.addTask {
                guard shouldSearchLibretro else {
                    ILOG("shouldSearchLibretro false, skipping...")
                    return (1, [])
                }
                let startTime = Date()
                if let results = try? await self.libreTroDB?.searchArtwork(
                    byGameName: name,
                    systemID: systemID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (1, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (1, [])
            }
            group.addTask {
                guard shouldSearchTheGamesDB else {
                    ILOG("shouldSearchTheGamesDB false, skipping...")
                    return (2, [])
                }
                let startTime = Date()
                if let theGamesDB = await self.getTheGamesDB(),
                   let results = try? await theGamesDB.searchArtwork(
                    byGameName: name,
                    systemID: systemID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork search took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (2, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (2, [])
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBArtwork = result
                case 1: libretroDBArtwork = result
                case 2: theGamesDBartwork = result
                default: break
                }
            }
        }

        /// Combine all results
        let results = openVGDBArtwork + libretroDBArtwork + theGamesDBartwork

        // Sort artwork by type priority
        let sortedArtwork = sortArtworkByType(results)

        let totalDuration = Date().timeIntervalSince(searchStartTime)

        // Cache results
        if !sortedArtwork.isEmpty {
            let cacheKey = ArtworkSearchKey(
                gameName: name,
                systemID: systemID,
                artworkTypes: artworkTypes ?? .defaults
            )
            await ArtworkSearchCache.shared.set(key: cacheKey, results: sortedArtwork)
            ILOG("PVLookup: Found and cached \(sortedArtwork.count) artwork results (search took \(String(format: "%.3f", totalDuration))s)")
        } else {
            ILOG("PVLookup: No artwork found (search took \(String(format: "%.3f", totalDuration))s)")
        }

        return sortedArtwork.isEmpty ? nil : sortedArtwork
    }

    /// Get artwork for a specific game ID across all services
    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        let searchStartTime = Date()
        ILOG("PVLookup: Starting artwork search for gameID: \(gameID)")

        /// Check which databases are enabled
        let shouldSearchOpenVGDB = databases.contains(.openVGDB)
        let shouldSearchLibretro = databases.contains(.libretro)
        let shouldSearchTheGamesDB = databases.contains(.theGamesDB)

        /// Run artwork queries in parallel
        var openVGDBArtwork: [ArtworkMetadata] = []
        var libretroDBArtwork: [ArtworkMetadata] = []
        var theGamesDBartwork: [ArtworkMetadata] = []
        await withTaskGroup(of: (Int, [ArtworkMetadata]).self) { group in
            group.addTask {
                guard shouldSearchOpenVGDB else {
                    ILOG("shouldSearchOpenVGDB false, skipping...")
                    return (0, [])
                }
                let startTime = Date()
                if let results = try? await self.openVGDB?.getArtwork(
                    forGameID: gameID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork lookup took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (0, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("OpenVGDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (0, [])
            }
            group.addTask {
                guard shouldSearchLibretro else {
                    ILOG("shouldSearchLibretro false, skipping...")
                    return (1, [])
                }
                let startTime = Date()
                if let results = try? await self.libreTroDB?.getArtwork(
                    forGameID: gameID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork lookup took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (1, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("LibretroDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (1, [])
            }
            group.addTask {
                guard shouldSearchTheGamesDB else {
                    ILOG("shouldSearchTheGamesDB false, skipping...")
                    return (2, [])
                }
                let startTime = Date()
                if let theGamesDB = await self.getTheGamesDB(),
                   let results = try? await theGamesDB.getArtwork(
                    forGameID: gameID,
                    artworkTypes: artworkTypes
                   ) {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork lookup took \(String(format: "%.3f", duration))s - found \(results.count) results")
                    return (2, results)
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    DLOG("TheGamesDB artwork search took \(String(format: "%.3f", duration))s - found \(0) results")
                }
                return (2, [])
            }
            for await (tag, result) in group {
                switch tag {
                case 0: openVGDBArtwork = result
                case 1: libretroDBArtwork = result
                case 2: theGamesDBartwork = result
                default: break
                }
            }
        }

        /// Await and combine all results
        let results = openVGDBArtwork + libretroDBArtwork + theGamesDBartwork

        // Sort artwork by type priority
        let sortedArtwork = sortArtworkByType(results)

        let totalDuration = Date().timeIntervalSince(searchStartTime)
        if sortedArtwork.isEmpty {
            ILOG("PVLookup: No artwork found for gameID (search took \(String(format: "%.3f", totalDuration))s)")
            return nil
        } else {
            ILOG("PVLookup: Found \(sortedArtwork.count) artwork results for gameID (search took \(String(format: "%.3f", totalDuration))s)")
            return sortedArtwork
        }
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
