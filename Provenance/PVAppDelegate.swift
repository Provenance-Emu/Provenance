//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

let TEST_THEMES = false
import CoreSpotlight
import PVSupport
import CocoaLumberjackSwift

@UIApplicationMain
class PVAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var shortcutItemMD5: String?

	#if os(iOS)
	var _logViewController: PVLogViewController?
	#endif

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]? = nil) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = PVSettingsModel.shared.disableAutoLock
		_initLogging()

		do {
			try RomDatabase.initDefaultDatabase()
		} catch {
			let alert = UIAlertController(title: "Database Error", message: error.localizedDescription, preferredStyle: .alert)
			ELOG(error.localizedDescription)
			alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { alert in
				fatalError(error.localizedDescription)
			}))
			window?.rootViewController?.present(alert, animated: true, completion: nil)

			return true
		}

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
            flowLayout.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
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
        let currentTheme = PVSettingsModel.shared.theme
        Theme.currentTheme = currentTheme.theme
#endif

        startOptionalWebDavServer()

        let database = RomDatabase.sharedInstance
        database.refresh()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.isFileURL {
            let filename = url.lastPathComponent
            let destinationPath = PVEmulatorConfiguration.romsImportPath.appendingPathComponent(filename, isDirectory: false)

            do {
                try FileManager.default.moveItem(at: url, to: destinationPath)
            } catch {
                ELOG("Unable to move file from \(url.path) to \(destinationPath.path) because \(error.localizedDescription)")
                return false
            }

            return true
        } else if let scheme = url.scheme, scheme.lowercased() == PVAppURLKey {

            guard let components = components else {
                ELOG("Failed to parse url <\(url.absoluteString)>")
                return false
            }

            if #available(iOS 9.0, *) {
                let sendingAppID = options[.sourceApplication]
                ILOG("App with id <\(sendingAppID ?? "nil")> requested to open url \(url.absoluteString)")
            }

            if components.host == "open" {
                guard let queryItems = components.queryItems, let firstQueryItem = queryItems.first else {
                    return false
                }

                if firstQueryItem.name == PVGameMD5Key, let value = firstQueryItem.value, !value.isEmpty {
                    shortcutItemMD5 = value
                    return true
                } else {
                    ELOG("Query didn't have acceptable values")
                    return false
                }

            } else {
                ELOG("Unsupported host <\(url.host?.removingPercentEncoding ?? "nil")>")
                return false
            }
        } else if let components = components, components.path == PVGameControllerKey, let first = components.queryItems?.first, first.name == PVGameMD5Key {
            shortcutItemMD5 = first.value
            return true
        }

        return false
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
        if PVSettingsModel.shared.webDavAlwaysOn || isWebDavServerEnviromentVariableSet() {
            PVWebServer.shared.startWebDavServer()
        }
    }
}

extension PVAppDelegate {

	func _initLogging() {
		// Initialize logging
		PVLogging.sharedInstance()

		#if os(iOS)
		// Debug view logger
		DDLog.add(PVUIForLumberJack.sharedInstance(), with: .info)
		_addLogViewerGesture()
		#endif

		DDTTYLogger.sharedInstance.colorsEnabled = true
		DDTTYLogger.sharedInstance.logFormatter = PVTTYFormatter()
	}

	#if os(iOS)
	func _addLogViewerGesture() {
		guard let window = window else {
			ELOG("No window")
			return
		}

		let secretTap = UITapGestureRecognizer(target: self, action: #selector(PVAppDelegate._displayLogViewer))
		secretTap.numberOfTapsRequired = 3
		#if targetEnvironment(simulator)
		secretTap.numberOfTouchesRequired = 2
		#else
		secretTap.numberOfTouchesRequired = 3
		#endif
		window.addGestureRecognizer(secretTap)
	}

	@objc func _displayLogViewer() {
		guard let window = window else {
			ELOG("No window")
			return
		}

		if _logViewController == nil, let logClass = NSClassFromString("PVLogViewController") {
			let bundle = Bundle(for: logClass)
			_logViewController = PVLogViewController(nibName: "PVLogViewController", bundle: bundle)

		}
		// Window incase the mainNav never displays
		var  controller: UIViewController? = window.rootViewController

		if let presentedViewController = controller?.presentedViewController {
			controller = presentedViewController
		}
		controller!.present(_logViewController!, animated: true, completion: nil)
	}
	#endif
}
