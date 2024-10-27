//  PVAppDelegate.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

// Import necessary modules for core functionality
import CoreSpotlight
import RealmSwift
import RxSwift
import UIKit

// Import custom modules for Provenance-specific functionality
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVUIBase
import PVUIKit
import PVSwiftUI
import PVLogging
import Combine
import Observation
import Perception
import SwiftUI
import Defaults

// Conditionally import PVJIT and JITManager if available
#if canImport(PVJIT)
import PVJIT
import JITManager
#endif

// Conditionally import SteamController for non-macCatalyst and non-macOS targets
#if !targetEnvironment(macCatalyst) && !os(macOS)
#if canImport(SteamController)
import SteamController
#endif
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

@Observable
final class PVAppDelegate: NSObject, GameLaunchingAppDelegate, UIApplicationDelegate {
    internal var window: UIWindow? = nil
    var shortcutItemGame: PVGame?
    var bootupState: AppBootupState {
        appState.bootupStateManager
    }
    var appState: AppState!

    // Check if the app is running in App Store mode
    var isAppStore: Bool {
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }

    // JIT-related properties for iOS, non-App Store builds with PVJIT support
#if os(iOS) && !APP_STORE && canImport(PVJIT)
    weak var jitScreenDelegate: JitScreenDelegate?
    weak var jitWaitScreenVC: JitWaitScreenViewController?
    var cancellation_token = DOLCancellationToken()
    var is_presenting_alert = false
#endif

    @MainActor weak var rootNavigationVC: UIViewController? = nil
    @MainActor weak var gameLibraryViewController: PVGameLibraryViewController? = nil


    // Initialize the UI theme
    @MainActor
    func _initUITheme() {
        ThemeManager.applySavedTheme()
        themeAppUI(withPalette: ThemeManager.shared.currentPalette)
    }
//
//    // Initialize the UI
//    @MainActor
//    func _initUI(
//        libraryUpdatesController: PVGameLibraryUpdatesController,
//        gameImporter: GameImporter,
//        gameLibrary: PVGameLibrary<RealmDatabaseDriver>
//    ) {
//        let window = setupWindow()
//        self.window = window
//
//        if !appState.useUIKit{
//            setupSwiftUIInterface(window: window,
//                                  libraryUpdatesController: libraryUpdatesController,
//                                  gameImporter: gameImporter,
//                                  gameLibrary: gameLibrary)
//        } else {
//            setupUIKitInterface(window: window,
//                                libraryUpdatesController: libraryUpdatesController,
//                                gameImporter: gameImporter,
//                                gameLibrary: gameLibrary)
//        }
//
//        _initUITheme()
//        setupJITIfNeeded()
//    }
//
//    private func setupWindow() -> UIWindow {
//        let window = UIWindow(frame: UIScreen.main.bounds)
//#if os(tvOS)
//        window.tintColor = .provenanceBlue
//#endif
//        return window
//    }
//
    private func setupSwiftUIInterface(window: UIWindow,
                                       libraryUpdatesController: PVGameLibraryUpdatesController,
                                       gameImporter: GameImporter,
                                       gameLibrary: PVGameLibrary<RealmDatabaseDriver>) {
        let viewModel = PVRootViewModel()
        let rootViewController = PVRootViewController.instantiate(
            updatesController: libraryUpdatesController,
            gameLibrary: gameLibrary,
            gameImporter: gameImporter,
            viewModel: viewModel)
        self.rootNavigationVC = rootViewController
        let sideNavHostedNavigationController = PVRootViewNavigationController(rootViewController: rootViewController)

        let sideNav = setupSideNavigation(mainViewController: sideNavHostedNavigationController,
                                          gameLibrary: gameLibrary,
                                          viewModel: viewModel,
                                          rootViewController: rootViewController)

        window.rootViewController = sideNav
    }

    fileprivate func setupSideNavigation(mainViewController: UIViewController,
                                     gameLibrary: PVGameLibrary<RealmDatabaseDriver>,
                                     viewModel: PVRootViewModel,
                                     rootViewController: PVRootViewController) -> SideNavigationController {
        let sideNav = SideNavigationController(mainViewController: mainViewController)
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let widthPercentage: CGFloat = isIpad ? 0.3 : 0.7
        let overlayColor: UIColor = ThemeManager.shared.currentPalette.menuHeaderBackground

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
        return sideNav
    }

