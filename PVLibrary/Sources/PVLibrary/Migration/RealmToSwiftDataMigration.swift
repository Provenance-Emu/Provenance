//
//  RealmToSwiftDataMigration.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-05.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  One-time migration that copies all Realm data into the SwiftData store
//  on the first launch after an app update.
//
//  Migration order (dependency-safe):
//    1. User_Data          (no dependencies)
//    2. System_Data        (no dependencies)
//    3. Core_Data          (no dependencies)
//    4. Core-System wiring (both above must exist)
//    5. BIOS_Data          (needs System_Data; creates File_Data as needed)
//    6. Game_Data          (needs System_Data; creates File_Data & ImageFile_Data as needed)
//    7. SaveState_Data     (needs Game_Data, Core_Data; may create File_Data & ImageFile_Data)
//    8. Cheats_Data        (needs Game_Data, Core_Data; may create File_Data)
//    9. RecentGame_Data    (needs Game_Data, Core_Data)
//   10. Library_Data       (needs Game_Data)
//
//  Notes:
//  - File_Data and ImageFile_Data records are created opportunistically while migrating
//    other entities; they do not have standalone migration phases.
//  - Validation compares counts for all primary Realm root entities listed above.
//  - Memory: entities are snapshotted and migrated one type at a time so peak memory
//    is bounded by the largest single entity collection rather than the full database.
//
//  Safety guarantees:
//  - Idempotent: guarded by a UserDefaults flag + SwiftData uniqueness constraints
//  - Non-destructive: Realm data is never deleted (caller decides when to remove it)
//  - Validates primary record counts pre- and post-migration
//  - Progress is logged via PVLogging
//

import SwiftData
import Foundation
@preconcurrency import RealmSwift
import PVLogging
import PVPrimitives
import PVRealm

// MARK: - Public types

/// Errors thrown by ``RealmToSwiftDataMigration``.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
public enum RealmToSwiftDataMigrationError: Error, LocalizedError {
    case realmUnavailable(underlying: Error)
    case swiftDataContextError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .realmUnavailable(let e):
            return "Could not open Realm: \(e.localizedDescription)"
        case .swiftDataContextError(let e):
            return "SwiftData context error: \(e.localizedDescription)"
        }
    }
}

/// Progress snapshot emitted during migration.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
public struct MigrationProgress: Sendable {
    public let entity: String
    /// Number of records actually inserted (skips already-existing records).
    public let migrated: Int
    /// Total number of records in the Realm snapshot for this entity.
    public let total: Int
    public var fraction: Double { total > 0 ? Double(migrated) / Double(total) : 1.0 }
}

/// Batch size used when inserting records into SwiftData.
private let kBatchSize = 200

// MARK: - Public API

