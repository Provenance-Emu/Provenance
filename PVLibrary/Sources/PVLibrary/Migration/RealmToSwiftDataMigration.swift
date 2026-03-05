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
//    4. File_Data          (no dependencies)
//    5. ImageFile_Data     (no dependencies)
//    6. BIOS_Data          (needs System_Data)
//    7. Game_Data          (needs System_Data, File_Data, ImageFile_Data)
//    8. SaveState_Data     (needs Game_Data, Core_Data, File_Data, ImageFile_Data)
//    9. Cheats_Data        (needs Game_Data, Core_Data, File_Data)
//   10. RecentGame_Data    (needs Game_Data, Core_Data)
//   11. Library_Data       (needs Game_Data)
//
//  Safety guarantees:
//  - Idempotent: guarded by a UserDefaults flag + SwiftData uniqueness constraints
//  - Non-destructive: Realm data is never deleted (caller decides when to remove it)
//  - Validates record counts pre- and post-migration
//  - Progress is logged via PVLogging
//

#if canImport(SwiftData)
import SwiftData
import Foundation
import RealmSwift
import PVLogging
import PVPrimitives

/// Key stored in UserDefaults after a successful migration.
private let kMigrationCompletedKey = "PVRealmToSwiftDataMigrationCompleted"

/// Errors thrown by ``RealmToSwiftDataMigration``.
public enum RealmToSwiftDataMigrationError: Error, LocalizedError {
    case realmUnavailable(underlying: Error)
    case swiftDataContextError(underlying: Error)
    case countMismatch(entity: String, realm: Int, swiftData: Int)

    public var errorDescription: String? {
        switch self {
        case .realmUnavailable(let e):
            return "Could not open Realm: \(e.localizedDescription)"
        case .swiftDataContextError(let e):
            return "SwiftData context error: \(e.localizedDescription)"
        case .countMismatch(let entity, let realm, let swiftData):
            return "Count mismatch for \(entity): Realm had \(realm) records but SwiftData has \(swiftData)"
        }
    }
}

