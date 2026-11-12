import UIKit
import Intents
import PVUIBase

/// Receives platform callbacks without owning windows or navigation.
/// SwiftUI has no equivalents for APNs registration or Home Screen shortcut delivery.
public final class PVSystemEvents: UIResponder, UIApplicationDelegate {
    private var services: PVApplicationServices { .shared }

    public func applicationWillTerminate(_ application: UIApplication) {
        services.prepareForTermination()
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        services.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        services.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        services.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        services.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    #if os(iOS)
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        let configuration = UISceneConfiguration(name: nil, sessionRole: role)
        // A cabled display or AirPlay screen: no app window of its own, only what
        // `ExternalDisplayCoordinator`'s clients put there (the game picture).
        configuration.delegateClass = role == .windowExternalDisplayNonInteractive
            ? PVExternalDisplaySceneDelegate.self
            : PVSceneDelegate.self
        return configuration
    }

    public func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        services.application(application, handle: intent, completionHandler: completionHandler)
    }

    public func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        services.application(application, handlerFor: intent)
    }
    #endif
}