/// Performs a one-time, idempotent migration from the Realm store to SwiftData.
///
/// Usage:
/// ```swift
/// let container = try PVSwiftDataSchema.makePVModelContainer()
/// let migrator = RealmToSwiftDataMigration(modelContainer: container)
/// try await migrator.migrateIfNeeded { progress in
///     print("\(progress.entity): \(progress.migrated)/\(progress.total)")
/// }
/// ```
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
public actor RealmToSwiftDataMigration {

    // MARK: - Constants

    /// UserDefaults key written after a successful migration.
    /// Exposed as `internal` so tests can reference the key by name without hard-coding it.
    static let migrationCompletedKey = "PVRealmToSwiftDataMigrationCompleted"

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let defaults: UserDefaults
    /// Optional Realm configuration; if `nil` the default configuration is used.
    /// Pass an in-memory configuration in tests for isolation.
    private let realmConfiguration: Realm.Configuration?

    public init(modelContainer: ModelContainer,
                defaults: UserDefaults = .standard,
                realmConfiguration: Realm.Configuration? = nil) {
        self.modelContainer = modelContainer
        self.defaults = defaults
        self.realmConfiguration = realmConfiguration
    }

    // MARK: Entry point

    /// Runs the migration if it has not already been completed.
    ///
    /// - Parameter progressHandler: Optional closure called after each record is inserted.
    /// - Throws: ``RealmToSwiftDataMigrationError`` if migration fails.
    public func migrateIfNeeded(
        progressHandler: (@Sendable (MigrationProgress) -> Void)? = nil
    ) async throws {
        guard !defaults.bool(forKey: Self.migrationCompletedKey) else {
            ILOG("[Migration] Already completed — skipping.")
            return
        }

        // Preflight: if SwiftData already contains root entities, the store is not empty.
        // Mark the flag and skip to prevent creating duplicates when the flag is reset
        // (e.g. via resetMigrationFlag() in debug) against an already-populated store.
        let context = ModelContext(modelContainer)
        let existingGameCount: Int
        do {
            existingGameCount = try context.fetchCount(FetchDescriptor<Game_Data>())
        } catch {
            ELOG("[Migration] Preflight fetch failed — proceeding with migration: \(error)")
            existingGameCount = 0
        }
        if existingGameCount > 0 {
            WLOG("[Migration] SwiftData store already contains \(existingGameCount) games. Marking migration complete to avoid duplicates. Call resetMigrationFlag() on an empty store to force a full re-run.")
            defaults.set(true, forKey: Self.migrationCompletedKey)
            return
        }

        ILOG("[Migration] Starting Realm → SwiftData migration.")
        try await runMigration(progressHandler: progressHandler)
        defaults.set(true, forKey: Self.migrationCompletedKey)
        ILOG("[Migration] Migration complete.")
    }

    /// Resets the completion flag so the migration will run again on the next call
    /// to ``migrateIfNeeded(progressHandler:)``.  Intended for debugging / testing only.
    internal func resetMigrationFlag() {
        defaults.removeObject(forKey: Self.migrationCompletedKey)
        ILOG("[Migration] Reset migration flag.")
    }

    /// Returns `true` if the migration has already been marked as complete.
    public var isMigrationCompleted: Bool {
        defaults.bool(forKey: Self.migrationCompletedKey)
    }

    // MARK: - Private implementation

    private func runMigration(
        progressHandler: (@Sendable (MigrationProgress) -> Void)?
    ) async throws {
        let config = realmConfiguration
        /// Frozen Realm is thread-safe and read-only — safe to use across actor boundaries
        let realm: Realm
        do {
            realm = try await MainActor.run {
                if let config {
                    return try Realm(configuration: config).freeze()
                } else {
                    return try Realm().freeze()
                }
            }
        } catch {
            throw RealmToSwiftDataMigrationError.realmUnavailable(underlying: error)
        }

        // Capture counts before migration for validation; no snapshots are held beyond this.
        let realmCounts: [String: Int] = [
            "User":       realm.objects(PVUser.self).count,
            "System":     realm.objects(PVSystem.self).count,
            "Core":       realm.objects(PVCore.self).count,
            "BIOS":       realm.objects(PVBIOS.self).count,
            "Game":       realm.objects(PVGame.self).count,
            "SaveState":  realm.objects(PVSaveState.self).count,
            "Cheat":      realm.objects(PVCheats.self).count,
            "RecentGame": realm.objects(PVRecentGame.self).count,
            "Library":    realm.objects(PVLibrary.self).count,
        ]

        ILOG("[Migration] Realm counts — systems: \(realmCounts["System"]!), games: \(realmCounts["Game"]!), save states: \(realmCounts["SaveState"]!)")
        ILOG("[Migration] Realm counts — cheats: \(realmCounts["Cheat"]!), BIOSes: \(realmCounts["BIOS"]!), recent games: \(realmCounts["RecentGame"]!)")
        ILOG("[Migration] Realm counts — libraries: \(realmCounts["Library"]!), users: \(realmCounts["User"]!), cores: \(realmCounts["Core"]!)")

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        // Prefetch all existing File_Data and ImageFile_Data records into caches up front.
        // This makes getOrCreateFile/getOrCreateImage idempotent across reruns — not just
        // within a single migration run — so crashes before the flag is set won't create
        // duplicate rows for already-migrated files.
        var fileCache: [String: File_Data] = [:]
        var imageCache: [String: ImageFile_Data] = [:]
        do {
            let existingFiles = try context.fetch(FetchDescriptor<File_Data>())
            for f in existingFiles where !f.partialPath.isEmpty {
                fileCache[f.partialPath] = f
            }
            let existingImages = try context.fetch(FetchDescriptor<ImageFile_Data>())
            for img in existingImages where !img.partialPath.isEmpty {
                imageCache[img.partialPath] = img
            }
        } catch {
            throw RealmToSwiftDataMigrationError.swiftDataContextError(underlying: error)
        }

        do {
            // --- Phase 1: independent leaf objects ---
            // Each phase snapshots its own entity type inline and releases the array
            // after the phase is done, keeping peak memory bounded.

            let users = Array(realm.objects(PVUser.self).map(UserSnapshot.init))
            try migrateUsers(users: users, context: context, progress: progressHandler)
            try saveBatch(context)

            let systems = Array(realm.objects(PVSystem.self).map(SystemSnapshot.init))
            let systemMap = try migrateSystems(systems: systems, context: context, progress: progressHandler)
            try saveBatch(context)

            let cores = Array(realm.objects(PVCore.self).map(CoreSnapshot.init))
            let coreMap = try migrateCores(cores: cores, context: context, progress: progressHandler)
            try saveBatch(context)

            // Wire core ↔ system many-to-many after both are persisted.
            wireCoreSystems(cores: cores, coreMap: coreMap, systemMap: systemMap)
            try saveBatch(context)

            // --- Phase 2: objects that depend on systems/cores ---
            let bioses = Array(realm.objects(PVBIOS.self).map(BIOSSnapshot.init))
            try migrateBIOSes(bioses: bioses, context: context, systemMap: systemMap, fileCache: &fileCache, progress: progressHandler)
            try saveBatch(context)

            // --- Phase 3: games (most complex object) ---
            let games = Array(realm.objects(PVGame.self).map(GameSnapshot.init))
            let gameMap = try migrateGames(games: games, context: context, systemMap: systemMap, fileCache: &fileCache, imageCache: &imageCache, progress: progressHandler)
            try saveBatch(context)

            // --- Phase 4: child objects of games ---
            let saveStates = Array(realm.objects(PVSaveState.self).map(SaveStateSnapshot.init))
            try migrateSaveStates(saveStates: saveStates, context: context, gameMap: gameMap, coreMap: coreMap, fileCache: &fileCache, imageCache: &imageCache, progress: progressHandler)
            try saveBatch(context)

            let cheats = Array(realm.objects(PVCheats.self).map(CheatSnapshot.init))
            try migrateCheats(cheats: cheats, context: context, gameMap: gameMap, coreMap: coreMap, fileCache: &fileCache, progress: progressHandler)
            try saveBatch(context)

            let recentGames = Array(realm.objects(PVRecentGame.self).map(RecentGameSnapshot.init))
            try migrateRecentGames(recentGames: recentGames, context: context, gameMap: gameMap, coreMap: coreMap, progress: progressHandler)
            try saveBatch(context)

            let libraries = Array(realm.objects(PVLibrary.self).map(LibrarySnapshot.init))
            try migrateLibraries(libraries: libraries, context: context, gameMap: gameMap, progress: progressHandler)
            try saveBatch(context)

        } catch let error as RealmToSwiftDataMigrationError {
            throw error
        } catch {
            throw RealmToSwiftDataMigrationError.swiftDataContextError(underlying: error)
        }

        // --- Validation ---
        try validateCounts(realmCounts: realmCounts, context: context)

        ILOG("[Migration] All phases complete.")
    }

    // MARK: - Save helper

    private func saveBatch(_ context: ModelContext) throws {
        try context.save()
    }

    // MARK: - File / Image deduplication helpers

    /// Returns an existing `File_Data` for the given `partialPath`, or inserts and caches a new one.
    /// The cache is pre-populated with all existing SwiftData records at migration start, making
    /// this helper idempotent across reruns (not just within a single run).
    private func getOrCreateFile(
        partialPath: String,
        md5Cache: String? = nil,
        createdDate: Date = Date(),
        context: ModelContext,
        cache: inout [String: File_Data]
    ) -> File_Data {
        if let cached = cache[partialPath] { return cached }
        let f = File_Data(partialPath: partialPath, md5Cache: md5Cache, createdDate: createdDate)
        context.insert(f)
        cache[partialPath] = f
        return f
    }

    /// Returns an existing `ImageFile_Data` for the given `partialPath`, or inserts and caches a new one.
    /// The cache is pre-populated with all existing SwiftData records at migration start, making
    /// this helper idempotent across reruns (not just within a single run).
    private func getOrCreateImage(
        partialPath: String,
        md5Cache: String? = nil,
        createdDate: Date = Date(),
        width: Float = 0,
        height: Float = 0,
        ratio: Float = 0,
        layout: String = "",
        context: ModelContext,
        cache: inout [String: ImageFile_Data]
    ) -> ImageFile_Data {
        if let cached = cache[partialPath] { return cached }
        let img = ImageFile_Data(
            partialPath: partialPath,
            md5Cache: md5Cache,
            createdDate: createdDate,
            width: width,
            height: height,
            ratio: ratio,
            layout: layout
        )
        context.insert(img)
        cache[partialPath] = img
        return img
    }

    // MARK: - Phase implementations

    // MARK: Users

    private func migrateUsers(
        users: [UserSnapshot],
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(users.count) users.")

        // Prefetch all existing User_Data UUIDs once to avoid N+1 per-row queries.
        let existingUsers = try context.fetch(FetchDescriptor<User_Data>())
        var existingUUIDs = Set(existingUsers.map { $0.uuid })
        var insertedCount = 0

        for (idx, u) in users.enumerated() {
            let uuid = u.uuid
            guard !existingUUIDs.contains(uuid) else { continue }

            let obj = User_Data(uuid: uuid, name: u.name, lastSeen: u.lastSeen)
            context.insert(obj)
            existingUUIDs.insert(uuid)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "User", migrated: insertedCount, total: users.count))
        }
    }

    // MARK: Systems

    @discardableResult
    private func migrateSystems(
        systems: [SystemSnapshot],
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: System_Data] {
        ILOG("[Migration] Migrating \(systems.count) systems.")

        // Prefetch all existing System_Data records and index by identifier.
        let existing = try context.fetch(FetchDescriptor<System_Data>())
        var map: [String: System_Data] = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        var insertedCount = 0

        for (idx, s) in systems.enumerated() {
            let identifier = s.identifier
            if map[identifier] != nil { continue }

            let obj = System_Data(
                name: s.name,
                shortName: s.shortName,
                shortNameAlt: s.shortNameAlt,
                manufacturer: s.manufacturer,
                releaseYear: s.releaseYear,
                bit: s.bit,
                headerByteSize: s.headerByteSize,
                openvgDatabaseID: s.openvgDatabaseID,
                requiresBIOS: s.requiresBIOS,
                usesCDs: s.usesCDs,
                portableSystem: s.portableSystem,
                supportsRumble: s.supportsRumble,
                supported: s.supported,
                screenType: s._screenType,
                supportedExtensions: Array(s.supportedExtensions),
                userPreferredCoreID: s.userPreferredCoreID,
                identifier: identifier,
                controlLayoutData: s.controlLayoutData
            )
            context.insert(obj)
            map[identifier] = obj
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "System", migrated: insertedCount, total: systems.count))
        }
        return map
    }

    // MARK: Cores

    @discardableResult
    private func migrateCores(
        cores: [CoreSnapshot],
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: Core_Data] {
        ILOG("[Migration] Migrating \(cores.count) cores.")

        // Prefetch all existing Core_Data records and index by identifier.
        let existing = try context.fetch(FetchDescriptor<Core_Data>())
        var map: [String: Core_Data] = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        var insertedCount = 0

        for (idx, c) in cores.enumerated() {
            let identifier = c.identifier
            if map[identifier] != nil { continue }

            let obj = Core_Data(
                identifier: identifier,
                principleClass: c.principleClass,
                projectName: c.projectName,
                projectURL: c.projectURL,
                projectVersion: c.projectVersion,
                disabled: c.disabled
            )
            context.insert(obj)
            map[identifier] = obj
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Core", migrated: insertedCount, total: cores.count))
        }
        return map
    }

    // MARK: Core ↔ System wiring

    private func wireCoreSystems(
        cores: [CoreSnapshot],
        coreMap: [String: Core_Data],
        systemMap: [String: System_Data]
    ) {
        for coreSnapshot in cores {
            guard let coreObj = coreMap[coreSnapshot.identifier] else { continue }
            for sysId in coreSnapshot.supportedSystemIdentifiers {
                guard let sysObj = systemMap[sysId] else { continue }
                if !coreObj.supportedSystems.contains(where: { $0.identifier == sysId }) {
                    coreObj.supportedSystems.append(sysObj)
                }
            }
        }
    }

    // MARK: BIOSes

    private func migrateBIOSes(
        bioses: [BIOSSnapshot],
        context: ModelContext,
        systemMap: [String: System_Data],
        fileCache: inout [String: File_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(bioses.count) BIOSes.")

        // Prefetch existing BIOS records. Deduplicate by both filename AND md5 to
        // respect the unique constraints on both fields and prevent save failures.
        let existing = try context.fetch(FetchDescriptor<BIOS_Data>())
        var existingByFilename = Set(existing.map { $0.expectedFilename })
        // Normalize MD5s to uppercase to match BIOS_Data's own uppercasing on init.
        var existingByMD5 = Set(existing.map { $0.expectedMD5.uppercased() })
        var insertedCount = 0

        for (idx, b) in bioses.enumerated() {
            let filename = b.expectedFilename
            // Uppercase the MD5 so the dedup check is consistent with BIOS_Data's uppercasing.
            let md5 = b.expectedMD5.uppercased()
            guard !existingByFilename.contains(filename) && !existingByMD5.contains(md5) else { continue }

            let fileData: File_Data? = b.filePartialPath.map {
                getOrCreateFile(partialPath: $0, md5Cache: b.fileMD5Cache, createdDate: b.fileCreatedDate ?? Date(), context: context, cache: &fileCache)
            }

            let obj = BIOS_Data(
                expectedFilename: filename,
                expectedMD5: md5,
                expectedSize: b.expectedSize,
                optional: b.optional,
                descriptionText: b.descriptionText,
                regions: b.regions,
                version: b.version,
                file: fileData,
                system: b.systemIdentifier.flatMap { systemMap[$0] }
            )
            context.insert(obj)
            existingByFilename.insert(filename)
            existingByMD5.insert(md5)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "BIOS", migrated: insertedCount, total: bioses.count))
        }
    }

    // MARK: Games

    @discardableResult
    private func migrateGames(
        games: [GameSnapshot],
        context: ModelContext,
        systemMap: [String: System_Data],
        fileCache: inout [String: File_Data],
        imageCache: inout [String: ImageFile_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: Game_Data] {
        ILOG("[Migration] Migrating \(games.count) games.")

        // Prefetch all existing Game_Data records indexed by md5Hash to avoid N+1 queries.
        let existing = try context.fetch(FetchDescriptor<Game_Data>())
        var map: [String: Game_Data] = Dictionary(uniqueKeysWithValues: existing.map { ($0.md5Hash, $0) })

        // Also track existing Game_Data.id values to detect and handle collisions.
        // Game_Data.id has @Attribute(.unique), but Realm PVGame.id is only indexed
        // (not a primary key), so duplicates in Realm would abort the SwiftData save.
        var existingGameIDs = Set(existing.map { $0.id })

        var insertedCount = 0

        for (idx, g) in games.enumerated() {
            let md5 = g.md5Hash
            if map[md5] != nil { continue }

            // Primary file — reuse an existing File_Data row if this path was already migrated.
            let fileData: File_Data? = g.filePartialPath.map {
                getOrCreateFile(partialPath: $0, md5Cache: g.fileMD5Cache, createdDate: g.fileCreatedDate ?? Date(), context: context, cache: &fileCache)
            }

            // Artwork image — reuse an existing ImageFile_Data row if already migrated.
            let artworkData: ImageFile_Data? = g.artworkPartialPath.map {
                getOrCreateImage(
                    partialPath: $0,
                    width: g.artworkWidth,
                    height: g.artworkHeight,
                    ratio: g.artworkRatio,
                    layout: g.artworkLayout,
                    context: context,
                    cache: &imageCache
                )
            }

            // Related files — snapshot preserves md5Cache and createdDate so metadata is
            // not lost during migration (unlike a plain [String] path list).
            var relatedFiles: [File_Data] = []
            for rf in g.relatedFiles {
                relatedFiles.append(getOrCreateFile(
                    partialPath: rf.partialPath,
                    md5Cache: rf.md5Cache,
                    createdDate: rf.createdDate,
                    context: context,
                    cache: &fileCache
                ))
            }

            var screenshots: [ImageFile_Data] = []
            for ss in g.screenshotPaths {
                screenshots.append(getOrCreateImage(
                    partialPath: ss.partialPath,
                    md5Cache: ss.md5Cache,
                    createdDate: ss.createdDate,
                    width: ss.width,
                    height: ss.height,
                    ratio: ss.ratio,
                    layout: ss.layout,
                    context: context,
                    cache: &imageCache
                ))
            }

            // Resolve the game's unique ID, generating a new UUID if a collision exists.
            // Realm PVGame.id is indexed but not a primary key, so two Realm records can
            // share the same id; SwiftData's @Attribute(.unique) on id would abort the save.
            let gameID: String
            if existingGameIDs.contains(g.id) {
                let newID = UUID().uuidString
                WLOG("[Migration] Game id collision for '\(g.title)' (md5: \(md5)); Realm id=\(g.id) already exists in SwiftData. Assigning new id=\(newID).")
                gameID = newID
            } else {
                gameID = g.id
            }
            existingGameIDs.insert(gameID)

            let obj = Game_Data(
                title: g.title,
                id: gameID,
                romPath: g.romPath,
                file: fileData,
                relatedFiles: relatedFiles,
                customArtworkURL: g.customArtworkURL,
                originalArtworkURL: g.originalArtworkURL,
                originalArtworkFile: artworkData,
                requiresSync: g.requiresSync,
                matchSourceRaw: g.matchSourceRaw,
                userCustomizedFieldsMask: g.userCustomizedFieldsMask,
                lastMetadataLookupDate: g.lastMetadataLookupDate,
                isFavorite: g.isFavorite,
                romSerial: g.romSerial,
                romHeader: g.romHeader,
                importDate: g.importDate,
                systemIdentifier: g.systemIdentifier,
                system: systemMap[g.systemIdentifier],
                md5Hash: md5,
                crc: g.crc,
                userPreferredCoreID: g.userPreferredCoreID,
                screenShots: screenshots,
                lastPlayed: g.lastPlayed,
                playCount: g.playCount,
                timeSpentInGame: g.timeSpentInGame,
                rating: g.rating,
                gameDescription: g.gameDescription,
                boxBackArtworkURL: g.boxBackArtworkURL,
                developer: g.developer,
                publisher: g.publisher,
                publishDate: g.publishDate,
                genres: g.genres,
                referenceURL: g.referenceURL,
                releaseID: g.releaseID,
                regionName: g.regionName,
                regionID: g.regionID,
                systemShortName: g.systemShortName,
                language: g.language
            )
            context.insert(obj)
            map[md5] = obj
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Game", migrated: insertedCount, total: games.count))
        }
        return map
    }

    // MARK: Save States

    private func migrateSaveStates(
        saveStates: [SaveStateSnapshot],
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        fileCache: inout [String: File_Data],
        imageCache: inout [String: ImageFile_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(saveStates.count) save states.")

        // Prefetch all existing SaveState_Data IDs to avoid N+1 queries.
        let existing = try context.fetch(FetchDescriptor<SaveState_Data>())
        var existingIDs = Set(existing.map { $0.id })
        var insertedCount = 0

        for (idx, s) in saveStates.enumerated() {
            let id = s.id
            guard !existingIDs.contains(id) else { continue }

            let fileData: File_Data? = s.filePartialPath.map {
                getOrCreateFile(
                    partialPath: $0,
                    md5Cache: s.fileMD5Cache,
                    createdDate: s.fileCreatedDate ?? Date(),
                    context: context,
                    cache: &fileCache
                )
            }
            let imageData: ImageFile_Data? = s.imagePartialPath.map {
                getOrCreateImage(
                    partialPath: $0,
                    md5Cache: s.imageMD5Cache,
                    createdDate: s.imageCreatedDate ?? Date(),
                    width: s.imageWidth,
                    height: s.imageHeight,
                    ratio: s.imageRatio,
                    layout: s.imageLayout,
                    context: context,
                    cache: &imageCache
                )
            }

            let obj = SaveState_Data(
                id: id,
                date: s.date,
                isAutosave: s.isAutosave,
                createdWithCoreVersion: s.createdWithCoreVersion ?? "",
                lastOpened: s.lastOpened,
                game: s.gameMD5.flatMap { gameMap[$0] },
                core: s.coreIdentifier.flatMap { coreMap[$0] },
                file: fileData,
                image: imageData
            )
            context.insert(obj)
            existingIDs.insert(id)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "SaveState", migrated: insertedCount, total: saveStates.count))
        }
    }

    // MARK: Cheats

    private func migrateCheats(
        cheats: [CheatSnapshot],
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        fileCache: inout [String: File_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(cheats.count) cheats.")

        // Prefetch all existing Cheats_Data IDs to avoid N+1 queries.
        let existing = try context.fetch(FetchDescriptor<Cheats_Data>())
        var existingIDs = Set(existing.map { $0.id })
        var insertedCount = 0

        for (idx, c) in cheats.enumerated() {
            let id = c.id
            guard !existingIDs.contains(id) else { continue }

            let fileData: File_Data? = c.filePartialPath.map {
                getOrCreateFile(
                    partialPath: $0,
                    md5Cache: c.fileMD5Cache,
                    createdDate: c.fileCreatedDate ?? Date(),
                    context: context,
                    cache: &fileCache
                )
            }

            let obj = Cheats_Data(
                id: id,
                code: c.code ?? "",
                enabled: c.enabled,
                date: c.date,
                lastOpened: c.lastOpened,
                type: c.type ?? "",
                codeType: c.codeType,
                createdWithCoreVersion: c.createdWithCoreVersion ?? "",
                game: c.gameMD5.flatMap { gameMap[$0] },
                core: c.coreIdentifier.flatMap { coreMap[$0] },
                file: fileData
            )
            context.insert(obj)
            existingIDs.insert(id)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Cheat", migrated: insertedCount, total: cheats.count))
        }
    }

    // MARK: Recent Games

    private func migrateRecentGames(
        recentGames: [RecentGameSnapshot],
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(recentGames.count) recent games.")

        // Prefetch all existing RecentGame_Data IDs to avoid N+1 queries.
        let existing = try context.fetch(FetchDescriptor<RecentGame_Data>())
        var existingIDs = Set(existing.map { $0.id })
        var insertedCount = 0

        for (idx, r) in recentGames.enumerated() {
            let id = r.id
            guard !existingIDs.contains(id) else { continue }

            let obj = RecentGame_Data(
                id: id,
                game: r.gameMD5.flatMap { gameMap[$0] },
                lastPlayedDate: r.lastPlayedDate,
                core: r.coreIdentifier.flatMap { coreMap[$0] }
            )
            context.insert(obj)
            existingIDs.insert(id)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "RecentGame", migrated: insertedCount, total: recentGames.count))
        }
    }

    // MARK: Libraries

    private func migrateLibraries(
        libraries: [LibrarySnapshot],
        context: ModelContext,
        gameMap: [String: Game_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        ILOG("[Migration] Migrating \(libraries.count) libraries.")

        // Prefetch all existing Library_Data UUIDs to avoid N+1 queries.
        let existing = try context.fetch(FetchDescriptor<Library_Data>())
        var existingUUIDs = Set(existing.map { $0.uuid })
        var insertedCount = 0

        for (idx, l) in libraries.enumerated() {
            let uuid = l.uuid
            guard !existingUUIDs.contains(uuid) else { continue }

            let games = l.gameMD5s.compactMap { gameMap[$0] }
            let obj = Library_Data(
                uuid: uuid,
                name: l.name,
                isLocal: l.isLocal,
                ipaddress: l.ipaddress,
                domainname: l.domainname,
                bonjourName: l.bonjourName,
                port: l.port,
                lastSeen: l.lastSeen,
                games: games
            )
            context.insert(obj)
            existingUUIDs.insert(uuid)
            insertedCount += 1

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Library", migrated: insertedCount, total: libraries.count))
        }
    }

    // MARK: - Validation

    private func validateCounts(realmCounts: [String: Int], context: ModelContext) throws {
        let entityPairs: [(String, () throws -> Int)] = [
            ("Game",       { try context.fetchCount(FetchDescriptor<Game_Data>()) }),
            ("System",     { try context.fetchCount(FetchDescriptor<System_Data>()) }),
            ("Core",       { try context.fetchCount(FetchDescriptor<Core_Data>()) }),
            ("SaveState",  { try context.fetchCount(FetchDescriptor<SaveState_Data>()) }),
            ("Cheat",      { try context.fetchCount(FetchDescriptor<Cheats_Data>()) }),
            ("RecentGame", { try context.fetchCount(FetchDescriptor<RecentGame_Data>()) }),
            ("Library",    { try context.fetchCount(FetchDescriptor<Library_Data>()) }),
            ("User",       { try context.fetchCount(FetchDescriptor<User_Data>()) }),
            ("BIOS",       { try context.fetchCount(FetchDescriptor<BIOS_Data>()) }),
        ]

        for (name, fetchCount) in entityPairs {
            let realmCount = realmCounts[name] ?? 0
            do {
                let sdCount = try fetchCount()
                if sdCount == realmCount {
                    ILOG("[Migration] Validation OK: \(name) — Realm=\(realmCount), SwiftData=\(sdCount)")
                } else if sdCount < realmCount {
                    // Warn only — count may differ due to deduplication (unique constraints).
                    WLOG("[Migration] Validation: \(name) Realm=\(realmCount) SwiftData=\(sdCount). Some records may have been deduplicated or skipped.")
                } else {
                    // SwiftData has more records than Realm — this is suspicious and may indicate duplicate creation during migration.
                    WLOG("[Migration] Validation: \(name) Realm=\(realmCount) SwiftData=\(sdCount). SwiftData has more records than Realm; possible duplicate records created during migration.")
                }
            } catch {
                ELOG("[Migration] Validation failed to fetch SwiftData count for \(name): \(error)")
                throw RealmToSwiftDataMigrationError.swiftDataContextError(underlying: error)
            }
        }
    }
}

