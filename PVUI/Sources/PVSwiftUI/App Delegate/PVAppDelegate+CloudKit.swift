//
//  PVAppDelegate+CloudKit.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import CloudKit
import PVLogging
import PVLibrary
import Defaults
import BackgroundTasks

/// Extension to handle CloudKit remote notifications in the app delegate
extension PVAppDelegate {
    /// Initialize CloudKit for all platforms
    func initializeCloudKit() {
        // Register for remote notifications if iCloud sync is enabled
        if Defaults[.iCloudSync] {
            DLOG("Initializing CloudKit for all platforms")
            
            // Initialize CloudKit schema first
            Task {
                let containerIdentifier = iCloudConstants.containerIdentifier
                
                // Initialize CloudKit container and database
                let container = CKContainer(identifier: containerIdentifier)
                let privateDatabase = container.privateCloudDatabase
                
                // Initialize CloudKit schema
                DLOG("Initializing CloudKit schema...")
                let success = await CloudKitSchema.initializeSchema(in: privateDatabase)
                if success {
                    DLOG("CloudKit schema initialized successfully")
                } else {
                    ELOG("Failed to initialize CloudKit schema")
                }
                
                // Initialize CloudSyncManager to create syncers
                _ = CloudSyncManager.shared
                DLOG("CloudSyncManager initialized")
                
                // Register for remote notifications and setup background tasks
                setupCloudKitBackgroundSync()
                
                // Start initial sync
                _ = try? await CloudSyncManager.shared.startSync().value
            }
        }
    }
    
    /// Setup CloudKit background sync and notifications
    private func setupCloudKitBackgroundSync() {
        // Register for remote notifications
        CloudKitNotificationManager.shared.registerForRemoteNotifications()
        
        // Setup CloudKit subscriptions for push notifications
        Task {
            await CloudKitNotificationManager.shared.setupSubscriptions()
        }
        
        // Register background tasks
        registerBackgroundTasks()
    }
    
    /// Schedule background tasks for CloudKit sync
    /// Registration is done in the main AppDelegate at app launch
    private func registerBackgroundTasks() {
        // Only schedule the task - registration is done in the AppDelegate at launch
        scheduleCloudKitSyncTask()
        
        DLOG("Scheduled background tasks for CloudKit sync")
    }
    
    /// Schedule a background task for CloudKit sync
    private func scheduleCloudKitSyncTask() {
        let request = BGProcessingTaskRequest(identifier: "com.provenance-emu.provenance.cloudkit-sync")
        
        // Only run when on Wi-Fi and charging
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        // Set earliest begin date to 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DLOG("Scheduled background CloudKit sync task")
        } catch {
            ELOG("Could not schedule background CloudKit sync: \(error.localizedDescription)")
        }
    }
    
    /// Handle a background CloudKit sync task
    /// - Parameter task: The background processing task
    private func handleCloudKitSyncTask(_ task: BGProcessingTask) {
        DLOG("Starting background CloudKit sync task")
        
        // Schedule the next background task
        scheduleCloudKitSyncTask()
        
        // Create a task assertion to track the background work
        let taskAssertionID = UIApplication.shared.beginBackgroundTask {
            // If the background task expires, complete the BGTask
            task.setTaskCompleted(success: false)
        }
        
        // Perform the sync in the background
        Task {
            do {
                // Sync metadata only to avoid large downloads in the background
                var didSync = false
                
                // Sync ROMs
                if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background sync: Synced \(count) ROM records")
                    }
                }
                
                // Sync save states
                if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background sync: Synced \(count) save state records")
                    }
                }
                
                // Sync BIOS files
                if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background sync: Synced \(count) BIOS records")
                    }
                }
                
                // Mark the task as completed
                task.setTaskCompleted(success: true)
                
                // End the background task assertion
                if taskAssertionID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskAssertionID)
                }
                
                DLOG("Background CloudKit sync completed successfully")
            } catch {
                ELOG("Error during background CloudKit sync: \(error.localizedDescription)")
                
                // Mark the task as completed with failure
                task.setTaskCompleted(success: false)
                
                // End the background task assertion
                if taskAssertionID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskAssertionID)
                }
            }
        }
    }
    
    /// Handle a remote notification
    /// - Parameters:
    ///   - application: The application
    ///   - userInfo: User info from the notification
    ///   - fetchCompletionHandler: Completion handler to call when done
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if handleCloudKitNotification(userInfo, fetchCompletionHandler: completionHandler) {
            return
        }
        // Check if iCloud sync is enabled
        guard Defaults[.iCloudSync] else {
            DLOG("iCloud sync is disabled, ignoring notification")
            completionHandler(.noData)
            return
        }
        
        // Process the notification using our notification manager
        Task {
            let result = await CloudKitNotificationManager.shared.processNotification(userInfo)
            completionHandler(result)
        }
    }
    
    /// Handle successful registration for remote notifications
    /// - Parameters:
    ///   - application: The application
    ///   - deviceToken: Device token
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass the device token to our notification manager
        CloudKitNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    /// Handle failure to register for remote notifications
    /// - Parameters:
    ///   - application: The application
    ///   - error: The error that occurred
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Pass the error to our notification manager
        CloudKitNotificationManager.shared.didFailToRegisterForRemoteNotifications(withError: error)
    }
    
    /// Handle background fetch request
    /// - Parameters:
    ///   - application: The application
    ///   - completionHandler: Completion handler to call when done
    public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if iCloud sync is enabled
        guard Defaults[.iCloudSync] else {
            DLOG("iCloud sync is disabled, skipping background fetch")
            completionHandler(.noData)
            return
        }
        
        // Perform background sync
        Task {
            do {
                // Sync metadata only to avoid large downloads in the background
                var didSync = false
                
                // Sync ROMs
                if let syncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background fetch: Synced \(count) ROM records")
                    }
                }
                
                // Sync save states
                if let syncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background fetch: Synced \(count) save state records")
                    }
                }
                
                // Sync BIOS files
                if let syncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
                    let count = await syncer.syncMetadataOnly()
                    if count > 0 {
                        didSync = true
                        DLOG("Background fetch: Synced \(count) BIOS records")
                    }
                }
                
                // Return the appropriate result
                completionHandler(didSync ? .newData : .noData)
            } catch {
                ELOG("Error during background fetch: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
    
    /// Register for CloudKit push notifications
    func setupCloudKitNotifications() {
        // Only register if iCloud sync is enabled
        guard Defaults[.iCloudSync] else {
            DLOG("iCloud sync is disabled, skipping notification registration")
            return
        }
        
        // Register for remote notifications
        CloudKitNotificationManager.shared.registerForRemoteNotifications()
        
        // Setup background fetch
        setupBackgroundFetch()
    }
    
    /// Setup background fetch for periodic syncing
    private func setupBackgroundFetch() {
        // Set minimum background fetch interval
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        DLOG("Background fetch configured with minimum interval")
    }
    
    /// Handle a CloudKit remote notification
    /// - Parameters:
    ///   - userInfo: User info from the notification
    ///   - fetchCompletionHandler: Completion handler to call when done
    /// - Returns: True if the notification was handled, false otherwise
    func handleCloudKitNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return false
        }
        
        DLOG("Received CloudKit notification: \(notification.notificationType.rawValue)")
        
        // Handle notification
        CloudKitSubscriptionManager.shared.handleRemoteNotification(userInfo)
        
        // Start sync
        Task {
            do {
                // Start sync
                try await CloudSyncManager.shared.startSync().value
                
                // Complete with new data
                completionHandler(.newData)
            } catch {
                ELOG("Error handling CloudKit notification: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
        
        return true
    }
    
}
