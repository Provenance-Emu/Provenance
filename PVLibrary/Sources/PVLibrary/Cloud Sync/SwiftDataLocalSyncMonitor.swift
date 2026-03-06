//
//  SwiftDataLocalSyncMonitor.swift
//  PVLibrary
//
//  Created by Agent on 2025-03-05.
//
//  Observes local SwiftData model changes and triggers file-based CloudKit
//  uploads for binary assets (ROMs, save states, BIOS files).
//
//  Design notes
//  ============
//  When the ModelContainer is configured with CloudKit (see
//  `PVSwiftDataSchema.makePVModelContainerWithCloudKit()`), SwiftData
//  automatically propagates @Model property changes to iCloud.  This covers
//  game metadata (title, isFavorite, rating, etc.) with no extra code.
//
//  What this monitor handles is the *file* side:  when a new ROM or save state
//  lands on disk, the corresponding binary file needs to be uploaded to CloudKit
//  as a `CKAsset`.  `LocalGameSyncMonitor` (Realm-based) did this via a Realm
//  change-notification token; this class provides the SwiftData equivalent.
//
//  `SwiftDataLocalSyncMonitor` listens to `ModelContext.didSave` / the
//  `NSManagedObjectContextObjectsDidChange` notification posted by
//  NSPersistentCloudKitContainer and re-routes relevant insertions and
//  modifications to the supplied file-based syncers.

#if canImport(SwiftData)
import SwiftData
import CoreData
import Foundation
import CloudKit
import Combine
import PVLogging

/// Monitors SwiftData context save events and triggers CloudKit file uploads.
///
/// Create one instance at app-start and call `startMonitoring()`.
/// The monitor holds a weak reference to the `CloudKitRomsSyncer` so it
/// doesn't prevent it from being released.
///
/// Thread safety: all mutable state (`cancellables`, `pendingSyncWork`) is
/// exclusively accessed on `queue`. `startMonitoring()` and `stopMonitoring()`
/// dispatch synchronously onto `queue`, so `@unchecked Sendable` is safe here.
public final class SwiftDataLocalSyncMonitor: @unchecked Sendable {

    // MARK: - Constants

    /// Typed `Notification.Name` for the CoreData "did save object IDs" notification posted
    /// by `NSPersistentCloudKitContainer`. Using the SDK constant prevents typo-related bugs
    /// and will pick up any future SDK renames automatically.
    private static let contextDidSaveObjectIDsNotification = NSManagedObjectContext.didSaveObjectIDsNotification

    // MARK: - Properties

    private weak var romsSyncer: CloudKitRomsSyncer?

    /// All Combine subscriptions. Always accessed on `queue`.
    private var cancellables = Set<AnyCancellable>()

    /// Serial queue that serialises all state mutations (cancellables, pendingSyncWork)
    /// and notification callbacks, preventing data races.
    private let queue = DispatchQueue(label: "com.provenance-emu.SwiftDataLocalSyncMonitor", qos: .utility)

    /// Pending debounced sync work item. Cancelled and replaced on each new save notification
    /// to coalesce rapid consecutive saves into a single `fetchAndApplyRemoteChanges()` call.
    /// Always accessed on `queue`.
    private var pendingSyncWork: DispatchWorkItem?

    // MARK: - Init

    /// - Parameter romsSyncer: The CloudKit file syncer to notify when games change.
    public init(romsSyncer: CloudKitRomsSyncer) {
        self.romsSyncer = romsSyncer
    }

    deinit {
        // Must dispatch synchronously to drain any in-flight work before dealloc.
        queue.sync { cancellables.removeAll() }
    }

    // MARK: - Lifecycle

    /// Starts listening for SwiftData context save notifications.
    ///
    /// SwiftData posts `NSManagedObjectContextDidSaveObjectIDsNotification` (and
    /// the legacy `NSManagedObjectContextObjectsDidChange`) from the underlying
    /// `NSPersistentCloudKitContainer`.  We observe the former because it carries
    /// permanent object IDs that survive context resets.
    ///
    /// Safe to call from any thread; subscription is stored synchronously on `queue`.
    public func startMonitoring() {
        queue.sync {
            // NSManagedObjectContextDidSaveObjectIDsNotification carries three keys:
            //   NSInsertedObjectIDsKey, NSUpdatedObjectIDsKey, NSDeletedObjectIDsKey
            // Each value is a Set<NSManagedObjectID>.
            NotificationCenter.default
                .publisher(for: SwiftDataLocalSyncMonitor.contextDidSaveObjectIDsNotification)
                .receive(on: queue)   // serial queue — safe to mutate pendingSyncWork here
                .sink { [weak self] notification in
                    self?.handleContextSave(notification)
                }
                .store(in: &cancellables)
        }
        ILOG("SwiftDataLocalSyncMonitor: started.")
    }

    /// Stops observing save notifications.
    ///
    /// Safe to call from any thread; cancellation is applied synchronously on `queue`.
    public func stopMonitoring() {
        queue.sync { cancellables.removeAll() }
        ILOG("SwiftDataLocalSyncMonitor: stopped.")
    }

    // MARK: - Notification handling

    private func handleContextSave(_ notification: Notification) {
        // Skip changes applied by the CloudKit import pipeline to avoid loops.
        if CloudKitRemoteApplyGuard.isApplyingRemoteChanges {
            VLOG("SwiftDataLocalSyncMonitor: skipping notification during remote-apply guard.")
            return
        }

        // The notification's userInfo contains NSManagedObjectID sets keyed by:
        // NSInsertedObjectIDsKey / NSUpdatedObjectIDsKey / NSDeletedObjectIDsKey.
        // We only act on insertions and updates for Game_Data (which trigger
        // ROM file uploads) — metadata field changes are handled automatically
        // by SwiftData's native CloudKit sync.

        // NOTE: Resolving NSManagedObjectIDs back to SwiftData @Model instances
        // requires access to the app's ModelContext. Rather than coupling this
        // monitor to a specific context, we emit a generic "file check" request
        // so the file syncer can reconcile CloudKit state on its next run.
        // A more granular approach (passing specific game IDs) can be added when
        // the CloudKit file syncers expose per-record update APIs.

        // Debounce: coalesce rapid consecutive saves into a single sync call.
        // This prevents excessive network traffic when many records are saved
        // in quick succession (e.g. during a bulk ROM import).
        pendingSyncWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let syncer = self?.romsSyncer else { return }
            VLOG("SwiftDataLocalSyncMonitor: context saved, scheduling ROM sync consistency check.")
            // `fetchAndApplyRemoteChanges` reconciles the local CloudKit change
            // token with the server, uploading any new local ROM records that
            // were not yet pushed.
            Task {
                await syncer.fetchAndApplyRemoteChanges()
            }
        }
        pendingSyncWork = work
        queue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
}
#endif