// MARK: - Snapshot value types
// Each snapshot struct converts a live Realm object to a plain value type so the data
// can safely cross actor isolation boundaries without holding a Realm reference.
// Snapshots are created inline within each migration phase, keeping peak memory
// bounded to one entity type at a time.

struct SystemSnapshot {
    let identifier: String
    let name: String
    let shortName: String
    let shortNameAlt: String?
    let manufacturer: String
    let releaseYear: Int
    let bit: Int
    let headerByteSize: Int
    let openvgDatabaseID: Int
    let requiresBIOS: Bool
    let usesCDs: Bool
    let portableSystem: Bool
    let supportsRumble: Bool
    let supported: Bool
    let _screenType: String
    let supportedExtensions: [String]
    let userPreferredCoreID: String?
    let controlLayoutData: Data?

    init(_ s: PVSystem) {
        identifier        = s.identifier
        name              = s.name
        shortName         = s.shortName
        shortNameAlt      = s.shortNameAlt
        manufacturer      = s.manufacturer
        releaseYear       = s.releaseYear
        bit               = s.bit
        headerByteSize    = s.headerByteSize
        openvgDatabaseID  = s.openvgDatabaseID
        requiresBIOS      = s.requiresBIOS
        usesCDs           = s.usesCDs
        portableSystem    = s.portableSystem
        supportsRumble    = s.supportsRumble
        supported         = s.supported
        _screenType       = s._screenType
        supportedExtensions = Array(s.supportedExtensions)
        userPreferredCoreID = s.userPreferredCoreID
        controlLayoutData = s.controlLayoutData
    }
}

