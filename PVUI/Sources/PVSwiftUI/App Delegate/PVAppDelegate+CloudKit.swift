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

/// Extension to handle CloudKit remote notifications in the app delegate
extension PVAppDelegate {
    /// Initialize CloudKit for all platforms
    func initializeCloudKit() {
        // Register for remote notifications if iCloud sync is enabled
        if Defaults[.iCloudSync] {
            DLOG("Initializing CloudKit for all platforms")
            
            // Initialize CloudKit schema first
            Task {
                // Get the container identifier from the bundle
                let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.provenance-emu.provenance"
                let containerIdentifier = "iCloud." + bundleIdentifier
                
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
                
                // Register for remote notifications
                CloudKitSubscriptionManager.shared.registerForRemoteNotifications()
                
                // Set up CloudKit subscriptions
                await CloudKitSubscriptionManager.shared.setupSubscriptions()
                
                // Start initial sync
                _ = try? await CloudSyncManager.shared.startSync().value
            }
        }
    }
    
    /// Handle a remote notification
    /// - Parameters:
    ///   - application: The application
    ///   - userInfo: User info from the notification
    ///   - fetchCompletionHandler: Completion handler to call when done
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if this is a CloudKit notification
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            completionHandler(.noData)
            return
        }
        
        DLOG("Received CloudKit notification: \(notification.notificationType.rawValue)")
        
        // Handle notification
        CloudKitSubscriptionManager.shared.handleRemoteNotification(userInfo)
        
        // Start sync
        Task {
            do {
                // Start sync
                _ = try await CloudSyncManager.shared.startSync().value
                
                // Complete with new data
                completionHandler(.newData)
            } catch {
                ELOG("Error handling CloudKit notification: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
    }
    
    /// Handle successful registration for remote notifications
    /// - Parameters:
    ///   - application: The application
    ///   - deviceToken: Device token
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DLOG("Registered for remote notifications with device token: \(tokenString)")
        
        // Set up CloudKit subscriptions
        Task {
            await CloudKitSubscriptionManager.shared.setupSubscriptions()
        }
    }
    
    /// Handle failure to register for remote notifications
    /// - Parameters:
    ///   - application: The application
    ///   - error: Error
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        ELOG("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
