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
    var emulator: PVEmulatorViewController?
    var isInBackground: Bool = false
    override func sendEvent(_ event: UIEvent) {
        if let core=self.core {
            core.send(event)
        }
        super.sendEvent(event)
    }
}

#if !os(tvOS)
final class PVUINavigationController: UINavigationController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
#endif

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
        self.window?.overrideUserInterfaceStyle = darkTheme ? .dark : .light
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
        // Set root view controller and make windows visible
        let window = UIWindow.init(frame: UIScreen.main.bounds)
        self.window = window

        _initUITheme()
        
        #if os(tvOS)
        window.tintColor = .provenanceBlue
        #endif

        if #available(iOS 14, tvOS 14, macCatalyst 15.0, visionOS 1.0, *),
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
        self.handleNotifications()
        _initUI(libraryUpdatesController: libraryUpdatesController, gameImporter: gameImporter, gameLibrary: gameLibrary)

        let database = RomDatabase.sharedInstance
        database.refresh()
        database.reloadCache()

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

    func saveCoreState(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn, let emulator = application.emulator {
                if PVSettingsModel.shared.autoSave, core.supportsSaveStates {
                    NSLog("PVAppDelegate: Saving Core State\n")
                    emulator.autoSaveState { result in
                        switch result {
                            case .success:
                                NSLog("PVAppDelegate: Save Successful")
                                break
                            case let .error(error):
                                NSLog("PVAppDelegate: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    func pauseCore(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn && core.isRunning {
                NSLog("PVAppDelegate: Pausing Core\n")
                core.setPauseEmulation(true)
            }
        }
    }

    func stopCore(_ application: PVApplication) {
        if let core = application.core {
            if core.isOn {
                NSLog("PVAppDelegate: Stopping Core\n")
                core.stopEmulation()
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        if let app=application as? PVApplication {
            app.isInBackground = true;

            pauseCore(app)
            sleep(1)
            saveCoreState(app)
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
                        GameImporter.shared.initSystems()
                        self.gameLibraryViewController?.checkROMs(false)
                        observer(.completed)
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