struct CoreSnapshot {
    let identifier: String
    let principleClass: String
    let projectName: String
    let projectURL: String
    let projectVersion: String
    let disabled: Bool
    let supportedSystemIdentifiers: [String]

    init(_ c: PVCore) {
        identifier        = c.identifier
        principleClass    = c.principleClass
        projectName       = c.projectName
        projectURL        = c.projectURL
        projectVersion    = c.projectVersion
        disabled          = c.disabled
        supportedSystemIdentifiers = c.supportedSystems.map(\.identifier)
    }
}

struct ImageFileSnapshot {
    let partialPath: String
    let width: Float
    let height: Float
    let ratio: Float
    let layout: String
    let md5Cache: String?
    let createdDate: Date

    init(_ img: PVImageFile) {
        partialPath  = img.partialPath
        width        = Float(img.width)
        height       = Float(img.height)
        ratio        = img.ratio
        layout       = img.layout
        md5Cache     = img.md5Cache
        createdDate  = img.createdDate
    }
}

/// Value-type snapshot of a `PVFile` that preserves all metadata (path, md5, date).
/// Used for related-file arrays where a plain `[String]` would lose md5Cache and createdDate.
struct RelatedFileSnapshot {
    let partialPath: String
    let md5Cache: String?
    let createdDate: Date

