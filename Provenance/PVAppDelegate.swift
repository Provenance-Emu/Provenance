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
import PVLogging

#if canImport(PVJIT)
import PVJIT
import JITManager
#endif

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
    
    var isAppStore: Bool {
        // Test if Info.plist has PVAppType containing appstore
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }

    #if os(iOS) && !APP_STORE && canImport(PVJIT)
    weak var jitScreenDelegate: JitScreenDelegate?
    weak var jitWaitScreenVC: JitWaitScreenViewController?
    var cancellation_token = DOLCancellationToken()
    var is_presenting_alert = false
    #endif
    
    weak var rootNavigationVC: UIViewController?
    weak var gameLibraryViewController: PVGameLibraryViewController?

    func _initUITheme() {
        ThemeManager.applySavedTheme()
        themeAppUI(withPalette: ThemeManager.shared.currentPalette)
    }

    func _initUI(
        libraryUpdatesController: PVGameLibraryUpdatesController,
        gameImporter: GameImporter,
        gameLibrary: PVGameLibrary<RealmDatabaseDriver>
    ) {
        // Set root view controller and make windows visible
        let window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window = window
        
        #if os(tvOS)
        window.tintColor = .provenanceBlue
        #endif
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let widthPercentage: CGFloat = isIpad ? 0.3 : 0.7
        let overlayColor: UIColor = ThemeManager.shared.currentPalette.menuHeaderBackground

        if !Defaults[.useUIKit] {
            let viewModel = PVRootViewModel()
            let rootViewController = PVRootViewController.instantiate(
                updatesController: libraryUpdatesController,
                gameLibrary: gameLibrary,
                gameImporter: gameImporter,
                viewModel: viewModel)
            self.rootNavigationVC = rootViewController
            let sideNavHostedNavigationController = PVRootViewNavigationController(rootViewController: rootViewController)
            
            let sideNav = SideNavigationController(mainViewController:sideNavHostedNavigationController)
            sideNav.leftSide(
                viewController: SideMenuView.instantiate(gameLibrary: gameLibrary,
                                                         viewModel: viewModel,
                                                         delegate: rootViewController,
                                                         rootDelegate: rootViewController),
                options: .init(widthPercent: widthPercentage,
                               animationDuration: 0.18,
                               overlayColor: overlayColor,
                               overlayOpacity: 0.1,
                               shadowOpacity: 0.2)
            )

            window.rootViewController = sideNav
        } else {
            Task.detached { @MainActor in
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
        }

        #if os(iOS) && !APP_STORE
        if Defaults[.autoJIT] {
            DOLJitManager.shared.attemptToAcquireJitOnStartup()
        }
        DispatchQueue.main.async { [unowned self] in
            self.showJITWaitScreen()
        }
        #endif
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        loadRocketSimConnect()
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()
        _initICloud()
        _initUITheme()
        _initThemeListener()

        application.isIdleTimerDisabled = Defaults[.disableAutoLock]

        runDetachedTaskWithCompletion {
            try RomDatabase.initDefaultDatabase()
        } completion: { result in
            switch result {
            case .success(let value):
                Task.detached { @MainActor in
                    self._initLibraryNotificationHandlers()
                    self._initGameImporter(application, launchOptions: launchOptions)
                }
            case .failure(let error):
                Task { @MainActor in
                    let appName: String = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "the application"
                    ELOG("Error: Database Error\n")
                    let alert = UIAlertController(title: NSLocalizedString("Database Error", comment: ""), message: error.localizedDescription + "\nDelete and reinstall " + appName + ".", preferredStyle: .alert)
                    ELOG(error.localizedDescription)
                    alert.addAction(UIAlertAction(title: "Exit", style: .destructive, handler: { _ in
                        fatalError(error.localizedDescription)
                    }))
                    
                    self.window?.rootViewController = UIViewController()
                    self.window?.makeKeyAndVisible()
                    self.window?.rootViewController?.present(alert, animated: true, completion: nil)
                    
                }
            }
        }

        _initSteamControllers()

        #if os(iOS) && !targetEnvironment(macCatalyst) && !APP_STORE
//            PVAltKitService.shared.start()
            ApplicationMonitor.shared.start()
        #endif

        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: { [unowned self] in
            self.startOptionalWebDavServer()
            #if !os(tvOS)
            if self.isAppStore {
                self._initAppRating()
            }
            #endif
        })

        return true
    }
    
    func _initSteamControllers() {
        #if !targetEnvironment(macCatalyst) && canImport(SteamController) && !targetEnvironment(simulator)
        // SteamController is build with STEAMCONTROLLER_NO_PRIVATE_API, so dont call this! ??
        // SteamControllerManager.listenForConnections()
        #endif
    }
    
    func _initGameImporter(_ application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        // Setup importing/updating library
        let gameImporter = GameImporter.shared
        let gameLibrary = PVGameLibrary<RealmDatabaseDriver>(database: RomDatabase.sharedInstance)

        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
            /// Setup shortcuts
            Observable.combineLatest(
                gameLibrary.favorites.mapMany { $0.asShortcut(isFavorite: true) },
                gameLibrary.recents.mapMany { $0.game?.asShortcut(isFavorite: false) }
            ) { $0 + $1 }
                .bind(onNext: { shortcuts in
                    application.shortcutItems = shortcuts
                })
                .disposed(by: disposeBag)

            /// Handle if started from shortcut
            if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
                shortcut.type == "kRecentGameShortcut",
                let md5Value = shortcut.userInfo?["PVGameHash"] as? String,
                let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
                shortcutItemGame = matchedGame
            }
        #endif
        
        Task.detached { @MainActor in
            let database = RomDatabase.sharedInstance
            await gameImporter.initSystems()
            RomDatabase.reloadCache()
            
            let libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter)

            // Handle refreshing library
            self._initUI(libraryUpdatesController: libraryUpdatesController, gameImporter: gameImporter, gameLibrary: gameLibrary)
            self.window!.makeKeyAndVisible()
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
            Task.detached {
                await libraryUpdatesController.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance)
            }
