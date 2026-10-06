//
//  PVAppDelegate+CloudKit.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import CloudKit
import PVLogging
import PVLibrary
import Defaults
import BackgroundTasks

/// Extension to handle CloudKit remote notifications in the app delegate
public extension PVAppDelegate {
    /// Initialize CloudKit for all platforms
    public func initializeCloudKit() {
        // Register for remote notifications if iCloud sync is enabled
        if Defaults[.iCloudSync] {
            DLOG("Initializing CloudKit for all platforms")

            // Initialize CloudKit schema first
            Task<Void, Never>.detached {
                // Guard: skip CloudKit init entirely on sideloaded builds without entitlement
                guard let container = iCloudConstants.container else {
                    WLOG("[CloudKit] Entitlement not present — CloudKit disabled (sideloaded build?)")
                    return
                }
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

                // Trigger a fast metadata-only ROM sync ASAP to populate library on fresh installs
                if let romsSyncer = CloudSyncManager.shared.romsSyncer as? CloudKitRomsSyncer {
                    Task.detached {
                        let count = await romsSyncer.syncMetadataOnly()
                        ILOG("Fast metadata-only ROM sync created/updated \(count) records")
                    }
                }

                // Register for remote notifications and setup background tasks
                self.setupCloudKitBackgroundSync()

                // Start initial sync
                try? await CloudSyncManager.shared.startSync()
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

        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.cloudKitSyncTaskInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            DLOG("Scheduled background CloudKit sync task")
        } catch {
            ELOG("Could not schedule background CloudKit sync: \(error.localizedDescription)")
        }
    }

    /// How long to wait between background CloudKit sync runs. Every launch
    /// resubmits the request, so a short interval meant iOS relaunched the
    /// app every 15 minutes while it was charging.
    private static let cloudKitSyncTaskInterval: TimeInterval = 4 * 60 * 60

    /// Handle a background processing task for CloudKit sync
    /// This is called by the BGTaskScheduler when a background task is launched
    public func handleCloudKitSyncTask(_ task: BGProcessingTask) {
        DLOG("Starting background CloudKit sync task")

        // Schedule the next background task
        scheduleCloudKitSyncTask()

        let work = Task {
            await syncCloudKitMetadataInBackground(source: "Background sync")
        }
        // Stop the work when iOS revokes our time; the task is reported
        // complete only after the work has actually returned, so no Realm
        // write is left running when the app is suspended.
        task.expirationHandler = {
            WLOG("Background CloudKit sync task expired — cancelling")
            work.cancel()
        }
        Task {
            let totalSynced = await work.value
            task.setTaskCompleted(success: !work.isCancelled && totalSynced > 0)
            DLOG("Background CloudKit sync task finished")
        }
    }

    /// Metadata-only sync for background launches: bounded, and finished
    /// before it returns, unlike `CloudSyncManager.startSync()`, which queues
    /// open-ended work.
    /// - Returns: The number of records synced.
    private func syncCloudKitMetadataInBackground(source: String) async -> Int {
        var totalSynced = 0
        for syncer in CloudKitSyncerStore.shared.cloudKitSyncers {
            if Task.isCancelled { break }
            let count = await syncer.syncMetadataOnly()
            if count > 0 {
                totalSynced += count
                DLOG("\(source): Synced \(count) records for type: \(syncer.recordType)")
            }
        }
        if totalSynced > 0 {
            DLOG("\(source): Total records synced: \(totalSynced)")
        } else {
            ILOG("\(source): No data to sync or syncers not found")
        }
        return totalSynced
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

        Task {
            let totalSynced = await syncCloudKitMetadataInBackground(source: "Background fetch")
            completionHandler(totalSynced > 0 ? .newData : .noData)
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

        Task { @MainActor in
            // In the background, iOS suspends the app once the completion
            // handler runs, so only do work that finishes before it.
            if UIApplication.shared.applicationState == .background {
                let totalSynced = await syncCloudKitMetadataInBackground(source: "CloudKit push")
                completionHandler(totalSynced > 0 ? .newData : .noData)
            } else {
                await CloudSyncManager.shared.startSync()
                completionHandler(.newData)
            }
        }

        return true
    }

}