    init(_ f: PVFile) {
        partialPath  = f.partialPath
        md5Cache     = f.md5Cache
        createdDate  = f.createdDate
    }
}

struct GameSnapshot {
    let id: String
    let title: String
    let md5Hash: String
    let crc: String
    let romPath: String
    let systemIdentifier: String
    let isFavorite: Bool
    let requiresSync: Bool
    let matchSourceRaw: Int
    let userCustomizedFieldsMask: Int
    let lastMetadataLookupDate: Date?
    let romSerial: String?
    let romHeader: String?
    let importDate: Date
    let userPreferredCoreID: String?
    let lastPlayed: Date?
    let playCount: Int
    let timeSpentInGame: Int
    let rating: Int
    let gameDescription: String?
    let boxBackArtworkURL: String?
    let developer: String?
    let publisher: String?
    let publishDate: String?
    let genres: String?
    let referenceURL: String?
    let releaseID: String?
    let regionName: String?
    let regionID: Int?
    let systemShortName: String?
    let language: String?
    let customArtworkURL: String
    let originalArtworkURL: String

    // File info
    let filePartialPath: String?
    let fileMD5Cache: String?
    let fileCreatedDate: Date?

    // Artwork
    let artworkPartialPath: String?
    let artworkWidth: Float
    let artworkHeight: Float
    let artworkRatio: Float
    let artworkLayout: String

