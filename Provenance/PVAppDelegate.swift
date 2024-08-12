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
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVUIBase
import PVUIKit
import PVSwiftUI

#if !targetEnvironment(macCatalyst) && !os(macOS)
#if canImport(SteamController)
import SteamController
#endif
import UIKit
#endif

final class PVAppDelegate: UIResponder, GameLaunchingAppDelegate {
    internal var window: UIWindow?
    var shortcutItemGame: PVGame?
    let disposeBag = DisposeBag()

    #if os(iOS) && !APP_STORE
    weak var jitScreenDelegate: JitScreenDelegate?
    weak var jitWaitScreenVC: JitWaitScreenViewController?
    var cancellation_token = DOLCancellationToken()
    var is_presenting_alert = false
    #endif
    
    weak var rootNavigationVC: UIViewController?
    weak var gameLibraryViewController: PVGameLibraryViewController?

    func _initUITheme() {
        #if os(iOS)
        let darkTheme = (Defaults[.theme] == .auto && self.window?.traitCollection.userInterfaceStyle == .dark) || Defaults[.theme] == .dark
        let newTheme = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
//        ThemeManager.shared.setCurrentTheme(newTheme)
        self.window?.overrideUserInterfaceStyle = ThemeManager.shared.currentTheme.dark ? .dark : .light
        #elseif os(tvOS)
//        if Defaults[.tvOSThemes] {
//            DispatchQueue.main.async {
//                ThemeManager.shared.currentTheme = Theme.darkTheme
//            }
//        }
        #endif
    }

    func _initUI(
        libraryUpdatesController: PVGameLibraryUpdatesController,
        gameImporter: GameImporter,
        gameLibrary: PVGameLibrary
    ) {
        // Set root view controller and make windows visible
        let window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window = window

        _initUITheme()
        
        #if os(tvOS)
        window.tintColor = .provenanceBlue
        #endif

        if #available(iOS 14, tvOS 14, macCatalyst 15.0, visionOS 1.0, *),
           Defaults[.useSwiftUI] {
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
            let storyboard = UIStoryboard.init(name: "Provenance", bundle: PVUIKit.BundleLoader.bundle)
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

        #if os(iOS) && !APP_STORE
        if Defaults[.autoJIT] {
            DOLJitManager.shared().attemptToAcquireJitOnStartup()
        }
        DispatchQueue.main.async { [unowned self] in
            self.showJITWaitScreen()
        }
        #endif
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.isIdleTimerDisabled = Defaults[.disableAutoLock]
        loadRocketSimConnect()
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()

//		#if !(targetEnvironment(macCatalyst) || os(macOS))
        PVEmulatorConfiguration.initICloud()
        DispatchQueue.global(qos: .background).async {
            let useiCloud = Defaults[.iCloudSync] && PVEmulatorConfiguration.supportsICloud
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
            print("Error: Database Error\n")
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
            if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem, 
                shortcut.type == "kRecentGameShortcut",
                let md5Value = shortcut.userInfo?["PVGameHash"] as? String,
                let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                shortcutItemGame = matchedGame
            }
        #endif

        if #available(iOS 17.0, *) {
            withObservationTracking {
                _ = ThemeManager.shared.currentTheme
            } onChange: { [unowned self] in
                print("changed: ", ThemeManager.shared.currentTheme)
                Task.detached { @MainActor in
                    self._initUITheme()
                }
            }
        } else {
            // Fallback on earlier versions
        }

        // Setup importing/updating library
        let gameImporter = GameImporter.shared

        self.handleNotifications()

        Task { @MainActor in
            let libraryUpdatesController = await PVGameLibraryUpdatesController(gameImporter: gameImporter)
#if os(iOS) || os(macOS)
            libraryUpdatesController.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance).disposed(by: disposeBag)
#endif

            // Handle refreshing library
            _initUI(libraryUpdatesController: libraryUpdatesController, gameImporter: gameImporter, gameLibrary: gameLibrary)
            self.window!.makeKeyAndVisible()
        }

        Task.detached {
            let database = RomDatabase.sharedInstance
            database.refresh()
            database.reloadCache()
        }

        #if !targetEnvironment(macCatalyst) && canImport(SteamController) && !targetEnvironment(simulator)
        // SteamController is build with STEAMCONTROLLER_NO_PRIVATE_API, so dont call this! ??
        // SteamControllerManager.listenForConnections()
        #endif

        #if os(iOS) && !targetEnvironment(macCatalyst) && !APP_STORE
//            PVAltKitService.shared.start()
            ApplicationMonitor.shared.start()
        #endif

        
		DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: { [unowned self] in
			self.startOptionalWebDavServer()
		})

        return true
    }

    func saveCoreState(_ application: PVApplication) async throws {
        if let core = application.core {
            if core.isOn, let emulator = application.emulator {
                if Defaults[.autoSave], core.supportsSaveStates {
                    ILOG("PVAppDelegate: Saving Core State\n")
                    try await emulator.autoSaveState()
                }
            }
        }
    }

    func pauseCore(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn && core.isRunning {
                ILOG("PVAppDelegate: Pausing Core\n")
                core.setPauseEmulation(true)
            }
        }
    }

    func stopCore(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn {
                ILOG("PVAppDelegate: Stopping Core\n")
                core.stopEmulation()
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        if let app=application as? PVApplication {
            app.isInBackground = true;

            pauseCore(app)
            sleep(1)

            Task {
                try await saveCoreState(app)
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if let app=application as? PVApplication {
            app.isInBackground = true;
            pauseCore(app)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let app=application as? PVApplication {
            app.isInBackground = false;
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if let app=application as? PVApplication {
            stopCore(app)
        }
    }
    func handleNotifications() {
        NotificationCenter.default.rx.notification(.PVReimportLibrary)
            .flatMapLatest { _ in
                return Completable.create { observer in
                    RomDatabase.sharedInstance.refresh()
                    self.gameLibraryViewController?.checkROMs(false)

                    observer(.completed)
                    return Disposables.create()
                }
            }
            .subscribe(onCompleted: {}).disposed(by: disposeBag)
        NotificationCenter.default.rx.notification(.PVRefreshLibrary)
            .flatMapLatest { _ in
                return Completable.create { observer in
                    do {
                        try RomDatabase.sharedInstance.deleteAllGames()
                        self.gameLibraryViewController?.checkROMs(false)
                        observer(.completed)
                    } catch {
                        NSLog("Failed to refresh all objects. \(error.localizedDescription)")
                        observer(.error(error))
                    }
                    return Disposables.create()
                }
            }
            .subscribe(onCompleted: {}).disposed(by: disposeBag)
        NotificationCenter.default.rx.notification(.PVResetLibrary)
            .flatMapLatest { _ in
                return Completable.create { observer in
                    do {
                        NSLog("PVAppDelegate: Completed ResetLibrary, Re-Importing")
                        try RomDatabase.sharedInstance.deleteAllData()
                        Task {
                            await GameImporter.shared.initSystems()
                            self.gameLibraryViewController?.checkROMs(false)
                            observer(.completed)
                        }
                    } catch {
                        NSLog("Failed to delete all objects. \(error.localizedDescription)")
                        observer(.error(error))
                    }
                    return Disposables.create()
                }
            }
            .subscribe(onCompleted: {}).disposed(by: disposeBag)
    }
}

private func loadRocketSimConnect() {
    #if DEBUG
    guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
        print("Failed to load linker framework")
        return
    }
    print("RocketSim Connect successfully linked")
    #endif
}
