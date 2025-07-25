//
//  CloudKitSubscriptionManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging
import Combine
import UIKit
import PVLibrary
import PVPrimitives

/// Manager for CloudKit subscriptions
/// Handles creating and managing subscriptions for real-time updates

public class CloudKitSubscriptionManager {
    // MARK: - Properties

    /// Shared instance
    public static let shared = CloudKitSubscriptionManager()

    /// CloudKit container
    private let container: CKContainer

    /// Private database
    private let privateDatabase: CKDatabase

    /// Subject for subscription updates
    private let subscriptionSubject = PassthroughSubject<CKSubscription, Error>()

    /// Publisher for subscription updates
    public var subscriptionPublisher: AnyPublisher<CKSubscription, Error> {
        subscriptionSubject.eraseToAnyPublisher()
    }

    /// Notification tokens
    private var notificationTokens: [NSObjectProtocol] = []

    // MARK: - Initialization

    /// Private initializer for singleton
    private init() {
        // Get CloudKit container
        container = iCloudConstants.container
        privateDatabase = container.privateCloudDatabase

        // Register for notifications
        registerForNotifications()
    }

    deinit {
        // Unregister from notifications
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Public Methods

    /// Set up subscriptions for CloudKit updates
    public func setupSubscriptions() async {
        do {
            // Initialize CloudKit schema
            DLOG("Initializing CloudKit schema before setting up subscriptions...")
            let success = await CloudKitSchema.initializeSchema(in: privateDatabase)
            if success {
                DLOG("CloudKit schema initialized successfully")
            } else {
                ELOG("Failed to initialize CloudKit schema")
            }

            // Create subscriptions for each record type
            try await createROMSubscription()
            try await createSaveStateSubscription()
            try await createBIOSSubscription()
            try await createFileSubscription()

            DLOG("CloudKit subscriptions set up successfully")
        } catch {
            ELOG("Failed to set up CloudKit subscriptions: \(error.localizedDescription)")
        }
    }

    /// Handle a remote notification
    /// - Parameter userInfo: User info from the notification
    public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        // Get notification from CloudKit
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        guard let notification = notification else {
            ELOG("Invalid CloudKit notification")
            return
        }

        DLOG("Received CloudKit notification: \(notification.notificationType.rawValue)")

        // Handle different notification types
        switch notification.notificationType {
        case .query:
            guard let queryNotification = notification as? CKQueryNotification,
                  let recordID = queryNotification.recordID else {
                return
            }

            // Handle query notification based on record type
            handleQueryNotification(queryNotification, recordID: recordID)

        case .database:
            // Handle database notification
            handleDatabaseNotification(notification)

        default:
            DLOG("Unhandled CloudKit notification type: \(notification.notificationType.rawValue)")
        }
    }

    /// Register for remote notifications
    public func registerForRemoteNotifications() {
        // Request authorization for notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                ELOG("Error requesting notification authorization: \(error.localizedDescription)")
                return
            }