    // Related files — full snapshots to preserve md5Cache and createdDate
    let relatedFiles: [RelatedFileSnapshot]

    // Screenshots
    let screenshotPaths: [ImageFileSnapshot]

    init(_ g: PVGame) {
        id                = g.id
        title             = g.title
        md5Hash           = g.md5Hash
        crc               = g.crc
        romPath           = g.romPath
        systemIdentifier  = g.systemIdentifier
        isFavorite               = g.isFavorite
        requiresSync             = g.requiresSync
        matchSourceRaw           = g.matchSourceRaw
        userCustomizedFieldsMask = g.userCustomizedFieldsMask
        lastMetadataLookupDate   = g.lastMetadataLookupDate
        romSerial                = g.romSerial
        romHeader         = g.romHeader
        importDate        = g.importDate
        userPreferredCoreID = g.userPreferredCoreID
        lastPlayed        = g.lastPlayed
        playCount         = g.playCount
        timeSpentInGame   = g.timeSpentInGame
        rating            = g.rating
        gameDescription   = g.gameDescription
        boxBackArtworkURL = g.boxBackArtworkURL
        developer         = g.developer
        publisher         = g.publisher
        publishDate       = g.publishDate
        genres            = g.genres
        referenceURL      = g.referenceURL
        releaseID         = g.releaseID
        regionName        = g.regionName
        regionID          = g.regionID
        systemShortName   = g.systemShortName
        language          = g.language
        customArtworkURL  = g.customArtworkURL
        originalArtworkURL = g.originalArtworkURL

        if let f = g.file, !f.isInvalidated {
            filePartialPath  = f.partialPath
            fileMD5Cache     = f.md5Cache
            fileCreatedDate  = f.createdDate
        } else {
            filePartialPath  = nil
            fileMD5Cache     = nil
            fileCreatedDate  = nil
        }

        if let art = g.originalArtworkFile, !art.isInvalidated {
            artworkPartialPath = art.partialPath
            artworkWidth       = Float(art.width)
            artworkHeight      = Float(art.height)
            artworkRatio       = art.ratio
            artworkLayout      = art.layout
        } else {
            artworkPartialPath = nil
            artworkWidth       = 0
            artworkHeight      = 0
            artworkRatio       = 0
            artworkLayout      = ""
        }

        relatedFiles    = g.relatedFiles.compactMap { $0.isInvalidated ? nil : RelatedFileSnapshot($0) }
        screenshotPaths = g.screenShots.compactMap { $0.isInvalidated ? nil : ImageFileSnapshot($0) }
    }
}

