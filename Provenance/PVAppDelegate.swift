//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

let TEST_THEMES = false
import CocoaLumberjackSwift
import CoreSpotlight
import Crashlytics
import Fabric
import HockeySDK
import PVLibrary
import PVSupport
import RealmSwift

@UIApplicationMain
final class PVAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var shortcutItemGame: PVGame?
    var fileLogger: DDFileLogger = DDFileLogger()

    #if os(iOS)
        var _logViewController: PVLogViewController?
    #endif

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = PVSettingsModel.shared.disableAutoLock
        _initLogging()
        setDefaultsFromSettingsBundle()

        DispatchQueue.global(qos: .background).async {
            let useiCloud = PVSettingsModel.shared.debugOptions.iCloudSync && PVEmulatorConfiguration.supportsICloud
            if useiCloud {
                DispatchQueue.main.async {
                    iCloudSync.initICloudDocuments()
                    iCloudSync.importNewSaves()
                }
            }
        }

        #if targetEnvironment(simulator)
        #else
            _initHockeyApp()
            _initCrashlytics()
        #endif

        do {
            try RomDatabase.initDefaultDatabase()
        } catch {
            let appName: String = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "the application"
            let alert = UIAlertController(title: "Database Error", message: error.localizedDescription + "\nDelete and reinstall " + appName + ".", preferredStyle: .alert)
            ELOG(error.localizedDescription)
            alert.addAction(UIAlertAction(title: "Exit", style: .destructive, handler: { _ in
                fatalError(error.localizedDescription)
            }))

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.window?.rootViewController?.present(alert, animated: true, completion: nil)
            }

            return true
        }

        #if os(iOS)
            if #available(iOS 9.0, *) {
                if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem, shortcut.type == "kRecentGameShortcut", let md5Value = shortcut.userInfo?["PVGameHash"] as? String, let matchedGame = try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value) {
                    shortcutItemGame = matchedGame
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
//        let currentTheme = PVSettingsModel.shared.theme
//        Theme.currentTheme = currentTheme.theme
            Theme.currentTheme = Theme.darkTheme
        #endif

        startOptionalWebDavServer()

        let database = RomDatabase.sharedInstance
        database.refresh()

        return true
    }

    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.isFileURL {
            let filename = url.lastPathComponent
            let destinationPath = PVEmulatorConfiguration.Paths.romsImportPath.appendingPathComponent(filename, isDirectory: false)

            do {
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                // Doesn't seem we need access in dev builds?
                _ = url.startAccessingSecurityScopedResource()

                if #available(iOS 9.0, *) {
                    if let openInPlace = options[.openInPlace] as? Bool, openInPlace {
                        try FileManager.default.copyItem(at: url, to: destinationPath)
                    } else {
                        try FileManager.default.moveItem(at: url, to: destinationPath)
                    }
                } else {
                    // Fallback on earlier versions
                    try FileManager.default.copyItem(at: url, to: destinationPath)
                }
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
                guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                    return false
                }

                let md5QueryItem = queryItems.first { $0.name == PVGameMD5Key }
                let systemItem = queryItems.first { $0.name == "system" }
                let nameItem = queryItems.first { $0.name == "title" }

                if let md5QueryItem = md5QueryItem, let value = md5QueryItem.value, !value.isEmpty, let matchedGame = try? Realm().object(ofType: PVGame.self, forPrimaryKey: value) {
                    // Match by md5
                    ILOG("Open by md5 \(value)")
                    shortcutItemGame = matchedGame
                    return true
                } else if let gameName = nameItem?.value, !gameName.isEmpty {
                    if let systemItem = systemItem {
                        // MAtch by name and system
                        if let value = systemItem.value, !value.isEmpty, let systemMaybe = try? Realm().object(ofType: PVSystem.self, forPrimaryKey: value), let matchedSystem = systemMaybe {
                            if let matchedGame = RomDatabase.sharedInstance.all(PVGame.self).filter("systemIdentifier == %@ AND title == %@", matchedSystem.identifier, gameName).first {
                                ILOG("Open by system \(value), name: \(gameName)")
                                shortcutItemGame = matchedGame
                                return true
                            } else {
                                ELOG("Failed to open by system \(value), name: \(gameName)")
                                return false
                            }
                        } else {
                            ELOG("Invalid system id \(systemItem.value ?? "nil")")
                            return false
                        }
                    } else {
                        if let matchedGame = RomDatabase.sharedInstance.all(PVGame.self, where: #keyPath(PVGame.title), value: gameName).first {
                            ILOG("Open by name: \(gameName)")
                            shortcutItemGame = matchedGame
                            return true
                        } else {
                            ELOG("Failed to open by name: \(gameName)")
                            return false
                        }
                    }
                } else {
                    ELOG("Open Query didn't have acceptable values")
                    return false
                }

            } else {
                ELOG("Unsupported host <\(url.host?.removingPercentEncoding ?? "nil")>")
                return false
            }
        } else if let components = components, components.path == PVGameControllerKey, let first = components.queryItems?.first, first.name == PVGameMD5Key, let md5Value = first.value, let matchedGame = try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value) {
            shortcutItemGame = matchedGame
            return true
        }

        return false
    }

    #if os(iOS)
        @available(iOS 9.0, *)
        func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
            if shortcutItem.type == "kRecentGameShortcut", let md5Value = shortcutItem.userInfo?["PVGameHash"] as? String, let matchedGame = try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value) {
                shortcutItemGame = matchedGame
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    #endif

    func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Spotlight search click-through
        #if os(iOS)
            if #available(iOS 9.0, *) {
                if userActivity.activityType == CSSearchableItemActionType {
                    if let md5 = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, let md5Value = md5.components(separatedBy: ".").last, let matchedGame = try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value) {
                        // Comes in a format of "com....md5"
                        shortcutItemGame = matchedGame
                        return true
                    } else {
                        WLOG("Spotlight activity didn't contain the MD5 I was looking for")
                    }
                }
            }
        #endif

        return false
    }

    func applicationWillResignActive(_: UIApplication) {}

    func applicationDidEnterBackground(_: UIApplication) {}

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_: UIApplication) {
        SteamControllerManager.shared().scanForControllers()
    }

    func applicationWillTerminate(_: UIApplication) {}

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

        fileLogger.maximumFileSize = (1024 * 64) // 64 KByte
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        fileLogger.rollLogFile(withCompletion: nil)
        DDLog.add(fileLogger)

        #if os(iOS)
            // Debug view logger
            DDLog.add(PVUIForLumberJack.sharedInstance(), with: .info)
            window?.addLogViewerGesture()
        #endif

        DDTTYLogger.sharedInstance.colorsEnabled = true
        DDTTYLogger.sharedInstance.logFormatter = PVTTYFormatter()
    }

    func _initHockeyApp() {
        #if os(tvOS)
            BITHockeyManager.shared().configure(withIdentifier: "613008343753414d93a7202324461575", delegate: self)
        #else
            BITHockeyManager.shared().configure(withIdentifier: "a1fd56cd852d4c959988484eba69f724", delegate: self)
        #endif

        #if DEBUG
            BITHockeyManager.shared().isMetricsManagerDisabled = true
        #endif

        let masterBranch = kGITBranch.lowercased() == "master"
        let developBranch = kGITBranch.lowercased() == "develop"
        let travisBuild = ["jmattiello", "travis"].contains(builtByUser)
        let masterOrDevelopBranch = masterBranch || developBranch
//        let feedbackEnabled = masterOrDevelopBranch && travisBuild

        #if os(iOS)
            BITHockeyManager.shared().isFeedbackManagerDisabled = !masterOrDevelopBranch
            BITHockeyManager.shared().isStoreUpdateManagerEnabled = false
        #endif

        BITHockeyManager.shared().isUpdateManagerDisabled = !masterBranch && travisBuild

//        if !UserDefaults.standard.bool(forKey: "hockeyAppEnabled") {
//            BITHockeyManager.shared().isUpdateManagerDisabled = true
//        }

        BITHockeyManager.shared().logLevel = BITLogLevel.warning
        BITHockeyManager.shared().start()
        BITHockeyManager.shared().authenticator.authenticateInstallation() // This line is obsolete in the crash only builds
    }

    func _initCrashlytics() {
        Fabric.with([Answers.self, Crashlytics.self])
    }

    func setDefaultsFromSettingsBundle() {
        // Read PreferenceSpecifiers from Root.plist in Settings.Bundle
        if let settingsURL = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
            let settingsPlist = NSDictionary(contentsOf: settingsURL),
            let preferences = settingsPlist["PreferenceSpecifiers"] as? [NSDictionary] {
            for prefSpecification in preferences {
                if let key = prefSpecification["Key"] as? String, let value = prefSpecification["DefaultValue"] {
                    // If key doesn't exists in userDefaults then register it, else keep original value
                    if UserDefaults.standard.value(forKey: key) == nil {
                        UserDefaults.standard.set(value, forKey: key)
                        ILOG("registerDefaultsFromSettingsBundle: Set following to UserDefaults - (key: \(key), value: \(value), type: \(type(of: value)))")
                    }
                }
            }
        } else {
            ELOG("registerDefaultsFromSettingsBundle: Could not find Settings.bundle")
        }
    }
}

