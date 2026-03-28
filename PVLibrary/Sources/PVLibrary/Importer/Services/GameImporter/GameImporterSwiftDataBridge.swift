//
//  GameImporterSwiftDataBridge.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Dual-write bridge: after every successful Realm write in the game importer
//  this bridge mirrors the same data into the SwiftData store.
//
//  Thread-safety: All methods create their own `ModelContext` from the shared
//  `ModelContainer`, so they are safe to call from background tasks.
//  DO NOT share a ModelContext across threads.
//

import SwiftData
import Foundation
import PVLogging
import PVRealm

// MARK: - GameImporterSwiftDataBridge

/// Mirrors game-importer writes into the SwiftData store alongside Realm.
///
/// This is a *transitional* helper for the Realm → SwiftData migration (epic #2510,
/// task #2554).  Once the whole app is on SwiftData, Realm writes can be removed
/// and this bridge can be simplified or removed.
public final class GameImporterSwiftDataBridge {

    // MARK: Properties

    private let driver: SwiftDataDatabaseDriver

    // MARK: Singleton / Shared

    /// Shared bridge backed by the application's SwiftData `ModelContainer`.
    /// Returns `nil` if the `ModelContainer` cannot be obtained; all write calls
    /// are no-ops in that case instead of crashing the process.
    public static let shared: GameImporterSwiftDataBridge? = {
        do {
            let container = try PVSwiftDataSchema.sharedContainer
            let driver = SwiftDataDatabaseDriver(container: container)
            return GameImporterSwiftDataBridge(driver: driver)
        } catch {
            ELOG("GameImporterSwiftDataBridge: failed to obtain shared container — SwiftData writes disabled: \(error)")
            return nil
        }
    }()

    // MARK: Init

    public init(driver: SwiftDataDatabaseDriver) {
        self.driver = driver
    }

    // MARK: - Public API

    /// Saves (inserts or updates) a `PVGame` Realm object into the SwiftData store.
    ///
    /// - Parameter game: A **frozen** or otherwise thread-safe snapshot of the Realm game.
    ///   Never pass a live Realm object from a different thread.
    public func saveGame(_ game: PVGame) async {
        let title = game.title
        let md5   = game.md5Hash
        let context = driver.newBackgroundContext()
        do {
            try gameData(from: game, context: context)
            try context.save()
            DLOG("SwiftDataBridge: saved game '\(title)' (\(md5))")
        } catch {
            WLOG("SwiftDataBridge: failed to save game '\(title)': \(error)")
        }
    }

    /// Updates the `romPath` field of an existing `Game_Data` record.
    ///
    /// Call this after `saveRelativePath` updates a Realm object.
    ///
    /// - Parameters:
    ///   - md5: MD5 of the game used as a lookup key.
    ///   - partialPath: New relative ROM path.
    public func updateRelativePath(md5: String, partialPath: String) async {
        let context = driver.newBackgroundContext()
        do {
            let matches = try driver.games(withMD5: md5, in: context)
            guard !matches.isEmpty else {
                DLOG("SwiftDataBridge: no Game_Data found for MD5 \(md5) to update path")
                return
            }
            if matches.count > 1 {
                WLOG("SwiftDataBridge: \(matches.count) Game_Data records found for MD5 \(md5); updating all")
            }
            for record in matches {
                record.romPath = partialPath
                // Keep the primary file's path in sync with the ROM path, mirroring Realm's `saveRelativePath`.
                if let primaryFile = record.file {
                    primaryFile.partialPath = partialPath
                } else {
                    WLOG("SwiftDataBridge: Game_Data for MD5 \(md5) has no primary file; updated romPath only")
                }
            }
            try context.save()
            DLOG("SwiftDataBridge: updated romPath for \(md5) → \(partialPath)")
        } catch {
            WLOG("SwiftDataBridge: failed to update romPath for \(md5): \(error)")
        }
    }

    // MARK: - Private helpers