struct SaveStateSnapshot {
    let id: String
    let date: Date
    let isAutosave: Bool
    let createdWithCoreVersion: String?
    let lastOpened: Date?
    let gameMD5: String?
    let coreIdentifier: String?

    // File metadata
    let filePartialPath: String?
    let fileMD5Cache: String?
    let fileCreatedDate: Date?

    // Image metadata
    let imagePartialPath: String?
    let imageMD5Cache: String?
    let imageCreatedDate: Date?
    let imageWidth: Float
    let imageHeight: Float
    let imageRatio: Float
    let imageLayout: String

    init(_ s: PVSaveState) {
        id                     = s.id
        date                   = s.date
        isAutosave             = s.isAutosave
        createdWithCoreVersion = s.createdWithCoreVersion
        lastOpened             = s.lastOpened
        gameMD5                = s.game?.isInvalidated == false ? s.game?.md5Hash : nil
        coreIdentifier         = s.core?.isInvalidated == false ? s.core?.identifier : nil

        if let f = s.file, !f.isInvalidated {
            filePartialPath  = f.partialPath
            fileMD5Cache     = f.md5Cache
            fileCreatedDate  = f.createdDate
        } else {
            filePartialPath  = nil
            fileMD5Cache     = nil
            fileCreatedDate  = nil
        }

        if let img = s.image, !img.isInvalidated {
            imagePartialPath = img.partialPath
            imageMD5Cache    = img.md5Cache
            imageCreatedDate = img.createdDate
            imageWidth       = Float(img.width)
            imageHeight      = Float(img.height)
            imageRatio       = img.ratio
            imageLayout      = img.layout
        } else {
            imagePartialPath = nil
            imageMD5Cache    = nil
            imageCreatedDate = nil
            imageWidth       = 0
            imageHeight      = 0
            imageRatio       = 0
            imageLayout      = ""
        }
    }
}

