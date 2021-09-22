//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

let TEST_THEMES = false
import CocoaLumberjackSwift
import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift
import RxSwift
#if !targetEnvironment(macCatalyst)
import SteamController
#endif

@UIApplicationMain
final class PVAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var shortcutItemGame: PVGame?
    var fileLogger: DDFileLogger = DDFileLogger()
    let disposeBag = DisposeBag()

    #if os(iOS)
        var _logViewController: PVLogViewController?
    #endif

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.isIdleTimerDisabled = PVSettingsModel.shared.disableAutoLock
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()

		#if !targetEnvironment(macCatalyst)
        DispatchQueue.global(qos: .background).async {
            let useiCloud = PVSettingsModel.shared.debugOptions.iCloudSync && PVEmulatorConfiguration.supportsICloud
            if useiCloud {
                DispatchQueue.main.async {
                    iCloudSync.initICloudDocuments()
                    iCloudSync.importNewSaves()
                }
            }
        }
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

        let gameLibrary = PVGameLibrary(database: RomDatabase.sharedInstance)

        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
            // Setup shortcuts
            Observable.combineLatest(
                gameLibrary.favorites.mapMany { $0.asShortcut(isFavorite: true) },
                gameLibrary.recents.mapMany { $0.game.asShortcut(isFavorite: false) }
            ) { $0 + $1 }
                .bind(onNext: { shortcuts in
                    application.shortcutItems = shortcuts
                })
                .disposed(by: disposeBag)

            // Handle if started from shortcut
            if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem, shortcut.type == "kRecentGameShortcut", let md5Value = shortcut.userInfo?["PVGameHash"] as? String, let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                shortcutItemGame = matchedGame
            }
        #endif

        #if os(tvOS)
            if let tabBarController = window?.rootViewController as? UITabBarController {
                let searchNavigationController = PVSearchViewController.createEmbeddedInNavigationController(gameLibrary: gameLibrary)

                guard var viewControllers = tabBarController.viewControllers else {
                    fatalError("tabBarController.viewControllers is nil")
                }
                viewControllers.insert(searchNavigationController, at: 1)
                tabBarController.viewControllers = viewControllers
            }
        #else
//        let currentTheme = PVSettingsModel.shared.theme
//        Theme.currentTheme = currentTheme.theme
            Theme.currentTheme = Theme.darkTheme
        #endif

        // Setup importing/updating library
        let gameImporter = GameImporter.shared
        let libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)
        #if os(iOS) || os(macOS)
            libraryUpdatesController.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance).disposed(by: disposeBag)
        #endif

        // Handle refreshing library
        NotificationCenter.default.rx.notification(.PVRefreshLibrary)
            .flatMapLatest { _ in
                // Clear the database, then the user has to restart to re-scan
                gameLibrary.clearLibrary()
            }
            .subscribe().disposed(by: disposeBag)

        #if os(iOS) || os(macOS)
        guard let rootNavigation = window?.rootViewController as? UINavigationController else {
            fatalError("No root nav controller")
        }
        #else
        guard let tabBarController = window?.rootViewController as? UITabBarController,
              let rootNavigation = tabBarController.viewControllers?[0] as? UINavigationController,
              let splitVC = tabBarController.viewControllers?[2] as? PVTVSplitViewController,
              let navVC = splitVC.viewControllers[1] as? UINavigationController,
              let settingsVC = navVC.topViewController as? PVSettingsViewController else {
                  fatalError("Bad View Controller heiarchy")
              }
        settingsVC.conflictsController = libraryUpdatesController
        #endif
        guard let gameLibraryViewController = rootNavigation.viewControllers.first as? PVGameLibraryViewController else {
            fatalError("No gameLibraryViewController")
        }

        // Would be nice to inject this in a better way, so that we can be certain that it's present at viewDidLoad for PVGameLibraryViewController, but this works for now
        gameLibraryViewController.updatesController = libraryUpdatesController
        gameLibraryViewController.gameImporter = gameImporter
        gameLibraryViewController.gameLibrary = gameLibrary

        let database = RomDatabase.sharedInstance
        database.refresh()

        #if !targetEnvironment(macCatalyst)
        SteamControllerManager.listenForConnections()
        #endif

        if #available(iOS 11, tvOS 11, *) {
            PVAltKitService.shared.start()
        }

		DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: { [unowned self] in
			self.startOptionalWebDavServer()
		})

        return true
    }

    func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        #if os(tvOS)
        importFile(atURL: url)
        return true
        #else
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

                if let openInPlace = options[.openInPlace] as? Bool, openInPlace {
                    try FileManager.default.copyItem(at: url, to: destinationPath)
                } else {
                    try FileManager.default.moveItem(at: url, to: destinationPath)
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

            let sendingAppID = options[.sourceApplication]
            ILOG("App with id <\(sendingAppID ?? "nil")> requested to open url \(url.absoluteString)")

            if components.host == "open" {
                guard let queryItems = components.queryItems, !queryItems.isEmpty else {
                    return false
                }

                let md5QueryItem = queryItems.first { $0.name == PVGameMD5Key }
                let systemItem = queryItems.first { $0.name == "system" }
                let nameItem = queryItems.first { $0.name == "title" }

                if let md5QueryItem = md5QueryItem, let value = md5QueryItem.value, !value.isEmpty, let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: value)) as PVGame??) {
                    // Match by md5
                    ILOG("Open by md5 \(value)")
                    shortcutItemGame = matchedGame
                    return true
                } else if let gameName = nameItem?.value, !gameName.isEmpty {
                    if let systemItem = systemItem {
                        // MAtch by name and system
                        if let value = systemItem.value, !value.isEmpty, let systemMaybe = ((try? Realm().object(ofType: PVSystem.self, forPrimaryKey: value)) as PVSystem??), let matchedSystem = systemMaybe {
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
        } else if let components = components, components.path == PVGameControllerKey, let first = components.queryItems?.first, first.name == PVGameMD5Key, let md5Value = first.value, let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
            shortcutItemGame = matchedGame
            return true
        }

        return false
        #endif
    }

    #if os(iOS) || os(macOS)
        func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
            if shortcutItem.type == "kRecentGameShortcut", let md5Value = shortcutItem.userInfo?["PVGameHash"] as? String, let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                shortcutItemGame = matchedGame
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    #endif

    func application(_: UIApplication, continue userActivity: NSUserActivity, restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Spotlight search click-through
        #if os(iOS) || os(macOS)
            if userActivity.activityType == CSSearchableItemActionType {
                if let md5 = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, let md5Value = md5.components(separatedBy: ".").last, let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                    // Comes in a format of "com....md5"
                    shortcutItemGame = matchedGame
                    return true
                } else {
                    WLOG("Spotlight activity didn't contain the MD5 I was looking for")
                }
            }
        #endif

        return false
    }

    func applicationWillResignActive(_: UIApplication) {}

    func applicationDidEnterBackground(_: UIApplication) {}

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_: UIApplication) {}

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

        DDOSLogger.sharedInstance.logFormatter = PVTTYFormatter()
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

#if os(iOS) || os(macOS)
@available(iOS 9.0, macOS 11.0, macCatalyst 11.0, *)
extension PVGame {
    func asShortcut(isFavorite: Bool) -> UIApplicationShortcutItem {
        let icon: UIApplicationShortcutIcon = isFavorite ? .init(type: .favorite) : .init(type: .play)
        return UIApplicationShortcutItem(type: "kRecentGameShortcut", localizedTitle: title, localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: systemIdentifier), icon: icon, userInfo: ["PVGameHash": md5Hash as NSSecureCoding])
    }
}
#endif