    /// Converts a `PVGame` into a `Game_Data`, inserting it or merging into an
    /// existing record with the same MD5 hash. Returns the resulting record.
    @discardableResult
    private func gameData(from pvGame: PVGame, context: ModelContext) throws -> Game_Data {
        // Upsert: look for an existing record by MD5
        // Note: games(withMD5:in:) already uppercases the hash internally
        let md5 = pvGame.md5Hash
        if let existing = try driver.games(withMD5: md5, in: context).first {
            applyFields(of: pvGame, to: existing, context: context)
            return existing
        }

        // Create a new record
        let record = makeGameData(from: pvGame, context: context)
        context.insert(record)
        return record
    }

    /// Build a fresh `Game_Data` from a `PVGame`.
    private func makeGameData(from pvGame: PVGame, context: ModelContext) -> Game_Data {
        let fileData: File_Data? = pvGame.file.map { pvFile in
            let f = File_Data(partialPath: pvFile.partialPath)
            context.insert(f)
            return f
        }

        let relatedFiles: [File_Data] = pvGame.relatedFiles.map { pvFile in
            let f = File_Data(partialPath: pvFile.partialPath)
            context.insert(f)
            return f
        }

        let artworkFile: ImageFile_Data? = pvGame.originalArtworkFile.map { pvImg in
            let img = ImageFile_Data(
                partialPath: pvImg.partialPath,
                width: Float(pvImg.width),
                height: Float(pvImg.height),
                ratio: pvImg.ratio,
                layout: pvImg.layout
            )
            context.insert(img)
            return img
        }

        let system: System_Data? = {
            guard !pvGame.systemIdentifier.isEmpty else { return nil }
            do {
                return try driver.system(identifier: pvGame.systemIdentifier, in: context)
            } catch {
                WLOG("SwiftDataBridge: failed to look up system '\(pvGame.systemIdentifier)': \(error)")
                return nil
            }
        }()

        return Game_Data(
            title: pvGame.title,
            id: pvGame.id,
            romPath: pvGame.romPath,
            file: fileData,
            relatedFiles: relatedFiles,
            customArtworkURL: pvGame.customArtworkURL,
            originalArtworkURL: pvGame.originalArtworkURL,
            originalArtworkFile: artworkFile,
            requiresSync: pvGame.requiresSync,
            matchSourceRaw: pvGame.matchSourceRaw,
            userCustomizedFieldsMask: pvGame.userCustomizedFieldsMask,
            lastMetadataLookupDate: pvGame.lastMetadataLookupDate,
            isFavorite: pvGame.isFavorite,
            romSerial: pvGame.romSerial,
            romHeader: pvGame.romHeader, importDate: pvGame.importDate,
            systemIdentifier: pvGame.systemIdentifier,
            system: system,
            md5Hash: pvGame.md5Hash.uppercased(),
            crc: pvGame.crc,
            userPreferredCoreID: pvGame.userPreferredCoreID,
            lastPlayed: pvGame.lastPlayed,
            playCount: pvGame.playCount,
            timeSpentInGame: pvGame.timeSpentInGame,
            rating: pvGame.rating,
            gameDescription: pvGame.gameDescription,
            boxBackArtworkURL: pvGame.boxBackArtworkURL,
            developer: pvGame.developer,
            publisher: pvGame.publisher,
            publishDate: pvGame.publishDate,
            genres: pvGame.genres,
            referenceURL: pvGame.referenceURL,
            releaseID: pvGame.releaseID,
            regionName: pvGame.regionName,
            regionID: pvGame.regionID,
            systemShortName: pvGame.systemShortName,
            language: pvGame.language
        )
    }