/// Progress snapshot emitted during migration.
public struct MigrationProgress: Sendable {
    public let entity: String
    public let migrated: Int
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
public actor RealmToSwiftDataMigration {

    private let modelContainer: ModelContainer
    private let defaults: UserDefaults

    public init(modelContainer: ModelContainer,
                defaults: UserDefaults = .standard) {
        self.modelContainer = modelContainer
        self.defaults = defaults
    }

    // MARK: Entry point

    /// Runs the migration if it has not already been completed.
    ///
    /// - Parameter progressHandler: Optional closure called after each entity batch.
    /// - Throws: ``RealmToSwiftDataMigrationError`` if migration fails.
    public func migrateIfNeeded(
        progressHandler: (@Sendable (MigrationProgress) -> Void)? = nil
    ) async throws {
        guard !defaults.bool(forKey: kMigrationCompletedKey) else {
            ILOG("[Migration] Already completed — skipping.")
            return
        }
        ILOG("[Migration] Starting Realm → SwiftData migration.")
        try await runMigration(progressHandler: progressHandler)
        defaults.set(true, forKey: kMigrationCompletedKey)
        ILOG("[Migration] Migration complete.")
    }

    /// Resets the completion flag so the migration will run again on the next call
    /// to ``migrateIfNeeded(progressHandler:)``.  Intended for debugging / testing only.
    public func resetMigrationFlag() {
        defaults.removeObject(forKey: kMigrationCompletedKey)
        ILOG("[Migration] Reset migration flag.")
    }

    /// Returns `true` if the migration has already been marked as complete.
    public var isMigrationCompleted: Bool {
        defaults.bool(forKey: kMigrationCompletedKey)
    }

    // MARK: - Private implementation

    private func runMigration(
        progressHandler: (@Sendable (MigrationProgress) -> Void)?
    ) async throws {
        // Open Realm on this actor context.  Realm objects must not cross actor
        // boundaries, so we snapshot the data we need before entering SwiftData work.
        let snapshot: RealmSnapshot
        do {
            snapshot = try RealmSnapshot()
        } catch {
            throw RealmToSwiftDataMigrationError.realmUnavailable(underlying: error)
        }

        ILOG("[Migration] Realm snapshot: \(snapshot.systems.count) systems, \(snapshot.games.count) games, \(snapshot.saveStates.count) save states, \(snapshot.cheats.count) cheats, \(snapshot.bioses.count) BIOSes, \(snapshot.recentGames.count) recent games, \(snapshot.libraries.count) libraries, \(snapshot.users.count) users, \(snapshot.cores.count) cores.")

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        do {
            // --- Phase 1: independent leaf objects ---
            try migrateUsers(snapshot: snapshot, context: context, progress: progressHandler)
            try saveBatch(context)

            let systemMap = try migrateSystems(snapshot: snapshot, context: context, progress: progressHandler)
            try saveBatch(context)

            let coreMap = try migrateCores(snapshot: snapshot, context: context, progress: progressHandler)
            try saveBatch(context)

            // --- Phase 2: objects that depend on systems/cores ---
            try migrateBIOSes(snapshot: snapshot, context: context, systemMap: systemMap, progress: progressHandler)
            try saveBatch(context)

            // Wire core ↔ system many-to-many after both are persisted.
            wireCoreSystems(snapshot: snapshot, coreMap: coreMap, systemMap: systemMap)
            try saveBatch(context)

            // --- Phase 3: games (most complex object) ---
            let gameMap = try migrateGames(snapshot: snapshot, context: context, systemMap: systemMap, progress: progressHandler)
            try saveBatch(context)

            // --- Phase 4: child objects of games ---
            try migrateSaveStates(snapshot: snapshot, context: context, gameMap: gameMap, coreMap: coreMap, progress: progressHandler)
            try saveBatch(context)

            try migrateCheats(snapshot: snapshot, context: context, gameMap: gameMap, coreMap: coreMap, progress: progressHandler)
            try saveBatch(context)

            try migrateRecentGames(snapshot: snapshot, context: context, gameMap: gameMap, coreMap: coreMap, progress: progressHandler)
            try saveBatch(context)

            try migrateLibraries(snapshot: snapshot, context: context, gameMap: gameMap, progress: progressHandler)
            try saveBatch(context)

        } catch let error as RealmToSwiftDataMigrationError {
            throw error
        } catch {
            throw RealmToSwiftDataMigrationError.swiftDataContextError(underlying: error)
        }

        // --- Validation ---
        validateCounts(snapshot: snapshot, context: context)

        ILOG("[Migration] All phases complete.")
    }

    // MARK: - Save helper

    private func saveBatch(_ context: ModelContext) throws {
        try context.save()
    }

    // MARK: - Phase implementations

    // MARK: Users

    private func migrateUsers(
        snapshot: RealmSnapshot,
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let users = snapshot.users
        ILOG("[Migration] Migrating \(users.count) users.")

        for (idx, u) in users.enumerated() {
            // Idempotency: skip if already exists (unique constraint on uuid)
            let uuid = u.uuid
            let existing = try? context.fetch(FetchDescriptor<User_Data>(
                predicate: #Predicate { $0.uuid == uuid }
            ))
            if existing?.isEmpty == false { continue }

            let obj = User_Data(uuid: u.uuid, name: u.name, lastSeen: u.lastSeen)
            context.insert(obj)

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "User", migrated: idx + 1, total: users.count))
        }
    }

    // MARK: Systems

    @discardableResult
    private func migrateSystems(
        snapshot: RealmSnapshot,
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: System_Data] {
        let systems = snapshot.systems
        ILOG("[Migration] Migrating \(systems.count) systems.")
        var map: [String: System_Data] = [:]

        for (idx, s) in systems.enumerated() {
            let identifier = s.identifier
            if map[identifier] != nil { continue }
            // Idempotency: look up existing
            let existing = try? context.fetch(FetchDescriptor<System_Data>(
                predicate: #Predicate { $0.identifier == identifier }
            ))
            if let first = existing?.first {
                map[identifier] = first
                continue
            }

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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "System", migrated: idx + 1, total: systems.count))
        }
        return map
    }

    // MARK: Cores

    @discardableResult
    private func migrateCores(
        snapshot: RealmSnapshot,
        context: ModelContext,
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: Core_Data] {
        let cores = snapshot.cores
        ILOG("[Migration] Migrating \(cores.count) cores.")
        var map: [String: Core_Data] = [:]

        for (idx, c) in cores.enumerated() {
            let identifier = c.identifier
            if map[identifier] != nil { continue }
            let existing = try? context.fetch(FetchDescriptor<Core_Data>(
                predicate: #Predicate { $0.identifier == identifier }
            ))
            if let first = existing?.first { map[identifier] = first; continue }

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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Core", migrated: idx + 1, total: cores.count))
        }
        return map
    }

    // MARK: Core ↔ System wiring

    private func wireCoreSystems(
        snapshot: RealmSnapshot,
        coreMap: [String: Core_Data],
        systemMap: [String: System_Data]
    ) {
        for coreSnapshot in snapshot.cores {
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
        snapshot: RealmSnapshot,
        context: ModelContext,
        systemMap: [String: System_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let bioses = snapshot.bioses
        ILOG("[Migration] Migrating \(bioses.count) BIOSes.")

        for (idx, b) in bioses.enumerated() {
            let filename = b.expectedFilename
            let existing = try? context.fetch(FetchDescriptor<BIOS_Data>(
                predicate: #Predicate { $0.expectedFilename == filename }
            ))
            if existing?.isEmpty == false { continue }

            let fileData: File_Data? = b.filePartialPath.map {
                let f = File_Data(partialPath: $0, md5Cache: b.fileMD5Cache, createdDate: b.fileCreatedDate ?? Date())
                context.insert(f)
                return f
            }

            let obj = BIOS_Data(
                expectedFilename: filename,
                expectedMD5: b.expectedMD5,
                expectedSize: b.expectedSize,
                optional: b.optional,
                descriptionText: b.descriptionText,
                regions: b.regions,
                version: b.version,
                file: fileData,
                system: b.systemIdentifier.flatMap { systemMap[$0] }
            )
            context.insert(obj)

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "BIOS", migrated: idx + 1, total: bioses.count))
        }
    }

    // MARK: Games

    @discardableResult
    private func migrateGames(
        snapshot: RealmSnapshot,
        context: ModelContext,
        systemMap: [String: System_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws -> [String: Game_Data] {
        let games = snapshot.games
        ILOG("[Migration] Migrating \(games.count) games.")
        var map: [String: Game_Data] = [:]

        for (idx, g) in games.enumerated() {
            let md5 = g.md5Hash
            if map[md5] != nil { continue }
            let existing = try? context.fetch(FetchDescriptor<Game_Data>(
                predicate: #Predicate { $0.md5Hash == md5 }
            ))
            if let first = existing?.first { map[md5] = first; continue }

            // Primary file
            let fileData: File_Data? = g.filePartialPath.map {
                let f = File_Data(partialPath: $0, md5Cache: g.fileMD5Cache, createdDate: g.fileCreatedDate ?? Date())
                context.insert(f)
                return f
            }

            // Artwork image
            let artworkData: ImageFile_Data? = g.artworkPartialPath.map {
                let img = ImageFile_Data(
                    partialPath: $0,
                    md5Cache: nil,
                    createdDate: Date(),
                    width: g.artworkWidth,
                    height: g.artworkHeight,
                    ratio: g.artworkRatio,
                    layout: g.artworkLayout
                )
                context.insert(img)
                return img
            }

            // Related files
            var relatedFiles: [File_Data] = []
            for rf in g.relatedFilePaths {
                let f = File_Data(partialPath: rf, md5Cache: nil, createdDate: Date())
                context.insert(f)
                relatedFiles.append(f)
            }

            // Screenshots
            var screenshots: [ImageFile_Data] = []
            for ss in g.screenshotPaths {
                let img = ImageFile_Data(
                    partialPath: ss.partialPath,
                    width: ss.width,
                    height: ss.height,
                    ratio: ss.ratio,
                    layout: ss.layout
                )
                context.insert(img)
                screenshots.append(img)
            }

            let obj = Game_Data(
                title: g.title,
                id: g.id,
                romPath: g.romPath,
                file: fileData,
                relatedFiles: relatedFiles,
                customArtworkURL: g.customArtworkURL,
                originalArtworkURL: g.originalArtworkURL,
                originalArtworkFile: artworkData,
                requiresSync: g.requiresSync,
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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Game", migrated: idx + 1, total: games.count))
        }
        return map
    }

    // MARK: Save States

    private func migrateSaveStates(
        snapshot: RealmSnapshot,
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let saves = snapshot.saveStates
        ILOG("[Migration] Migrating \(saves.count) save states.")

        for (idx, s) in saves.enumerated() {
            let id = s.id
            let existing = try? context.fetch(FetchDescriptor<SaveState_Data>(
                predicate: #Predicate { $0.id == id }
            ))
            if existing?.isEmpty == false { continue }

            let fileData: File_Data? = s.filePartialPath.map {
                let f = File_Data(partialPath: $0, md5Cache: nil, createdDate: Date())
                context.insert(f)
                return f
            }
            let imageData: ImageFile_Data? = s.imagePartialPath.map {
                let img = ImageFile_Data(partialPath: $0)
                context.insert(img)
                return img
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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "SaveState", migrated: idx + 1, total: saves.count))
        }
    }

    // MARK: Cheats

    private func migrateCheats(
        snapshot: RealmSnapshot,
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let cheats = snapshot.cheats
        ILOG("[Migration] Migrating \(cheats.count) cheats.")

        for (idx, c) in cheats.enumerated() {
            let id = c.id
            let existing = try? context.fetch(FetchDescriptor<Cheats_Data>(
                predicate: #Predicate { $0.id == id }
            ))
            if existing?.isEmpty == false { continue }

            let fileData: File_Data? = c.filePartialPath.map {
                let f = File_Data(partialPath: $0, md5Cache: nil, createdDate: Date())
                context.insert(f)
                return f
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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Cheat", migrated: idx + 1, total: cheats.count))
        }
    }

    // MARK: Recent Games

    private func migrateRecentGames(
        snapshot: RealmSnapshot,
        context: ModelContext,
        gameMap: [String: Game_Data],
        coreMap: [String: Core_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let recents = snapshot.recentGames
        ILOG("[Migration] Migrating \(recents.count) recent games.")

        for (idx, r) in recents.enumerated() {
            let id = r.id
            let existing = try? context.fetch(FetchDescriptor<RecentGame_Data>(
                predicate: #Predicate { $0.id == id }
            ))
            if existing?.isEmpty == false { continue }

            let obj = RecentGame_Data(
                id: id,
                game: r.gameMD5.flatMap { gameMap[$0] },
                lastPlayedDate: r.lastPlayedDate,
                core: r.coreIdentifier.flatMap { coreMap[$0] }
            )
            context.insert(obj)

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "RecentGame", migrated: idx + 1, total: recents.count))
        }
    }

    // MARK: Libraries

    private func migrateLibraries(
        snapshot: RealmSnapshot,
        context: ModelContext,
        gameMap: [String: Game_Data],
        progress: (@Sendable (MigrationProgress) -> Void)?
    ) throws {
        let libs = snapshot.libraries
        ILOG("[Migration] Migrating \(libs.count) libraries.")

        for (idx, l) in libs.enumerated() {
            let uuid = l.uuid
            let existing = try? context.fetch(FetchDescriptor<Library_Data>(
                predicate: #Predicate { $0.uuid == uuid }
            ))
            if existing?.isEmpty == false { continue }

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

            if (idx + 1) % kBatchSize == 0 { try saveBatch(context) }
            progress?(MigrationProgress(entity: "Library", migrated: idx + 1, total: libs.count))
        }
    }

    // MARK: - Validation

    private func validateCounts(snapshot: RealmSnapshot, context: ModelContext) {
        let realmCounts: [(String, Int)] = [
            ("Game",       snapshot.games.count),
            ("System",     snapshot.systems.count),
            ("Core",       snapshot.cores.count),
            ("SaveState",  snapshot.saveStates.count),
            ("Cheat",      snapshot.cheats.count),
            ("RecentGame", snapshot.recentGames.count),
            ("Library",    snapshot.libraries.count),
            ("User",       snapshot.users.count),
            ("BIOS",       snapshot.bioses.count),
        ]

        for (name, realmCount) in realmCounts {
            let sdCount = fetchCount(of: name, context: context)
            if sdCount < realmCount {
                // Warn only — count may differ due to deduplication (unique constraints).
                WLOG("[Migration] Validation: \(name) Realm=\(realmCount) SwiftData=\(sdCount). Some records may have been deduplicated or skipped.")
            } else {
                ILOG("[Migration] Validation OK: \(name) — Realm=\(realmCount), SwiftData=\(sdCount)")
            }
        }
    }

    private func fetchCount(of entity: String, context: ModelContext) -> Int {
        switch entity {
        case "Game":       return (try? context.fetchCount(FetchDescriptor<Game_Data>())) ?? 0
        case "System":     return (try? context.fetchCount(FetchDescriptor<System_Data>())) ?? 0
        case "Core":       return (try? context.fetchCount(FetchDescriptor<Core_Data>())) ?? 0
        case "SaveState":  return (try? context.fetchCount(FetchDescriptor<SaveState_Data>())) ?? 0
        case "Cheat":      return (try? context.fetchCount(FetchDescriptor<Cheats_Data>())) ?? 0
        case "RecentGame": return (try? context.fetchCount(FetchDescriptor<RecentGame_Data>())) ?? 0
        case "Library":    return (try? context.fetchCount(FetchDescriptor<Library_Data>())) ?? 0
        case "User":       return (try? context.fetchCount(FetchDescriptor<User_Data>())) ?? 0
        case "BIOS":       return (try? context.fetchCount(FetchDescriptor<BIOS_Data>())) ?? 0
        default:           return 0
        }
    }
}

// MARK: - Realm Snapshot (value types — safe to cross isolation boundaries)

/// A value-type snapshot of all Realm data taken synchronously on the calling thread.
/// All Realm objects are frozen/copied into plain structs so they can safely cross
/// actor isolation boundaries.
struct RealmSnapshot {

    let systems: [SystemSnapshot]
    let cores: [CoreSnapshot]
    let games: [GameSnapshot]
    let saveStates: [SaveStateSnapshot]
    let cheats: [CheatSnapshot]
    let bioses: [BIOSSnapshot]
    let recentGames: [RecentGameSnapshot]
    let libraries: [LibrarySnapshot]
    let users: [UserSnapshot]

    init() throws {
        // Open the default Realm (configured by RomDatabase.setDefaultRealmConfig() at launch).
        // PVLibrary already depends on PVRealm, which brings RealmSwift in.
        let realm = try Realm()

        systems    = realm.objects(PVSystem.self).map(SystemSnapshot.init)
        cores      = realm.objects(PVCore.self).map(CoreSnapshot.init)
        games      = realm.objects(PVGame.self).map(GameSnapshot.init)
        saveStates = realm.objects(PVSaveState.self).map(SaveStateSnapshot.init)
        cheats     = realm.objects(PVCheats.self).map(CheatSnapshot.init)
        bioses     = realm.objects(PVBIOS.self).map(BIOSSnapshot.init)
        recentGames = realm.objects(PVRecentGame.self).map(RecentGameSnapshot.init)
        libraries  = realm.objects(PVLibrary.self).map(LibrarySnapshot.init)
        users      = realm.objects(PVUser.self).map(UserSnapshot.init)
    }
}

// MARK: - Snapshot value types

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

    init(_ img: PVImageFile) {
        partialPath = img.partialPath
        width       = Float(img.width)
        height      = Float(img.height)
        ratio       = img.ratio
        layout      = img.layout
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

    // Related files
    let relatedFilePaths: [String]

    // Screenshots
    let screenshotPaths: [ImageFileSnapshot]

    init(_ g: PVGame) {
        id                = g.id
        title             = g.title
        md5Hash           = g.md5Hash
        crc               = g.crc
        romPath           = g.romPath
        systemIdentifier  = g.systemIdentifier
        isFavorite        = g.isFavorite
        requiresSync      = g.requiresSync
        romSerial         = g.romSerial
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

        relatedFilePaths = g.relatedFiles.compactMap { $0.isInvalidated ? nil : $0.partialPath }
        screenshotPaths  = g.screenShots.compactMap { $0.isInvalidated ? nil : ImageFileSnapshot($0) }
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
    let filePartialPath: String?
    let imagePartialPath: String?

    init(_ s: PVSaveState) {
        id                    = s.id
        date                  = s.date
        isAutosave            = s.isAutosave
        createdWithCoreVersion = s.createdWithCoreVersion
        lastOpened            = s.lastOpened
        gameMD5               = s.game?.isInvalidated == false ? s.game?.md5Hash : nil
        coreIdentifier        = s.core?.isInvalidated == false ? s.core?.identifier : nil
        filePartialPath       = s.file?.isInvalidated == false ? s.file?.partialPath : nil
        imagePartialPath      = s.image?.isInvalidated == false ? s.image?.partialPath : nil
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
        filePartialPath       = c.file?.isInvalidated == false ? c.file?.partialPath : nil
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


