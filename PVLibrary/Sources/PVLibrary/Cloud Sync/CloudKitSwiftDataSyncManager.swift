//
//  CloudKitSwiftDataSyncManager.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Coordinates CloudKit sync for SwiftData-backed models.
//
//  Architecture
//  ============
//  Provenance's CloudKit sync is split into two orthogonal layers:
//
//  1. **Metadata sync** (this file / SwiftData native CloudKit)
//     Game titles, favourites, ratings, save-state timestamps, and all other
//     structured @Model fields are synced automatically by SwiftData via
//     `NSPersistentCloudKitContainer` when the ModelContainer is configured
//     with `.cloudKitDatabase(.private(...))`.  No custom sync code is needed
//     for this layer.
//
//  2. **File sync** (existing per-directory CloudKit syncers)
//     Actual binary ROM files, save-state files, BIOS files, and artwork are
//     too large for the CloudKit private database record limit (1 MB).  These
//     continue to be managed by:
//       - `CloudKitRomsSyncer`       → ROM files
//       - `CloudKitSaveStatesSyncer` → Save-state files + screenshots
//       - `BIOSSyncing` implementors → BIOS files
//     Those syncers upload/download files as `CKAsset` records and update the
//     corresponding metadata records in CloudKit's custom record types (ROM,
//     SaveState, BIOS).  The SwiftData models are kept in sync via
//     `SwiftDataLocalSyncMonitor`.
//
//  Merge Conflicts
//  ===============
//  SwiftData's native CloudKit sync uses field-level last-write-wins semantics.
//  For user-editable fields (favourites, ratings, custom artwork URL) this is
//  generally correct.  Play stats (playCount, timeSpentInGame) could accumulate
//  incorrectly if the same game is played on two devices offline simultaneously;
//  however this is an acceptable trade-off for the current implementation.
//  A future improvement would be to use a monotonically increasing server-side
//  field for play stats and merge by taking the maximum.
//
//  Backward Compatibility
//  ======================
//  Existing user data already in the CloudKit private database (stored under
//  the legacy Realm-era record types ROM / SaveState / BIOS) is not touched
//  by SwiftData's sync layer, which uses its own private record types under
//  `com.apple.coredata.cloudkit.*`.  Both stores can co-exist; the file-based
//  syncers continue to read/write the legacy record types.

#if canImport(SwiftData)
import SwiftData
import CloudKit
import Foundation
import PVLogging

/// Coordinates the two-layer CloudKit sync strategy for SwiftData models.
///
/// At app launch call `start(container:)` to configure `ModelContextActor` and
/// (if the user has iCloud enabled) enable native SwiftData CloudKit sync.
/// The existing file-based syncers (ROMs, save states, BIOS) should be started
/// separately via `CloudSyncManager`.
public final class CloudKitSwiftDataSyncManager: @unchecked Sendable {

    // MARK: - Shared

    public static let shared = CloudKitSwiftDataSyncManager()

    // MARK: - Properties

    private let lock = NSLock()
    private var _isStarted = false

    /// Whether `start(container:)` has already been called.
    ///
    /// Thread-safe: guarded by an internal `NSLock`.
    public var isStarted: Bool {
        lock.withLock { _isStarted }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    /// Configures `ModelContextActor` with the given container and starts native
    /// SwiftData CloudKit sync (if `cloudKitEnabled` is true).
    ///
    /// This should be called once, early in the application lifecycle (e.g.
    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or the
    /// SwiftUI `@main` App initialiser).
    ///
    /// - Parameters:
    ///   - container: The `ModelContainer` to use.  For production pass the
    ///     result of `PVSwiftDataSchema.makePVModelContainerWithCloudKit()`.
    ///     For testing pass the result of `PVSwiftDataSchema.makePVModelContainer(inMemory:true)`.
    public func start(container: ModelContainer) async {
        let alreadyStarted = lock.withLock {
            if _isStarted { return true }
            _isStarted = true
            return false
        }
        guard !alreadyStarted else {
            WLOG("CloudKitSwiftDataSyncManager.start called more than once — ignoring.")
            return
        }
        await ModelContextActor.shared.configure(container: container)
        ILOG("CloudKitSwiftDataSyncManager started. Native SwiftData CloudKit sync active if container is CloudKit-backed.")
    }

    // MARK: - CloudKit Account Status

    /// Returns `true` when the current iCloud account is available.
    ///
    /// Native SwiftData CloudKit sync is gated on account availability; calling
    /// this before `start(container:)` is not required but can be used in the
    /// UI to show the sync status.
    public static func checkiCloudAccountAvailability() async -> Bool {
        await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error {
                    ELOG("CloudKit account status error: \(error.localizedDescription)")
                }
                continuation.resume(returning: status == .available)
            }
        }
    }
}

// MARK: - SwiftData CloudKit record ID helpers

/// Maps SwiftData model persistent identifiers to stable CloudKit record IDs.
///
/// SwiftData's native CloudKit sync manages its own record IDs internally.
/// These helpers produce *deterministic* record ID strings that the legacy
/// file-based syncers can use when creating `CKRecord`s for binary assets,
/// ensuring that the metadata record and the file asset record reference the
/// same logical entity.
public enum SwiftDataCloudKitRecordID {

    /// Returns a stable CloudKit record name for a `Game_Data` model.
    ///
    /// The record name is derived from the MD5 hash (which is unique per ROM)
    /// so the same game maps to the same CloudKit record across installs.
    public static func recordName(for game: Game_Data) -> String {
        "ROM.\(game.md5Hash.uppercased())"
    }

    /// Returns a stable CloudKit record name for a `SaveState_Data` model.
    public static func recordName(for saveState: SaveState_Data) -> String {
        "SaveState.\(saveState.id)"
    }

    /// Returns a stable CloudKit record name for a `BIOS_Data` model.
    public static func recordName(for bios: BIOS_Data) -> String {
        "BIOS.\(bios.expectedMD5.uppercased())"
    }
}
#endif
