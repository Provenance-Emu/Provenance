//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

let TEST_THEMES = false
import CoreSpotlight

@UIApplicationMain
class PVAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var shortcutItemMD5 : String? = nil
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = PVSettingsModel.sharedInstance().disableAutoLock
        
#if os(iOS)
        if #available(iOS 9.0, *) {
            if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem, shortcut.type == "kRecentGameShortcut" {
                shortcutItemMD5 = shortcut.userInfo?["PVGameHash"] as? String
            }
        }
#endif
        
#if os(tvOS)
        if let tabBarController = window?.rootViewController as? UITabBarController {
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.sectionInset = UIEdgeInsetsMake(20, 0, 20, 0)
            let searchViewController = PVSearchViewController(collectionViewLayout: flowLayout)
            let searchController = UISearchController(searchResultsController: searchViewController)
            searchController.searchResultsUpdater = searchViewController
            let searchContainerController = UISearchContainerViewController(searchController: searchController)
            searchContainerController.title = "Search"
            let navController = UINavigationController(rootViewController: searchContainerController)
            var viewControllers = tabBarController.viewControllers!
            viewControllers.insert(navController, at: 1)
            tabBarController.viewControllers = viewControllers
        }
#else

        if #available(iOS 9.0, *) {
            let currentTheme = PVSettingsModel.sharedInstance().theme
            Theme.setTheme(currentTheme.theme)
        }
#endif
        
        startOptionalWebDavServer()
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.isFileURL {
#if os(tvOS)
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
#else
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
#endif
            let documentsDirectory = paths.first!

            let filename = url.lastPathComponent
            let destinationPath = URL(fileURLWithPath:documentsDirectory).appendingPathComponent("roms", isDirectory: true).appendingPathComponent(filename)

            do {
                try FileManager.default.moveItem(at: url, to: destinationPath)
            } catch {
                ELOG("Unable to move file from \(url.path) to \(destinationPath.path) because \(error.localizedDescription)")
            }
        }
        else if (components?.path == PVGameControllerKey) && (components?.queryItems?.first?.name == PVGameMD5Key) {
            shortcutItemMD5 = components?.queryItems?.first?.value ?? ""
        }

        return true
    }
#if os(iOS)
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if (shortcutItem.type == "kRecentGameShortcut") {
            shortcutItemMD5 = shortcutItem.userInfo?["PVGameHash"] as? String
        }
        completionHandler(true)
    }
#endif
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {

        // Spotlight search click-through
        #if os(iOS)
        if #available(iOS 9.0, *) {
            if userActivity.activityType == CSSearchableItemActionType {
                if let md5 = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    // Comes in a format of "com....md5"
                    shortcutItemMD5 = md5.components(separatedBy: ".").last
                    return true
                } else {
                    WLOG("Spotlight activity didn't contain the MD5 I was looking for")
                }
            }
        }
        #endif

        return false
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }
    func applicationDidEnterBackground(_ application: UIApplication) {
    }
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    func applicationWillTerminate(_ application: UIApplication) {
    }
    
// MARK: - Helpers
    func isWebDavServerEnviromentVariableSet() -> Bool {
            // Start optional always on WebDav server using enviroment variable
            // See XCode run scheme enviroment varialbes settings.
            // Note: ENV variables are only passed when when from XCode scheme.
            // Users clicking the app icon won't be passed this variable when run outside of XCode
        let buildConfiguration = ProcessInfo.processInfo.environment["ALWAYS_ON_WEBDAV"]
        return buildConfiguration == "1"
    }
    
    func startOptionalWebDavServer() {
        // Check if the user setting is set or the optional ENV variable
        if PVSettingsModel.sharedInstance().webDavAlwaysOn || isWebDavServerEnviromentVariableSet() {
            PVWebServer.sharedInstance().startWebDavServer()
        }
    }
}