#endif
        }
    }
    
    func _initICloud() {
        PVEmulatorConfiguration.initICloud()
        DispatchQueue.global(qos: .background).async {
            let useiCloud = Defaults[.iCloudSync] && URL.supportsICloud
            if useiCloud {
                DispatchQueue.main.async {
                    iCloudSync.initICloudDocuments()
                    iCloudSync.importNewSaves()
                }
            }
        }
    }
    
    func _initThemeListener() {
        if #available(iOS 17.0, *) {
            withObservationTracking {
                _ = UITraitCollection.current.userInterfaceStyle
            } onChange: { [unowned self] in
                ILOG("changed: \(UITraitCollection.current.userInterfaceStyle)")
                Task.detached { @MainActor in
                    self._initUITheme()
                    if self.isAppStore {
                        self.appRatingSignifigantEvent()
                    }
                }
            }

            withObservationTracking {
                _ = ThemeManager.shared.currentPalette
            } onChange: { [unowned self] in
                ILOG("changed: \(ThemeManager.shared.currentPalette.name)")
                Task.detached { @MainActor in
                    self._initUITheme()
                    if self.isAppStore {
                        self.appRatingSignifigantEvent()
                    }
                }
            }
        } else {
            // Fallback on earlier versions
        }
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
        if isAppStore {
            appRatingSignifigantEvent()
        }
    }

    func pauseCore(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn && core.isRunning {
                ILOG("PVAppDelegate: Pausing Core\n")
                core.setPauseEmulation(true)
            }
        }
        if isAppStore {
            appRatingSignifigantEvent()
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
                try await self.saveCoreState(app)
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
    func _initLibraryNotificationHandlers() {
        NotificationCenter.default.rx.notification(.PVReimportLibrary)
            .flatMapLatest { _ in
                return Completable.create { observer in
                    RomDatabase.refresh()
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

func runDetachedTaskWithCompletion<T>(
    priority: TaskPriority? = nil,
    operation: @escaping () async throws -> T,
    completion: @escaping (Result<T, Error>) -> Void
) {
    Task.detached(priority: priority) {
        do {
            let result = try await operation()
            completion(.success(result))
        } catch {
            completion(.failure(error))
        }
    }
}