    fileprivate func setupUIKitInterface(window: UIWindow,
                                     libraryUpdatesController: PVGameLibraryUpdatesController,
                                     gameImporter: GameImporter,
                                     gameLibrary: PVGameLibrary<RealmDatabaseDriver>) {
        Task.detached { @MainActor in
            let storyboard = UIStoryboard(name: "Provenance", bundle: PVUIKit.BundleLoader.bundle)
            let vc = storyboard.instantiateInitialViewController()

            window.rootViewController = vc

            guard let rootNavigation = window.rootViewController as? UINavigationController else {
                fatalError("No root nav controller")
            }
            self.rootNavigationVC = rootNavigation
            guard let gameLibraryViewController = rootNavigation.viewControllers.first as? PVGameLibraryViewController else {
                fatalError("No gameLibraryViewController")
            }

            gameLibraryViewController.updatesController = libraryUpdatesController
            gameLibraryViewController.gameImporter = gameImporter
            gameLibraryViewController.gameLibrary = gameLibrary

            self.gameLibraryViewController = gameLibraryViewController
        }
    }
//
//    private func setupJITIfNeeded() {
//#if os(iOS) && !APP_STORE
//        if Defaults[.autoJIT] {
//            DOLJitManager.shared.attemptToAcquireJitOnStartup()
//        }
//        DispatchQueue.main.async { [unowned self] in
//            self.showJITWaitScreen()
//        }
//#endif
//    }
//
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ILOG("PVAppDelegate: Application did finish launching")
        initializeAppComponents()
        configureApplication(application)

        return true
    }

    @MainActor
    private func initializeAppComponents() {
        loadRocketSimConnect()
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()
        _initICloud()
        _initUITheme()
        _initThemeListener()
    }

    private func configureApplication(_ application: UIApplication,  launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        // Handle if started from shortcut
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           shortcut.type == "kRecentGameShortcut",
           let md5Value = shortcut.userInfo?["PVGameHash"] as? String,
           let matchedGame = ((try? Realm().object(ofType: PVGame.self, forPrimaryKey: md5Value)) as PVGame??) {
            shortcutItemGame = matchedGame
        }

        Task {
            for await value in Defaults.updates(.disableAutoLock) {
                application.isIdleTimerDisabled =  value
            }
        }
    }

    private func initializeAdditionalComponents() {
        _initSteamControllers()

#if os(iOS) && !targetEnvironment(macCatalyst) && !APP_STORE
        ApplicationMonitor.shared.start()
#endif
    }

    private func scheduleDelayedTasks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.startOptionalWebDavServer()
#if !os(tvOS)
            if self?.isAppStore == true {
                self?._initAppRating()
            }