            if granted {
                DLOG("Notification authorization granted")

                // Register for remote notifications on main thread
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                ELOG("Notification authorization denied")
            }
        }
    }

    // MARK: - Private Methods

    /// Create a subscription for file records
    private func createFileSubscription() async throws {
        // Create subscription ID
        let subscriptionID = "file-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            DLOG("File subscription already exists")
            return
        } catch {
            // Subscription doesn't exist, create it
        }

        // Create predicate for all file records
        let predicate = NSPredicate(value: true)

        // Create subscription
        let subscription = CKQuerySubscription(
            recordType: CloudKitSchema.RecordType.file.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        // Create notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        // Save subscription
        _ = try await privateDatabase.save(subscription)
        DLOG("Created file subscription")

        // Notify subscribers
        subscriptionSubject.send(subscription)
    }

    /// Create a subscription for ROM records
    private func createROMSubscription() async throws {
        // Create subscription ID
        let subscriptionID = "rom-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            DLOG("ROM subscription already exists")
            return
        } catch {
            // Subscription doesn't exist, create it
        }

        // Create predicate for all ROM records
        let predicate = NSPredicate(value: true)

        // Create subscription
        let subscription = CKQuerySubscription(
            recordType: CloudKitSchema.RecordType.rom.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        // Create notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        // Save subscription
        _ = try await privateDatabase.save(subscription)
        DLOG("Created game subscription")

        // Notify subscribers
        subscriptionSubject.send(subscription)
    }

    /// Create a subscription for save state records
    private func createSaveStateSubscription() async throws {
        // Create subscription ID
        let subscriptionID = "savestate-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            DLOG("Save state subscription already exists")
            return
        } catch {
            // Subscription doesn't exist, create it
        }

        // Create predicate for all save state records
        let predicate = NSPredicate(value: true)

        // Create subscription
        let subscription = CKQuerySubscription(
            recordType: CloudKitSchema.RecordType.saveState.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        // Create notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        // Save subscription
        _ = try await privateDatabase.save(subscription)
        DLOG("Created save state subscription")

        // Notify subscribers
        subscriptionSubject.send(subscription)
    }

    /// Create a subscription for BIOS records
    private func createBIOSSubscription() async throws {
        // Create subscription ID
        let subscriptionID = "bios-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            DLOG("BIOS subscription already exists")
            return
        } catch {
            // Subscription doesn't exist, create it
        }

        // Create predicate for all BIOS records
        let predicate = NSPredicate(value: true)

        // Create subscription
        let subscription = CKQuerySubscription(
            recordType: CloudKitSchema.RecordType.bios.rawValue,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        // Create notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        // Save subscription
        _ = try await privateDatabase.save(subscription)
        DLOG("Created BIOS subscription")

        // Notify subscribers
        subscriptionSubject.send(subscription)
    }

    /// Handle a query notification
    /// - Parameters:
    ///   - queryNotification: The notification object
    ///   - recordID: The ID of the affected record
    private func handleQueryNotification(_ queryNotification: CKQueryNotification, recordID: CKRecord.ID) {
        DLOG("Handling query notification for Record ID: \(recordID.recordName), Reason: \(queryNotification.queryNotificationReason.rawValue)")

        // Get the subscription ID to determine the record type context
        let subscriptionID = queryNotification.subscriptionID ?? "unknown"
        let reason = queryNotification.queryNotificationReason // Pass the reason along

        Task { // Perform async operations in a Task
            switch subscriptionID {
            case "rom-changes":
                // Handle ROM changes (using romsSyncer)
                // Ensure the syncer is the CloudKit specific one before calling its method
                if let cloudKitSyncer = CloudSyncManager.shared.romsSyncer as? CloudKitRomsSyncer {
                    do {
                        try await cloudKitSyncer.handleRemoteGameChange(recordID: recordID)
                        DLOG("Processed ROM notification via CloudKitRomsSyncer for \(recordID.recordName)")
                    } catch {
                        ELOG("Error processing ROM notification for \(recordID.recordName): \(error)")
                    }
                } else {
                    WLOG("Roms Syncer is not CloudKitRomsSyncer or is nil. Cannot handle CloudKit notification for \(recordID.recordName).")
                }

            case "save-state-changes":
                // Handle Save State changes
                // Ensure the syncer is the CloudKit specific one (or its base class) before calling its method
                if let cloudKitSyncer = CloudSyncManager.shared.saveStatesSyncer as? CloudKitSyncer {
                    do {
                        // Fetch the record using the ID provided by the notification
                        let record = try await cloudKitSyncer.privateDatabase.record(for: recordID)
                        DLOG("Fetched SaveState record for notification: \(record.recordID.recordName)")
                        // Process the fetched record
                        await cloudKitSyncer.processCloudKitRecord(record)
                        DLOG("Processed SaveState notification via CloudKitSyncer for \(recordID.recordName)")
                    } catch {
                        ELOG("Error fetching or processing SaveState notification for \(recordID.recordName): \(error)")
                        // Optionally, inform the syncer's error handler
                        // await cloudKitSyncer.errorHandler.handle(error: error)
                    }
                } else {
                    WLOG("SaveStates Syncer is not CloudKitSyncer or is nil. Cannot handle CloudKit notification for \(recordID.recordName).")
                }

            case "file-changes", "bios-changes":
                // Handle File/BIOS changes (using nonDatabaseSyncer)
                if let nonDatabaseSyncer = CloudSyncManager.shared.nonDatabaseSyncer {
                    // Call the method we added earlier in CloudKitNonDatabaseSyncer.swift
                    // This method currently handles deletion implicitly by catching CKError.unknownItem
                    await nonDatabaseSyncer.processRemoteRecordUpdate(recordID: recordID)
                    DLOG("Processed File/BIOS notification via nonDatabaseSyncer for \(recordID.recordName)")
                } else {
                    WLOG("NonDatabase Syncer not available to handle notification for \(recordID.recordName)")
                }

            default:
                WLOG("Unhandled subscription ID: \(subscriptionID) for record \(recordID.recordName)")
                // Optional: Add logic to fetch the record to determine its type if needed.
            }
        }
    }

    /// Handle a database notification
    /// - Parameter notification: The database notification
    private func handleDatabaseNotification(_ notification: CKNotification) {
        // Post notification for database changes
        NotificationCenter.default.post(name: .CloudKitDatabaseChanged, object: nil)

        // Trigger fetch of remote changes (more focused than full sync)
        Task {
            await CloudSyncManager.shared.fetchRemoteChangesOnly()
        }
    }

    /// Handle a file notification
    /// - Parameters:
    ///   - notification: The query notification
    ///   - recordID: The record ID
    private func handleFileNotification(_ notification: CKQueryNotification, recordID: CKRecord.ID) {
        // Handle based on notification type
        switch notification.queryNotificationReason {
        case .recordCreated:
            // File created
            DLOG("File created: \(recordID.recordName)")

            // Fetch the file record
            Task {
                do {
                    let record = try await privateDatabase.record(for: recordID)

                    // Get file details
                    if let directory = record["directory"] as? String,
                       let filename = record["filename"] as? String {
                        // Post notification
                        NotificationCenter.default.post(
                            name: .CloudKitFileCreated,
                            object: nil,
                            userInfo: [
                                "directory": directory,
                                "filename": filename,
                                "recordID": recordID
                            ]
                        )

                        // Trigger sync for this file
                        if directory == "ROMs" {
                            // Handle ROM file
                            if let gameID = record["gameID"] as? String {
                                // Find game and download
                                if let game = PVGame.with(primaryKey: gameID) {
                                    _ = try await CloudSyncManager.shared.downloadROM(for: game)
                                }
                            }
                        } else if directory == "Saves" {
                            // Handle save state file
                            if let saveStateID = record["saveStateID"] as? String {
                                // Find save state and download
                                if let saveState = PVSaveState.with(primaryKey: saveStateID) {
                                    _ = try await CloudSyncManager.shared.downloadSaveState(for: saveState)
                                }
                            }
                        } else {
                            // Handle any file
                            if let biosSyncer = CloudSyncManager.shared.nonDatabaseSyncer  {
                                _ = try await biosSyncer.downloadFileOnDemand(recordName: filename)
                            }
                        }
                    }
                } catch {
                    ELOG("Error fetching file record: \(error.localizedDescription)")
                }
            }

        case .recordUpdated:
            // File updated
            DLOG("File updated: \(recordID.recordName)")

            // Similar to created, but post different notification
            Task {
                do {
                    let record = try await privateDatabase.record(for: recordID)

                    // Get file details
                    if let directory = record["directory"] as? String,
                       let filename = record["filename"] as? String {
                        // Post notification
                        NotificationCenter.default.post(
                            name: .CloudKitFileUpdated,
                            object: nil,
                            userInfo: [
                                "directory": directory,
                                "filename": filename,
                                "recordID": recordID
                            ]
                        )

                        // Trigger sync for this file (same as created)
                        if directory == "ROMs" {
                            // Handle ROM file
                            if let gameID = record["gameID"] as? String {
                                // Find game and download
                                if let game = PVGame.with(primaryKey: gameID) {
                                    _ = try await CloudSyncManager.shared.downloadROM(for: game)
                                }
                            }
                        } else if directory == "Saves" {
                            // Handle save state file
                            if let saveStateID = record["saveStateID"] as? String {
                                // Find save state and download
                                if let saveState = PVSaveState.with(primaryKey: saveStateID) {
                                    _ = try await CloudSyncManager.shared.downloadSaveState(for: saveState)
                                }
                            }
                        } else {
                            // Handle BIOS file
                            if let biosSyncer = CloudSyncManager.shared.nonDatabaseSyncer {
                                _ = try await biosSyncer.downloadFileOnDemand(recordName: filename)
                            }
                        }
                    }
                } catch {
                    ELOG("Error fetching file record: \(error.localizedDescription)")
                }
            }

        case .recordDeleted:
            // File deleted
            DLOG("File deleted: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitFileDeleted,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        @unknown default:
            DLOG("Unknown query notification reason: \(notification.queryNotificationReason.rawValue)")
        }
    }

    /// Handle a game notification
    /// - Parameters:
    ///   - notification: The query notification
    ///   - recordID: The record ID
    private func handleGameNotification(_ notification: CKQueryNotification, recordID: CKRecord.ID) {
        // Handle based on notification type
        switch notification.queryNotificationReason {
        case .recordCreated:
            // Game created
            DLOG("Game created: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitGameCreated,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        case .recordUpdated:
            // Game updated
            DLOG("Game updated: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitGameUpdated,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        case .recordDeleted:
            // Game deleted
            DLOG("Game deleted: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitGameDeleted,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        @unknown default:
            DLOG("Unknown query notification reason: \(notification.queryNotificationReason.rawValue)")
        }
    }

    /// Handle a save state notification
    /// - Parameters:
    ///   - notification: The query notification
    ///   - recordID: The record ID
    private func handleSaveStateNotification(_ notification: CKQueryNotification, recordID: CKRecord.ID) {
        // Handle based on notification type
        switch notification.queryNotificationReason {
        case .recordCreated:
            // Save state created
            DLOG("Save state created: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitSaveStateCreated,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        case .recordUpdated:
            // Save state updated
            DLOG("Save state updated: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitSaveStateUpdated,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        case .recordDeleted:
            // Save state deleted
            DLOG("Save state deleted: \(recordID.recordName)")

            // Post notification
            NotificationCenter.default.post(
                name: .CloudKitSaveStateDeleted,
                object: nil,
                userInfo: [
                    "recordID": recordID
                ]
            )

        @unknown default:
            DLOG("Unknown query notification reason: \(notification.queryNotificationReason.rawValue)")
        }
    }

    /// Register for notifications
    private func registerForNotifications() {
        // Register for app becoming active notification
        let activeToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Set up subscriptions when app becomes active
            Task {
                await self?.setupSubscriptions()
            }
        }

        // Register for iCloud sync enabled notification
        let enabledToken = NotificationCenter.default.addObserver(
            forName: .iCloudSyncEnabled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Set up subscriptions when iCloud sync is enabled
            Task {
                await self?.setupSubscriptions()
            }

            // Register for remote notifications
            self?.registerForRemoteNotifications()
        }

        // Store tokens for cleanup
        notificationTokens = [
            activeToken,
            enabledToken
        ]
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Notification sent when CloudKit database changes
    public static let CloudKitDatabaseChanged = Notification.Name("CloudKitDatabaseChanged")

    /// Notification sent when a file is created in CloudKit
    public static let CloudKitFileCreated = Notification.Name("CloudKitFileCreated")

    /// Notification sent when a file is updated in CloudKit
    public static let CloudKitFileUpdated = Notification.Name("CloudKitFileUpdated")

    /// Notification sent when a file is deleted in CloudKit
    public static let CloudKitFileDeleted = Notification.Name("CloudKitFileDeleted")

    /// Notification sent when a game is created in CloudKit
    public static let CloudKitGameCreated = Notification.Name("CloudKitGameCreated")

    /// Notification sent when a game is updated in CloudKit
    public static let CloudKitGameUpdated = Notification.Name("CloudKitGameUpdated")

    /// Notification sent when a game is deleted in CloudKit
    public static let CloudKitGameDeleted = Notification.Name("CloudKitGameDeleted")

    /// Notification sent when a save state is created in CloudKit
    public static let CloudKitSaveStateCreated = Notification.Name("CloudKitSaveStateCreated")

    /// Notification sent when a save state is updated in CloudKit
    public static let CloudKitSaveStateUpdated = Notification.Name("CloudKitSaveStateUpdated")

    /// Notification sent when a save state is deleted in CloudKit
    public static let CloudKitSaveStateDeleted = Notification.Name("CloudKitSaveStateDeleted")

    /// Notification sent when a file is downloaded from CloudKit
    public static let PVCloudSyncDidDownloadFile = Notification.Name("PVCloudSyncDidDownloadFile")
}
