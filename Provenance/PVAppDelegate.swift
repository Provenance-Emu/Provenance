//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

import CoreSpotlight
import PVLibrary
import PVSupport
import RealmSwift
import RxSwift
#if !targetEnvironment(macCatalyst) && !os(macOS) // && canImport(SteamController)
import SteamController
import UIKit
#endif

final class PVApplication: UIApplication {
    var core: PVEmulatorCore?
    override func sendEvent(_ event: UIEvent) {
        if (core != nil) {
            core!.send(event)
        }

        super.sendEvent(event)
    }
}


final class PVAppDelegate: UIResponder, UIApplicationDelegate {
    internal var window: UIWindow?
    var shortcutItemGame: PVGame?
    let disposeBag = DisposeBag()

    #if os(iOS)
    weak var jitScreenDelegate: JitScreenDelegate?
    weak var jitWaitScreenVC: JitWaitScreenViewController?
    var cancellation_token = DOLCancellationToken()
    var is_presenting_alert = false
    #endif
    
    weak var rootNavigationVC: UIViewController?
    weak var gameLibraryViewController: PVGameLibraryViewController?

    func _initUITheme() {
        #if os(iOS)
        let darkTheme = (PVSettingsModel.shared.theme == .auto && self.window?.traitCollection.userInterfaceStyle == .dark) || PVSettingsModel.shared.theme == .dark
        Theme.currentTheme = darkTheme ? Theme.darkTheme : Theme.lightTheme
        #elseif os(tvOS)
        if PVSettingsModel.shared.debugOptions.tvOSThemes {
            DispatchQueue.main.async {
                Theme.currentTheme = Theme.darkTheme
            }
        }
        #endif
    }

    func _initUI(
        libraryUpdatesController: PVGameLibraryUpdatesController,
        gameImporter: GameImporter,
        gameLibrary: PVGameLibrary
    ) {
        _initUITheme()

        // Set root view controller and make windows visible
        let window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window = window

        #if os(tvOS)
        window.tintColor = .provenanceBlue
        #else
        let darkTheme = (PVSettingsModel.shared.theme == .auto && window.traitCollection.userInterfaceStyle == .dark) || PVSettingsModel.shared.theme == .dark
        window.overrideUserInterfaceStyle = darkTheme ? .dark : .light
        #endif

        if #available(iOS 14, tvOS 14, macCatalyst 15.0, *),
           PVSettingsModel.shared.debugOptions.useSwiftUI {
            let viewModel = PVRootViewModel()
            let rootViewController = PVRootViewController.instantiate(
                updatesController: libraryUpdatesController,
                gameLibrary: gameLibrary,
                gameImporter: gameImporter,
                viewModel: viewModel)
            self.rootNavigationVC = rootViewController
            let sideNav = SideNavigationController(mainViewController: UINavigationController(rootViewController: rootViewController))
            sideNav.leftSide(
                viewController: SideMenuView.instantiate(gameLibrary: gameLibrary, viewModel: viewModel, delegate: rootViewController, rootDelegate: rootViewController),
                options: .init(widthPercent: 0.7, animationDuration: 0.18, overlayColor: .clear, overlayOpacity: 1, shadowOpacity: 0.0)
            )

            window.rootViewController = sideNav
        } else {
            let storyboard = UIStoryboard.init(name: "Provenance", bundle: Bundle.main)
            let vc = storyboard.instantiateInitialViewController()

            window.rootViewController = vc

            guard let rootNavigation = window.rootViewController as? UINavigationController else {
                fatalError("No root nav controller")
            }
            self.rootNavigationVC = rootNavigation
            guard let gameLibraryViewController = rootNavigation.viewControllers.first as? PVGameLibraryViewController else {
                fatalError("No gameLibraryViewController")
            }

            // Would be nice to inject this in a better way, so that we can be certain that it's present at viewDidLoad for PVGameLibraryViewController, but this works for now
            gameLibraryViewController.updatesController = libraryUpdatesController
            gameLibraryViewController.gameImporter = gameImporter
            gameLibraryViewController.gameLibrary = gameLibrary
            
            self.gameLibraryViewController = gameLibraryViewController
        }
        
        #if os(iOS)
        if PVSettingsModel.shared.debugOptions.autoJIT {
            DOLJitManager.shared().attemptToAcquireJitOnStartup()
        }
        DispatchQueue.main.async { [unowned self] in
            self.showJITWaitScreen()
        }
        #endif
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.isIdleTimerDisabled = PVSettingsModel.shared.disableAutoLock
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()

//		#if !(targetEnvironment(macCatalyst) || os(macOS))
        PVEmulatorConfiguration.initICloud()
        DispatchQueue.global(qos: .background).async {
            let useiCloud = PVSettingsModel.shared.debugOptions.iCloudSync && PVEmulatorConfiguration.supportsICloud
            if useiCloud {
                DispatchQueue.main.async {
                    iCloudSync.initICloudDocuments()
                    iCloudSync.importNewSaves()
                }
            }
        }
//		#endif

        do {
            try RomDatabase.initDefaultDatabase()
        } catch {
            let appName: String = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "the application"
            let alert = UIAlertController(title: NSLocalizedString("Database Error", comment: ""), message: error.localizedDescription + "\nDelete and reinstall " + appName + ".", preferredStyle: .alert)
            ELOG(error.localizedDescription)
            alert.addAction(UIAlertAction(title: "Exit", style: .destructive, handler: { _ in
                fatalError(error.localizedDescription)
            }))

            self.window?.rootViewController = UIViewController()
            self.window?.makeKeyAndVisible()
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
                gameLibrary.recents.mapMany { $0.game?.asShortcut(isFavorite: false) }
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
//                gameLibrary.clearLibrary()
                gameLibrary.clearROMs()
            }
            .subscribe().disposed(by: disposeBag)

        _initUI(libraryUpdatesController: libraryUpdatesController, gameImporter: gameImporter, gameLibrary: gameLibrary)

        let database = RomDatabase.sharedInstance
        database.refresh()

        #if !targetEnvironment(macCatalyst) && canImport(SteamController) && !targetEnvironment(simulator)
        // SteamController is build with STEAMCONTROLLER_NO_PRIVATE_API, so dont call this! ??
        // SteamControllerManager.listenForConnections()
        #endif

        #if os(iOS) && !targetEnvironment(macCatalyst)
//            PVAltKitService.shared.start()
            ApplicationMonitor.shared.start()
        #endif

		DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: { [unowned self] in
			self.startOptionalWebDavServer()
		})

        self.window!.makeKeyAndVisible()

        return true
    }

    func applicationWillResignActive(_: UIApplication) {}

    func applicationDidEnterBackground(_: UIApplication) {}

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_: UIApplication) {}

    func applicationWillTerminate(_: UIApplication) {}
}
