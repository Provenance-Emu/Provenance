//
//  CloudKitNotificationManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import UserNotifications
import UIKit
import PVLogging
import Combine

/// Manager for handling CloudKit push notifications and background sync
public class CloudKitNotificationManager {
    /// Shared instance for app-wide access
    public static let shared = CloudKitNotificationManager()

    // Use CloudKit Record Types from CloudKitSchema
    // This ensures consistency across all CloudKit components
    private enum RecordType {
        static let file = CloudKitSchema.RecordType.file.rawValue
        static let rom = CloudKitSchema.RecordType.rom.rawValue
        static let saveState = CloudKitSchema.RecordType.saveState.rawValue
        static let bios = CloudKitSchema.RecordType.bios.rawValue
        // Add other types if needed
    }

    // MARK: - Properties

    /// The CloudKit container — nil when running without CloudKit entitlement (sideloaded builds).
    private let container: CKContainer?

    /// The CloudKit database — nil when container is unavailable.
    private let privateDatabase: CKDatabase?

    /// Publisher for notification events
    private let notificationSubject = PassthroughSubject<CKNotification, Never>()

    /// Publisher for notification events
    public var notificationPublisher: AnyPublisher<CKNotification, Never> {
        notificationSubject.eraseToAnyPublisher()
    }

    /// Flag indicating if notifications are registered
    @Published public var isRegisteredForNotifications = false

    /// Flag indicating if background refresh is enabled
    @Published public var isBackgroundRefreshEnabled = false

    // MARK: - Initialization

    private init() {
        container = iCloudConstants.container
        privateDatabase = container?.privateCloudDatabase
        guard container != nil else {
            CloudSyncManager.syncLog.event(.check, item: "notifications/entitlement", status: .notFound, detail: "CloudKit entitlement not present — notification manager disabled (sideloaded?)")
            return
        }
        checkNotificationStatus()
        checkBackgroundRefreshStatus()
    }

    // MARK: - Public Methods