struct CheatSnapshot {
    let id: String
    let code: String?
    let type: String?
    let codeType: String
    let enabled: Bool
    let date: Date
    let lastOpened: Date?
    let createdWithCoreVersion: String?
    let gameMD5: String?
    let coreIdentifier: String?
    let filePartialPath: String?
    let fileMD5Cache: String?
    let fileCreatedDate: Date?

    init(_ c: PVCheats) {
        id                    = c.id
        code                  = c.code
        type                  = c.type
        codeType              = c.codeType
        enabled               = c.enabled
        date                  = c.date
        lastOpened            = c.lastOpened
        createdWithCoreVersion = c.createdWithCoreVersion
        gameMD5               = c.game?.isInvalidated == false ? c.game?.md5Hash : nil
        coreIdentifier        = c.core?.isInvalidated == false ? c.core?.identifier : nil
        if let f = c.file, !f.isInvalidated {
            filePartialPath  = f.partialPath
            fileMD5Cache     = f.md5Cache
            fileCreatedDate  = f.createdDate
        } else {
            filePartialPath  = nil
            fileMD5Cache     = nil
            fileCreatedDate  = nil
        }
    }
}

struct BIOSSnapshot {
    let expectedFilename: String
    let expectedMD5: String
    let expectedSize: Int
    let optional: Bool
    let descriptionText: String
    let regions: RegionOptions
    let version: String
    let systemIdentifier: String?
    let filePartialPath: String?
    let fileMD5Cache: String?
    let fileCreatedDate: Date?

    init(_ b: PVBIOS) {
        expectedFilename = b.expectedFilename
        expectedMD5      = b.expectedMD5
        expectedSize     = b.expectedSize
        optional         = b.optional
        descriptionText  = b.descriptionText
        regions          = b.regions
        version          = b.version
        systemIdentifier = b.system?.isInvalidated == false ? b.system?.identifier : nil
        if let f = b.file, !f.isInvalidated {
            filePartialPath  = f.partialPath
            fileMD5Cache     = f.md5Cache
            fileCreatedDate  = f.createdDate
        } else {
            filePartialPath  = nil
            fileMD5Cache     = nil
            fileCreatedDate  = nil
        }
    }
}

struct RecentGameSnapshot {
    let id: String
    let gameMD5: String?
    let lastPlayedDate: Date
    let coreIdentifier: String?

    init(_ r: PVRecentGame) {
        id             = r.id
        gameMD5        = r.game?.isInvalidated == false ? r.game?.md5Hash : nil
        lastPlayedDate = r.lastPlayedDate
        coreIdentifier = r.core?.isInvalidated == false ? r.core?.identifier : nil
    }
}

struct LibrarySnapshot {
    let uuid: String
    let name: String
    let isLocal: Bool
    let ipaddress: String
    let domainname: String
    let bonjourName: String
    let port: Int
    let lastSeen: Date
    let gameMD5s: [String]

    init(_ l: PVLibrary) {
        uuid        = l.uuid
        name        = l.name
        isLocal     = l.isLocal
        ipaddress   = l.ipaddress
        domainname  = l.domainname
        bonjourName = l.bonjourName
        port        = l.port
        lastSeen    = l.lastSeen
        gameMD5s    = l.games.compactMap { $0.isInvalidated ? nil : $0.md5Hash }
    }
}

struct UserSnapshot {
    let uuid: String
    let name: String
    let lastSeen: Date

    init(_ u: PVUser) {
        uuid     = u.uuid
        name     = u.name
        lastSeen = u.lastSeen
    }
}