    /// Updates mutable metadata fields on an *existing* `Game_Data` record.
    ///
    /// This is a true mirror of Realm: every field is assigned directly from `pvGame`,
    /// including nil/empty values, so SwiftData never retains stale data after Realm clears a field.
    private func applyFields(of pvGame: PVGame, to record: Game_Data, context: ModelContext) {
        // Always overwrite all scalar fields to stay in sync with Realm (true mirror semantics).
        record.title                     = pvGame.title
        record.romPath                   = pvGame.romPath
        record.requiresSync              = pvGame.requiresSync
        record.matchSourceRaw            = pvGame.matchSourceRaw
        record.userCustomizedFieldsMask  = pvGame.userCustomizedFieldsMask
        record.lastMetadataLookupDate    = pvGame.lastMetadataLookupDate
        record.lastPlayed                = pvGame.lastPlayed
        record.playCount       = pvGame.playCount
        record.timeSpentInGame = pvGame.timeSpentInGame
        record.rating          = pvGame.rating
        record.isFavorite      = pvGame.isFavorite
        record.importDate      = pvGame.importDate

        // Mirror optional string fields — propagate nil/empty to clear stale values.
        record.gameDescription   = pvGame.gameDescription
        record.developer         = pvGame.developer
        record.publisher         = pvGame.publisher
        record.publishDate       = pvGame.publishDate
        record.genres            = pvGame.genres
        record.regionName        = pvGame.regionName
        record.regionID          = pvGame.regionID
        record.referenceURL      = pvGame.referenceURL
        record.releaseID         = pvGame.releaseID
        record.systemShortName   = pvGame.systemShortName
        record.boxBackArtworkURL = pvGame.boxBackArtworkURL
        record.romSerial         = pvGame.romSerial
        record.romHeader         = pvGame.romHeader
        record.crc               = pvGame.crc
        record.userPreferredCoreID = pvGame.userPreferredCoreID
        record.language          = pvGame.language

        // Always mirror artwork URLs so post-download write-backs are captured.
        record.originalArtworkURL = pvGame.originalArtworkURL
        record.customArtworkURL   = pvGame.customArtworkURL

        // Mirror artwork file relationship from Realm.
        // Update fields in-place when possible to avoid orphaning the old record.
        if let pvArtworkFile = pvGame.originalArtworkFile {
            if let existing = record.originalArtworkFile {
                existing.partialPath = pvArtworkFile.partialPath
                existing.width       = Float(pvArtworkFile.width)
                existing.height      = Float(pvArtworkFile.height)
                existing.ratio       = pvArtworkFile.ratio
                existing.layout      = pvArtworkFile.layout
            } else {
                let img = ImageFile_Data(
                    partialPath: pvArtworkFile.partialPath,
                    width: Float(pvArtworkFile.width),
                    height: Float(pvArtworkFile.height),
                    ratio: pvArtworkFile.ratio,
                    layout: pvArtworkFile.layout
                )
                context.insert(img)
                record.originalArtworkFile = img
            }
        } else {
            record.originalArtworkFile = nil
        }

        // Mirror system link (always refresh, not just when nil).
        if !pvGame.systemIdentifier.isEmpty {
            do {
                record.system = try driver.system(identifier: pvGame.systemIdentifier, in: context)
            } catch {
                WLOG("SwiftDataBridge: failed to look up system '\(pvGame.systemIdentifier)': \(error)")
            }
        }

        // Mirror primary file reference.
        // Update partialPath in-place when possible to avoid orphaning the old record.
        if let pvFile = pvGame.file {
            if let existing = record.file {
                existing.partialPath = pvFile.partialPath
            } else {
                let f = File_Data(partialPath: pvFile.partialPath)
                context.insert(f)
                record.file = f
            }
        } else {
            record.file = nil
        }

        // Mirror related files: remove stale entries and insert new ones.
        // Explicit deletion prevents orphaned File_Data records in the store.
        let pvRelatedPaths = Set(pvGame.relatedFiles.map { $0.partialPath })
        for oldFile in record.relatedFiles where !pvRelatedPaths.contains(oldFile.partialPath) {
            context.delete(oldFile)
        }
        let existingPaths = Set(record.relatedFiles.map { $0.partialPath })
        for pvFile in pvGame.relatedFiles where !existingPaths.contains(pvFile.partialPath) {
            let f = File_Data(partialPath: pvFile.partialPath)
            context.insert(f)
            record.relatedFiles.append(f)
        }
    }
}