    /// Register for remote notifications
    public func registerForRemoteNotifications() {
        DLOG("Registering for remote notifications")

        // Request authorization for notifications
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DLOG("Notification authorization granted")

                // Register for remote notifications on the main thread
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                CloudSyncManager.syncLog.event(.error, item: "notifications/authorization", status: .failed, detail: "Failed to request notification authorization: \(error.localizedDescription)")
            } else {
                CloudSyncManager.syncLog.event(.error, item: "notifications/authorization", status: .failed, detail: "Notification authorization denied by user")
            }
        }
    }

    /// Setup CloudKit subscriptions for database changes
    public func setupSubscriptions() async {
        guard container != nil else { return }
        DLOG("Setting up CloudKit subscriptions")

        do {
            // Create subscriptions for each record type
            try await setupSubscription(for: RecordType.rom)
            try await setupSubscription(for: RecordType.saveState)
            try await setupSubscription(for: RecordType.bios)
            // Add subscription for RecordType.file if NonDatabaseSyncer needs notifications
            // try await setupSubscription(for: RecordType.file)

            DLOG("CloudKit subscriptions setup successfully")
        } catch {
            CloudSyncManager.syncLog.event(.error, item: "notifications/subscriptions", status: .failed, detail: "Failed to setup CloudKit subscriptions: \(error.localizedDescription)")
        }
    }

    /// Process a remote notification
    /// - Parameter userInfo: The notification payload
    /// - Returns: Background fetch result
    @discardableResult
    public func processNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard container != nil else { return .noData }
        let syncLog = CloudSyncManager.syncLog
        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            syncLog.event(.check, item: "notifications/push", status: .skipped, detail: "Not a CloudKit notification")
            return .noData
        }

        syncLog.event(.sync, item: "notifications/push", status: .inProgress, detail: "CloudKit push: type=\(notification.notificationType.rawValue), subscription=\(notification.subscriptionID ?? "none")")

        // Publish the notification for subscribers
        notificationSubject.send(notification)

        do {
            // Process different notification types
            switch notification.notificationType {
            case .query:
                // Query notification - sync the specific query
                if let queryNotification = notification as? CKQueryNotification {
                    DLOG("[SYNC] Query notification for record: \(queryNotification.recordID?.recordName ?? "unknown")")
                    return try await processQueryNotification(queryNotification)
                }

            case .recordZone:
                // Record zone notification - sync the specific zone
                if let zoneNotification = notification as? CKRecordZoneNotification {
                    DLOG("[SYNC] Zone notification received")
                    return try await processZoneNotification(zoneNotification)
                }

            case .database:
                // Database notification - sync all data
                DLOG("[SYNC] Database notification received")
                return try await processDatabaseNotification(notification)

            default:
                DLOG("[SYNC] Unhandled notification type: \(notification.notificationType)")
                return .noData
            }
        } catch {
            syncLog.event(.error, item: "notifications/push", status: .failed, detail: "Error processing CloudKit notification: \(error.localizedDescription)")
            return .failed
        }

        return .noData
    }

    /// Handle device token registration
    /// - Parameter deviceToken: The device token data
    public func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DLOG("Registered for remote notifications with token: \(tokenString)")

        // Update registration status
        isRegisteredForNotifications = true

        // Setup subscriptions
        Task {
            await setupSubscriptions()
        }
    }

    /// Handle device token registration failure
    /// - Parameter error: The registration error
    public func didFailToRegisterForRemoteNotifications(withError error: Error) {
        CloudSyncManager.syncLog.event(.error, item: "notifications/registration", status: .failed, detail: "Failed to register for remote notifications: \(error.localizedDescription)")
        isRegisteredForNotifications = false
    }

    // MARK: - Private Methods

    /// Check the current notification registration status
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.isRegisteredForNotifications = settings.authorizationStatus == .authorized
            DLOG("Notification authorization status: \(settings.authorizationStatus.rawValue)")
        }
    }

    /// Check if background refresh is enabled
    private func checkBackgroundRefreshStatus() {
        let status = UIApplication.shared.backgroundRefreshStatus
        isBackgroundRefreshEnabled = status == .available
        DLOG("Background refresh status: \(status.rawValue)")
    }

    /// Setup a subscription for a specific record type
    /// - Parameter recordType: The record type to subscribe to
    private func setupSubscription(for recordType: String) async throws {
        guard let privateDatabase else { return }

        // Create a unique subscription ID
        let subscriptionID = "com.provenance-emu.provenance.subscription.\(recordType)"

        // Create a subscription for all records of this type
        let predicate = NSPredicate(value: true)
        let options: CKQuerySubscription.Options = [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subscriptionID, options: options)

        // Configure notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // For silent notifications
        notificationInfo.shouldBadge = false
        #if !os(tvOS)
        notificationInfo.alertBody = nil // No visible alert
        #endif
        subscription.notificationInfo = notificationInfo

        // Save the subscription
        do {
            _ = try await privateDatabase.save(subscription)
            DLOG("Saved subscription for record type: \(recordType)")
        } catch let error as CKError {
            // If the subscription already exists, that's fine
            if error.code == .serverRecordChanged {
                DLOG("Subscription already exists for record type: \(recordType)")
            } else {
                throw error
            }
        }
    }

    /// Process a query notification
    /// - Parameter notification: The query notification
    /// - Returns: Background fetch result
    private func processQueryNotification(_ notification: CKQueryNotification) async throws -> UIBackgroundFetchResult {
        let syncLog = CloudSyncManager.syncLog
        guard let recordID = notification.recordID else {
            syncLog.event(.query, item: "notifications/query", status: .skipped, detail: "Query notification received without a recordID. SubscriptionID: \(notification.subscriptionID ?? "nil")")
            return .noData
        }

        // Determine record type from subscription ID or potentially recordID format
        // This relies on subscriptionID matching the recordType, which is how setupSubscription works.
        guard let subscriptionID = notification.subscriptionID,
              let recordType = subscriptionID.split(separator: ".").last.map(String.init) else {
            syncLog.event(.query, item: "notifications/query", status: .skipped, detail: "Could not determine record type from subscription ID: \(notification.subscriptionID ?? "nil")")
            // Fallback: Try to guess from recordID prefix? (Less reliable)
            // let recordName = recordID.recordName
            // if recordName.hasPrefix("rom_") { recordType = RecordType.rom } etc.
            return .noData
        }

        DLOG("Processing query notification for type: \(recordType), record ID: \(recordID.recordName)")

        var dataChanged = false

        // Determine which syncer to use based on record type
        switch recordType {
        case RecordType.rom:
            // Sync ROMs metadata
            if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
                 // Call the method to handle a specific remote record change
                 try await syncer.handleRemoteGameChange(recordID: recordID)
                 dataChanged = true
            } else { syncLog.event(.sync, item: "notifications/query/rom", status: .notFound, detail: "CloudKitRomsSyncer not found") }

        case RecordType.saveState:
            // Sync save states metadata
            if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
                try await syncer.handleRemoteSaveStateChange(recordID: recordID)
                dataChanged = true
            } else { syncLog.event(.sync, item: "notifications/query/saveState", status: .notFound, detail: "CloudKitSaveStatesSyncer not found") }

        case RecordType.bios:
            // Sync BIOS files metadata
            if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
                // TODO: Implement handleRemoteBIOSChange in CloudKitBIOSSyncer
                // try await syncer.handleRemoteBIOSChange(recordID: recordID)
                syncLog.event(.sync, item: "notifications/query/bios", status: .pending, detail: "handleRemoteBIOSChange not yet implemented in CloudKitBIOSSyncer for notification processing")
                dataChanged = true // Assume data changed even if method is stubbed for now
            } else { syncLog.event(.sync, item: "notifications/query/bios", status: .notFound, detail: "CloudKitBIOSSyncer not found") }

        // Handle File type if NonDatabaseSyncer needs notification processing
        // case RecordType.file:
        //     if let syncer = CloudKitSyncerStore.shared.nonDatabaseSyncers.first as? CloudKitNonDatabaseSyncer {
        //         try await syncer.handleRemoteFileChange(recordID: recordID)
        //         dataChanged = true
        //     } else { WLOG("CloudKitNonDatabaseSyncer not found.") }

        default:
            syncLog.event(.query, item: "notifications/query/\(recordType)", status: .skipped, detail: "Unhandled record type in query notification")
            return .noData
        }

        return dataChanged ? .newData : .noData
    }

    /// Process a record zone notification
    /// - Parameter notification: The record zone notification
    /// - Returns: Background fetch result
    private func processZoneNotification(_ notification: CKRecordZoneNotification) async throws -> UIBackgroundFetchResult {
        DLOG("Processing record zone notification for zone ID: \(notification.recordZoneID?.zoneName ?? "unknown")")

        // Get the zone ID
        guard let zoneID = notification.recordZoneID else {
            CloudSyncManager.syncLog.event(.sync, item: "notifications/zone", status: .skipped, detail: "Ignoring notification with no zone ID")
            return .noData
        }

        // We might want to verify the zoneID belongs to our private database scope if needed
        // e.g., zoneID.ownerName == CKCurrentUserDefaultName

        // A zone-level notification often implies multiple changes or a need for a broader sync.
        CloudSyncManager.syncLog.event(.sync, item: "notifications/zone", status: .inProgress, detail: "Zone notification received, posting notification for CloudSyncManager")

        // Post a standard notification that CloudSyncManager can observe
        // Make sure .cloudKitZoneChanged is defined elsewhere (e.g., NotificationsAdditions.swift)
        NotificationCenter.default.post(name: .cloudKitZoneChanged, object: zoneID)

        // Returning .newData signals work was done, even if specific changes aren't processed here.
        return .newData
    }

    /// Process a database notification
    /// - Parameter notification: The database notification
    /// - Returns: Background fetch result
    private func processDatabaseNotification(_ notification: CKNotification) async throws -> UIBackgroundFetchResult {
        DLOG("Processing database notification")

        // Sync all data
        return try await syncAllData()
    }

    /// Sync all data from CloudKit
    /// - Returns: Background fetch result
    private func syncAllData() async throws -> UIBackgroundFetchResult {
        DLOG("Syncing all data from CloudKit")
        let syncLog = CloudSyncManager.syncLog

        var didSync = false

        // Sync ROMs
        if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
            // TODO: Implement a method to sync all ROMs triggered by database notification
            // await syncer.syncAll()
            syncLog.event(.sync, item: "notifications/database/rom", status: .pending, detail: "Full ROM sync triggered by database notification not yet implemented")
            didSync = true
        }

        // Sync save states
        if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
            // TODO: Implement a method to sync all save states
            // await syncer.syncAll()
            syncLog.event(.sync, item: "notifications/database/saveState", status: .pending, detail: "Full save state sync triggered by database notification not yet implemented")
            didSync = true
        }

        // Sync BIOS files
        if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
            // TODO: Implement a method to sync all BIOS files
            // await syncer.syncAll()
            syncLog.event(.sync, item: "notifications/database/bios", status: .pending, detail: "Full BIOS sync triggered by database notification not yet implemented")
            didSync = true
        }

        return didSync ? .newData : .noData
    }
}
