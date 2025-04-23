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
import Intents
import PVUIKit
// Import custom modules for Provenance-specific functionality
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVUIBase
import PVSwiftUI
import PVLogging
import Combine
import Observation
import Perception
import SwiftUI
import Defaults
import PVFeatureFlags

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseCrashlyticsSwift
import FirebaseAnalytics
#endif

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

//#if os(tvOS)
//@Perceptible
//#else
//@Observable
//#endif
public final class PVAppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    /// This is set by the UIApplicationDelegateAdaptor
    public var window: UIWindow? = nil

    static func main() {
        UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, NSStringFromClass(PVApplication.self), NSStringFromClass(PVAppDelegate.self))
    }

    /// This is set by the ContentView
    public var appState: AppState? {
        didSet {
            ILOG("Did set appstate: currently is: \(appState?.bootupStateManager.currentState)")
        }
    }

    // Check if the app is running in App Store mode
    public var isAppStore: Bool {
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
    @MainActor weak var gameLibraryViewController: PVGameLibraryViewController? = nil {
        didSet {
            ILOG("Did set gameLibraryViewController")
            if gameLibraryViewController != nil {
                ILOG("Initializing library notification handlers")
                _initLibraryNotificationHandlers()
            }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    @MainActor
    func _initLibraryNotificationHandlers() {
        ILOG("Initializing library notification handlers")
        cancellables.forEach { $0.cancel() }

        /// Reimport the library
        NotificationCenter.default.publisher(for: .PVReimportLibrary)
            .flatMap { _ in
                Future<Void, Never> { promise in
                    Task.detached {  @MainActor [self] in
                        RomDatabase.refresh()
                        if let _ = self.gameLibraryViewController {
                            self.gameLibraryViewController?.checkROMs(false)
                        } else {
                            if let updates = self.appState?.libraryUpdatesController {
                                await updates.importROMDirectories()
                            }
                        }
                        RomDatabase.sharedInstance.recoverAllSaveStates()
                        if PVFeatureFlagsManager.shared.romPathMigrator {
                            Task {
                                do {
                                    try await self.appState?.gameLibrary?.romMigrator.fixOrphanedFiles()
                                    try await self.appState?.gameLibrary?.romMigrator.fixPartialPaths()

                                } catch {
                                    ELOG("Error: \(error.localizedDescription)")
                                }
                            }
                        }
                        promise(.success(()))
                    }
                }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // Trigger a refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            NotificationCenter.default.post(name: NSNotification.Name.PVReimportLibrary, object: nil)
        }
        
        /// Refresh the library
        NotificationCenter.default.publisher(for: .PVRefreshLibrary)
            .flatMap { _ in
                Future<Void, Error> { promise in
                    Task {
                        do {
                            //                            try RomDatabase.sharedInstance.deleteAllGames()
                            Task { @MainActor in
                                if let _ = self.gameLibraryViewController {
                                    self.gameLibraryViewController?.checkROMs(false)
                                } else {
                                    if let updates = self.appState?.libraryUpdatesController {
                                        await updates.importROMDirectories()
                                    }
                                }
                            }
                            Task.detached {
                                RomDatabase.sharedInstance.recoverAllSaveStates()
                            }
                            if PVFeatureFlagsManager.shared.romPathMigrator {
                                Task.detached {
                                    do {
                                        try await self.appState?.gameLibrary?.romMigrator.fixOrphanedFiles()
                                        try await self.appState?.gameLibrary?.romMigrator.fixPartialPaths()
                                    } catch {
                                        ELOG("Error: \(error.localizedDescription)")
                                    }
                                }
                            }
                            promise(.success(()))
                        } catch {
                            ELOG("Failed to refresh all objects. \(error.localizedDescription)")
                            promise(.failure(error))
                        }
                    }
                }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        /// Reset the library
        NotificationCenter.default.publisher(for: .PVResetLibrary)
            .flatMap { _ in
                Future<Void, Error> { promise in
                    do {
                        ILOG("PVAppDelegate: Completed ResetLibrary, Re-Importing")
                        try RomDatabase.sharedInstance.deleteAllData()
                        Task {
                            await GameImporter.shared.initSystems()
                            if let _ = self.gameLibraryViewController {
                                self.gameLibraryViewController?.checkROMs(false)
                            } else {
                                if let updates = self.appState?.libraryUpdatesController {
                                    await updates.importROMDirectories()
                                }
                            }
                            promise(.success(()))
                        }
                    } catch {
                        ELOG("Failed to delete all objects. \(error.localizedDescription)")
                        promise(.failure(error))
                    }
                }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    // Initialize the UI theme
    @MainActor
    func _initUITheme() {
        ThemeManager.applySavedTheme()
        themeAppUI(withPalette: ThemeManager.shared.currentPalette)
#if os(tvOS)
        UIWindow.appearance().tintColor = .provenanceBlue
#endif
    }

    /// Setup the side navigation
    fileprivate func setupSideNavigation(mainViewController: UIViewController,
                                         gameLibrary: PVGameLibrary<RealmDatabaseDriver>,
                                         viewModel: PVRootViewModel,
                                         rootViewController: PVRootViewController) -> SideNavigationController {
        let sideNav = SideNavigationController(mainViewController: mainViewController)
        let traits = UITraitCollection.current
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad

        /// Calculate width percentage based on device and size class
        let widthPercentage: CGFloat = {
            switch (isIpad, traits.horizontalSizeClass) {
            case (true, .regular):   return 0.3  // iPad regular
            case (true, .compact):   return 0.3  // iPad compact (rare but possible)
            case (true, .unspecified), (true, _): return 0.3  // iPad fallback
            case (false, .compact):  return 0.7  // iPhone portrait
            case (false, .regular):  return 0.4  // iPhone landscape
            case (false, .unspecified), (false, _): return 0.7  // iPhone fallback
            }
        }()

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

        /// Add trait collection observer to update width when orientation changes
#if !os(tvOS)
        NotificationCenter.default.addObserver(forName: UIApplication.didChangeStatusBarOrientationNotification, object: nil, queue: .main) { _ in
            let newWidth: CGFloat = {
                switch (isIpad, UITraitCollection.current.horizontalSizeClass) {
                case (true, .regular):   return 0.3  // iPad regular
                case (true, .compact):   return 0.3  // iPad compact (rare but possible)
                case (true, .unspecified): return 0.3  // iPad fallback
                case (false, .compact):  return 0.3  // iPhone portrait
                case (false, .regular):  return 0.4  // iPhone landscape
                case (false, .unspecified): return 0.3  // iPhone fallback
                case (_, _):
                    return 0.3
                }
            }()
            sideNav.updateSideMenuWidth(percent: newWidth)
        }
#endif
        return sideNav
    }

    /// Setup JIT if needed
    ///
    /// This is called from the ContentView
    // TODO: This is not called from the ContentView
    @MainActor
    private func setupJITIfNeeded() {
#if os(iOS) && !APP_STORE
        if Defaults[.autoJIT] {
            DOLJitManager.shared.attemptToAcquireJitOnStartup()
        }
        DispatchQueue.main.async { [unowned self] in
            self.showJITWaitScreen()
        }
#endif
    }

    private var autoLockTask: Task<Void, Never>?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        ILOG("PVAppDelegate: Application did finish launching")

        initializeAppComponents()
        configureApplication(application)
        return true
    }

    // TODO: Move to ProvenanceApp
    @MainActor
    private func initializeAppComponents() {
        loadRocketSimConnect()
        _initLogging()
        _initAppCenter()
        setDefaultsFromSettingsBundle()
        _initICloud()
        _initUITheme()
        _initThemeListener()
        
        #if os(tvOS)
        // Initialize CloudKit for tvOS
        initializeCloudKit()
        #endif

        // Register intent handler for Siri shortcuts
#if false
        #if os(iOS)
        if #available(iOS 14.0, *) {
            registerIntentHandler()
        }
        #endif
#endif
    }

    public func configureApplication(_ application: UIApplication,  launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        // Handle if started from shortcut
#if !os(tvOS)
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           shortcut.type == "kRecentGameShortcut",
           let md5Value = shortcut.userInfo?["PVGameHash"] as? String,
           let matchedGame = fetchGame(byMD5: md5Value) {
            AppState.shared.appOpenAction = .openGame(matchedGame)
        }
#endif

        // Store weak reference to application
        weak var weakApplication = application

        // Cancel any existing task
        autoLockTask?.cancel()

        // Create new task with weak reference
        autoLockTask = Task { [weak self] in
            guard self != nil else { return }
            for await value in Defaults.updates(.disableAutoLock) {
                guard !Task.isCancelled else { break }
                weakApplication?.isIdleTimerDisabled = value
            }
        }
    }

    deinit {
        // Cancel the task when the delegate is deallocated
        autoLockTask?.cancel()
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
        
        // Initialize CloudKit for all platforms
        initializeCloudKit()
        
        // Keep the legacy iCloud document sync code in place but don't use it by default
        // We can uncomment this if we need to revert back to the old sync method
        /*
        #if !os(tvOS)
        iCloudSync.initICloudDocuments()
        #endif
        */
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
#if !os(tvOS)
                        self.appRatingSignifigantEvent()
#endif
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
#if !os(tvOS)
                                self?.appRatingSignifigantEvent()
#endif
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
#if !os(tvOS)
                        self.appRatingSignifigantEvent()
#endif
                    }
                }
            }

            currentThemeObservation =   withPerceptionTracking {
                _ = ThemeManager.shared.currentPalette
            } onChange: { [unowned self] in
                Task { @MainActor in
                    let newPaletteName = ThemeManager.shared.currentPalette.name
                    ILOG("Theme changed to: \(newPaletteName)")
                    if newPaletteName != oldPalette?.name {
                        oldPalette = ThemeManager.shared.currentPalette
                        Task { @MainActor in
                            self._initUITheme()
                            if self.isAppStore == true {
    #if !os(tvOS)
                                self.appRatingSignifigantEvent()
    #endif
                            }
                        }
                    }
                }
            }
        }
    }

    // TODO: Move to ProvenanceApp
    func saveCoreState() async throws {
        if let core = appState?.emulationUIState.core, core.isOn, let emulator = appState?.emulationUIState.emulator {
            if Defaults[.autoSave], core.supportsSaveStates {
                ILOG("PVAppDelegate: Saving Core State\n")
                try await emulator.autoSaveState()
            }
        }
        if isAppStore {
#if !os(tvOS)
            appRatingSignifigantEvent()
#endif
        }
    }

    // TODO: Move to ProvenanceApp
    func pauseCore() {
        if let core = appState?.emulationUIState.core, core.isOn && core.isRunning {
            ILOG("PVAppDelegate: Pausing Core\n")
            core.setPauseEmulation(true)
        }
        if isAppStore {
#if !os(tvOS)
            appRatingSignifigantEvent()
#endif
        }
    }

    // TODO: Move to ProvenanceApp
    func stopCore() {
        if let core = appState?.emulationUIState.core, core.isOn {
            ILOG("PVAppDelegate: Stopping Core\n")
            core.stopEmulation()
        }
    }


    public func applicationWillResignActive(_ application: UIApplication) {
        let emulationState = appState?.emulationUIState
        emulationState?.isInBackground = true
        pauseCore()
        sleep(1)
        Task {
            try await self.saveCoreState()
        }
    }

    // TODO: Move to ProvenanceApp
    public func applicationDidEnterBackground(_ application: UIApplication) {
        appState?.emulationUIState.isInBackground = true
        pauseCore()
    }

    public func applicationWillEnterForeground(_: UIApplication) {}

    // TODO: Move to ProvenanceApp
    public func applicationDidBecomeActive(_ application: UIApplication) {
        appState?.emulationUIState.isInBackground = false
    }

    // TODO: Move to ProvenanceApp
    public func applicationWillTerminate(_ application: UIApplication) {
        stopCore()
    }

    @MainActor
    func setupUIKitInterface() -> UIViewController {
        guard let appState = appState else {
            ELOG("`appState` was nil. Never set?")
            return .init()
        }

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
        ILOG("PVAppDelegate: Starting SwiftUI interface setup")
        guard let appState = appState else {
            ELOG("PVAppDelegate: `appState` was nil. Never set?")
            return .init()
        }

        ILOG("PVAppDelegate: AppState is set")
        let viewModel = PVRootViewModel()

        ILOG("PVAppDelegate: Checking required components")
        if appState.libraryUpdatesController == nil {
            ELOG("PVAppDelegate: libraryUpdatesController is nil")
        }
        if appState.gameLibrary == nil {
            ELOG("PVAppDelegate: gameLibrary is nil")
        }
        if appState.gameImporter == nil {
            ELOG("PVAppDelegate: gameImporter is nil")
        }

        guard let libraryUpdatesController = appState.libraryUpdatesController,
              let gameLibrary = appState.gameLibrary,
              let gameImporter = appState.gameImporter else {
            ELOG("PVAppDelegate: Required components in appState are nil")
            return .init()
        }

        // Refresh the library
        //        Task.detached(priority: .background) {
        //            await libraryUpdatesController.updateConflicts()
        //            await libraryUpdatesController.importROMDirectories()
        //        }

        ILOG("PVAppDelegate: All required components are available")
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

        _initLibraryNotificationHandlers()
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
