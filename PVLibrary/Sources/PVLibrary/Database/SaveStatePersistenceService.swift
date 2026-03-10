//
//  SaveStatePersistenceService.swift
//  PVLibrary
//
//  Created by Agent on 2026-03-10.
//
//  Abstracts save-state database writes so emulator UI code (PVUI)
//  is decoupled from Realm internals and can be adapted for the
//  SwiftData backend when that migration lands (#2510).
//

import Foundation
// NOTE: PVRealm is imported here because PVFile and PVImageFile (Realm model
// objects) appear in the protocol's method signature. Once the SwiftData
// migration (#2510) is complete, these parameters can be replaced with
// Foundation types (e.g., URL) and this import removed, fully decoupling
// the abstraction from any specific persistence backend.
import PVRealm

/// Abstracts the persistence of a newly created save state into the app database.
///
/// The concrete implementation today is ``RomDatabase`` (Realm-backed).
/// When the SwiftData migration (#2510) is complete, a
/// `SwiftDataSaveStatePersistenceService` conforming to this protocol can be
/// provided instead, without changing any PVUI call sites.
///
/// PVUI code should depend on this protocol (via
/// ``PVEmualatorControllerProtocol/saveStatePersistenceService``) rather than
/// calling `RomDatabase.sharedInstance` directly.
public protocol SaveStatePersistenceServiceProtocol: AnyObject {

    /// Persist a newly created save state and return its database ID.
    ///
    /// Implementations must:
    /// 1. Create a save-state record linked to the specified game and core.
    /// 2. Serialise its metadata to a sidecar JSON file via `LibrarySerializer`.
    /// 3. Post a `.PVSaveStateSaved` notification for CloudKit sync.
    /// 4. Purge old auto-saves beyond the keep limit when `isAutosave` is `true`.
    ///
    /// - Parameters:
    ///   - gameID:          The ROM's MD5 hash (primary key for the game record).
    ///   - coreIdentifier:  The core's bundle identifier (primary key for the core record).
    ///   - file:            `PVFile` pointing to the `.svs` save-state file on disk.
    ///   - imageFile:       Optional `PVImageFile` for the screenshot thumbnail.
    ///   - isAutosave:      `true` if this is an automatic save (triggers auto-save cleanup).
    /// - Returns: The UUID string of the persisted save-state record.
    /// - Throws: If the underlying database write fails or the game/core record is not found.
    func registerSaveState(
        gameID: String,
        coreIdentifier: String,
        file: PVFile,
        imageFile: PVImageFile?,
        isAutosave: Bool
    ) async throws -> String
}