#endif
        }
    }

    func _initSteamControllers() {
#if !targetEnvironment(macCatalyst) && canImport(SteamController) && !targetEnvironment(simulator)
        // SteamController is built with STEAMCONTROLLER_NO_PRIVATE_API, so we don't call this
        // SteamControllerManager.listenForConnections()
#endif
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

    var currentThemeObservation: Any? // AnyCancellable?
    var userInterfaceStyleObservation: Any?
    var oldPalette: (any UXThemePalette)?

    @MainActor
    func _initThemeListener() {
        if #available(iOS 17.0, tvOS 17.0, *) {
            userInterfaceStyleObservation = withObservationTracking {
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

            currentThemeObservation = ThemeManager.shared.$currentPalette
                .dropFirst() // Skip the initial value
                .sink { [weak self] newPalette in
                    ILOG("Theme changed to: \(newPalette.name)")
                    if newPalette.name != self?.oldPalette?.name {
                        self?.oldPalette = newPalette
                        Task { @MainActor in
                            self?._initUITheme()
                            if self?.isAppStore == true {
                                self?.appRatingSignifigantEvent()
                            }
                        }
                    }
                }
        }
        else {
            userInterfaceStyleObservation = withPerceptionTracking {
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

            currentThemeObservation =   withPerceptionTracking {
                _ = ThemeManager.shared.currentPalette
            } onChange: { [unowned self] in
                let newPaletteName = ThemeManager.shared.currentPalette.name
                ILOG("Theme changed to: \(newPaletteName)")
                if newPaletteName != oldPalette?.name {
                    oldPalette = ThemeManager.shared.currentPalette
                    Task { @MainActor in
                        self._initUITheme()
                        if self.isAppStore == true {
                            self.appRatingSignifigantEvent()
                        }
                    }
                }
            }
        }
    }

    func saveCoreState(_ application: PVApplication) async throws {
        if let core = application.core, core.isOn, let emulator = application.emulator {
            if Defaults[.autoSave], core.supportsSaveStates {
                ILOG("PVAppDelegate: Saving Core State\n")
                try await emulator.autoSaveState()
            }
        }
        if isAppStore {
            appRatingSignifigantEvent()
        }
    }

    func pauseCore(_ application: PVApplication) {
        if let core = application.core, core.isOn && core.isRunning {
            ILOG("PVAppDelegate: Pausing Core\n")
            core.setPauseEmulation(true)
        }
        if isAppStore {
            appRatingSignifigantEvent()
        }
    }

    func stopCore(_ application: PVApplication) {
        if let core = application.core, core.isOn {
            ILOG("PVAppDelegate: Stopping Core\n")
            core.stopEmulation()
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        if let app = application as? PVApplication {
            app.isInBackground = true
            pauseCore(app)
            sleep(1)
            Task {
                try await self.saveCoreState(app)
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if let app = application as? PVApplication {
            app.isInBackground = true
            pauseCore(app)
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {}

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let app = application as? PVApplication {
            app.isInBackground = false
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if let app = application as? PVApplication {
            stopCore(app)
        }
    }

//    private var cancellables = Set<AnyCancellable>()
//    func _initLibraryNotificationHandlers() {
//        NotificationCenter.default.publisher(for: .PVReimportLibrary)
//            .flatMap { _ in
//                Future<Void, Never> { promise in
//                    RomDatabase.refresh()
//                    self.gameLibraryViewController?.checkROMs(false)
//                    promise(.success(()))
//                }
//            }
//            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//            .store(in: &cancellables)
//
//        NotificationCenter.default.publisher(for: .PVRefreshLibrary)
//            .flatMap { _ in
//                Future<Void, Error> { promise in
//                    do {
//                        try RomDatabase.sharedInstance.deleteAllGames()
//                        self.gameLibraryViewController?.checkROMs(false)
//                        promise(.success(()))
//                    } catch {
//                        ELOG("Failed to refresh all objects. \(error.localizedDescription)")
//                        promise(.failure(error))
//                    }
//                }
//            }
//            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//            .store(in: &cancellables)
//
//        NotificationCenter.default.publisher(for: .PVResetLibrary)
//            .flatMap { _ in
//                Future<Void, Error> { promise in
//                    do {
//                        ILOG("PVAppDelegate: Completed ResetLibrary, Re-Importing")
//                        try RomDatabase.sharedInstance.deleteAllData()
//                        Task {
//                            await GameImporter.shared.initSystems()
//                            self.gameLibraryViewController?.checkROMs(false)
//                            promise(.success(()))
//                        }
//                    } catch {
//                        ELOG("Failed to delete all objects. \(error.localizedDescription)")
//                        promise(.failure(error))
//                    }
//                }
//            }
//            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//            .store(in: &cancellables)
//    }
//
  
    @MainActor
    func setupUIKitInterface() -> UIViewController {
        ILOG("PVAppDelegate: Setting up UIKit interface")
        let storyboard = UIStoryboard(name: "Provenance", bundle: PVUIKit.BundleLoader.bundle)
        guard let rootNavigation = storyboard.instantiateInitialViewController() as? UINavigationController else {
            fatalError("No root nav controller")
        }

        self.rootNavigationVC = rootNavigation
        guard let gameLibraryViewController = rootNavigation.viewControllers.first as? PVGameLibraryViewController else {
            fatalError("No gameLibraryViewController")
        }

        gameLibraryViewController.updatesController = appState.libraryUpdatesController
        gameLibraryViewController.gameImporter = appState.gameImporter
        gameLibraryViewController.gameLibrary = appState.gameLibrary

        self.gameLibraryViewController = gameLibraryViewController

        return rootNavigation
    }

    @MainActor
    func setupSwiftUIInterface() -> UIViewController {
        ILOG("PVAppDelegate: Setting up SwiftUI interface")
        let viewModel = PVRootViewModel()
        let rootViewController = PVRootViewController.instantiate(
            updatesController: appState.libraryUpdatesController!,
            gameLibrary: appState.gameLibrary!,
            gameImporter: appState.gameImporter!,
            viewModel: viewModel)
        self.rootNavigationVC = rootViewController
        let sideNavHostedNavigationController = PVRootViewNavigationController(rootViewController: rootViewController)

        let sideNav = setupSideNavigation(mainViewController: sideNavHostedNavigationController,
                                          gameLibrary: appState.gameLibrary!,
                                          viewModel: viewModel,
                                          rootViewController: rootViewController)

        return sideNav
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

}

// You might want to define a protocol for errors that can provide more detailed information
protocol DetailedError: Error {
    var detailedDescription: String { get }
}
