//
//  CloudKitNotificationManager.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
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
    
    // MARK: - Properties
    
    /// The CloudKit container
    private let container = CKContainer.default()
    
    /// The CloudKit database
    private let privateDatabase: CKDatabase
    
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
        privateDatabase = container.privateCloudDatabase
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
                ELOG("Failed to request notification authorization: \(error.localizedDescription)")
            } else {
                ELOG("Notification authorization denied by user")
            }
        }
    }
    
    /// Setup CloudKit subscriptions for database changes
    public func setupSubscriptions() async {
        DLOG("Setting up CloudKit subscriptions")
        
        do {
            // Create subscriptions for each record type
            try await setupSubscription(for: CloudKitSchema.RecordType.rom)
            try await setupSubscription(for: CloudKitSchema.RecordType.saveState)
            try await setupSubscription(for: CloudKitSchema.RecordType.bios)
            
            DLOG("CloudKit subscriptions setup successfully")
        } catch {
            ELOG("Failed to setup CloudKit subscriptions: \(error.localizedDescription)")
        }
    }
    
    /// Process a remote notification
    /// - Parameter userInfo: The notification payload
    /// - Returns: Background fetch result
    @discardableResult
    public func processNotification(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        DLOG("Processing CloudKit notification")
        
        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            ELOG("Not a CloudKit notification")
            return .noData
        }
        
        // Publish the notification for subscribers
        notificationSubject.send(notification)
        
        do {
            // Process different notification types
            switch notification.notificationType {
            case .query:
                // Query notification - sync the specific query
                if let queryNotification = notification as? CKQueryNotification {
                    return try await processQueryNotification(queryNotification)
                }
                
            case .recordZone:
                // Record zone notification - sync the specific zone
                if let zoneNotification = notification as? CKRecordZoneNotification {
                    return try await processZoneNotification(zoneNotification)
                }
                
            case .database:
                // Database notification - sync all data
                return try await processDatabaseNotification(notification)
                
            default:
                DLOG("Unhandled notification type: \(notification.notificationType)")
                return .noData
            }
        } catch {
            ELOG("Error processing CloudKit notification: \(error.localizedDescription)")
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
        ELOG("Failed to register for remote notifications: \(error.localizedDescription)")
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
        let recordID = notification.recordID
        
        // Get record type from the query notification's subscription ID
        // The subscription ID is typically set to the record type when creating subscriptions
        let subscriptionID = notification.subscriptionID
        let recordType = subscriptionID ?? "unknown"
        
        DLOG("Processing query notification for subscription: \(recordType), record ID: \(recordID?.recordName ?? "unknown")")
        
        // Determine which syncer to use based on record type
        switch recordType {
        case CloudKitSchema.RecordType.rom:
            // Sync ROMs
            if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
                await syncer.syncMetadataOnly()
                return .newData
            }
            
        case CloudKitSchema.RecordType.saveState:
            // Sync save states
            if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
                await syncer.syncMetadataOnly()
                return .newData
            }
            
        case CloudKitSchema.RecordType.bios:
            // Sync BIOS files
            if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
                await syncer.syncMetadataOnly()
                return .newData
            }
            
        default:
            DLOG("Unknown record type in notification: \(recordType)")
            return .noData
        }
        
        return .noData
    }
    
    /// Process a record zone notification
    /// - Parameter notification: The zone notification
    /// - Returns: Background fetch result
    private func processZoneNotification(_ notification: CKRecordZoneNotification) async throws -> UIBackgroundFetchResult {
        let zoneID = notification.recordZoneID
        DLOG("Processing zone notification for zone: \(zoneID?.zoneName ?? "null")")
        
        // Sync all data in this zone
        // For now, we'll just sync all data since we're not using zones yet
        return try await syncAllData()
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
        
        var didSync = false
        
        // Sync ROMs
        if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
            let count = await syncer.syncMetadataOnly()
            if count > 0 {
                didSync = true
                DLOG("Synced \(count) ROM records")
            }
        }
        
        // Sync save states
        if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
            let count = await syncer.syncMetadataOnly()
            if count > 0 {
                didSync = true
                DLOG("Synced \(count) save state records")
            }
        }
        
        // Sync BIOS files
        if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
            let count = await syncer.syncMetadataOnly()
            if count > 0 {
                didSync = true
                DLOG("Synced \(count) BIOS records")
            }
        }
        
        return didSync ? .newData : .noData
    }
}