extension PVAppDelegate: BITHockeyManagerDelegate {
    func getLogFilesContentWithMaxSize(_ maxSize: Int) -> String {
        var description = ""
        if let sortedLogFileInfos = fileLogger.logFileManager.sortedLogFileInfos {
            for logFile in sortedLogFileInfos {
                if let logData = FileManager.default.contents(atPath: logFile.filePath) {
                    if !logData.isEmpty {
                        description.append(String(data: logData, encoding: String.Encoding.utf8)!)
                    }
                }
            }
        }
        if description.count > maxSize {
            let index = description.index(description.startIndex, offsetBy: description.count - maxSize - 1)
            description = String(description.suffix(from: index))
        }
        return description
    }

    func applicationLog(for _: BITCrashManager!) -> String! {
        let description = getLogFilesContentWithMaxSize(5000) // 5000 bytes should be enough!
        if description.isEmpty {
            return nil
        } else {
            return description
        }
    }
}

#if os(tvOS)
    class PVTVTabBarController: UITabBarController {
        // MARK: - Keyboard actions

        public override var keyCommands: [UIKeyCommand]? {
            var sectionCommands = [UIKeyCommand]() /* TODO: .reserveCapacity(sectionInfo.count + 2) */

            let findCommand = UIKeyCommand(input: "f", modifierFlags: [.command], action: #selector(PVTVTabBarController.searchAction), discoverabilityTitle: "Find …")
            sectionCommands.append(findCommand)

            let settingsCommand = UIKeyCommand(input: ",", modifierFlags: [.command], action: #selector(PVTVTabBarController.settingsAction), discoverabilityTitle: "Settings")
            sectionCommands.append(settingsCommand)

            return sectionCommands
        }

        @objc
        func settingsAction() {
            selectedIndex = max(0, (viewControllers?.count ?? 1) - 1)
        }

        @objc
        func searchAction() {
            if let navVC = selectedViewController as? UINavigationController, let searchVC = navVC.viewControllers.first as? UISearchContainerViewController {
                // Reselect the search bar
                searchVC.searchController.searchBar.becomeFirstResponder()
                searchVC.searchController.searchBar.setNeedsFocusUpdate()
                searchVC.searchController.searchBar.updateFocusIfNeeded()
            } else {
                selectedIndex = 1
            }
        }
    }
#endif
