//
//  AppDelegate+CloudKit.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import CloudKit
import PVLogging

/// Extension to handle CloudKit remote notifications in the app delegate
/// To use this, add the following to your AppDelegate:
///
/// ```swift
/// func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
///     if handleCloudKitNotification(userInfo, fetchCompletionHandler: completionHandler) {
///         return
///     }
///     
///     // Handle other remote notifications
///     completionHandler(.noData)
/// }
///
/// func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
///     handleCloudKitRegistration(deviceToken)
/// }
///
/// func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
///     handleCloudKitRegistrationFailure(error)
/// }
/// ```
#if os(tvOS)
public extension UIApplicationDelegate {
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
                _ = try await CloudSyncManager.shared.startSync().value
                
                // Complete with new data
                completionHandler(.newData)
            } catch {
                ELOG("Error handling CloudKit notification: \(error.localizedDescription)")
                completionHandler(.failed)
            }
        }
        
        return true
    }
    
    /// Handle successful registration for remote notifications
    /// - Parameter deviceToken: Device token
    func handleCloudKitRegistration(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DLOG("Registered for remote notifications with device token: \(tokenString)")
        
        // Set up CloudKit subscriptions
        Task {
            await CloudKitSubscriptionManager.shared.setupSubscriptions()
        }
    }
    
    /// Handle failure to register for remote notifications
    /// - Parameter error: Error
    func handleCloudKitRegistrationFailure(_ error: Error) {
        ELOG("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
#endif
