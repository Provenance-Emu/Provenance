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
import PVLibrary
import PVLogging
import Combine
import Observation
import SwiftUI
import Defaults
import PVFeatureFlags
import BackgroundTasks
import PVWebServer

// Conditionally import PVJIT and JITManager if available
#if canImport(PVJIT)
import PVJIT
import JITManager
#endif

// Conditionally import `PVAppIntents` if available
#if canImport(PVAppIntents)
import PVAppIntents
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

//@Observable
public final class PVAppDelegate: UIResponder, UIApplicationDelegate, ObservableObject {
    /// This is set by the UIApplicationDelegateAdaptor
    public var window: UIWindow? = nil
    private let pauseMenuSettingsDelegate = MockPVMenuDelegate()

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
        guard Bundle.main.bundleIdentifier?.hasPrefix("org.provenance-emu.provenance") == true else {
            ILOG("Bundle id \(Bundle.main.bundleIdentifier ?? "null") is NOT official. Disabling Provenance Plus checks.")
            return false
        }
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else {
            ILOG("appType \( Bundle.main.infoDictionary?["PVAppType"] ?? "null") is NOT official. Disabling Provenance Plus checks.")
            return false
        }
        let isAppStore = appType.lowercased().contains("appstore")
        if isAppStore {
            ILOG("isAppStore true.")
        } else {
            ILOG("isAppStore false.")
        }
        return isAppStore
    }

    /// JIT-related state shared by non-App Store iOS and tvOS builds.
#if (os(iOS) || os(tvOS)) && !APP_STORE && canImport(PVJIT)
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
                    Task.detached(priority: .utility) { [weak self] in
                        guard let self else {
                            promise(.success(()))
                            return
                        }

                        // Safely capture @MainActor state before doing background work.
                        let (updatesController, romMigrator, hasLibraryVC) = await MainActor.run {
                            (
                                self.appState?.libraryUpdatesController,
                                self.appState?.gameLibrary?.romMigrator,
                                self.gameLibraryViewController != nil
                            )
                        }
                        // Synchronous — no actor hop needed (PVFeatureFlags is thread-safe)
                        let migratorEnabled = PVFeatureFlags.shared.isEnabled(.romPathMigrator)

                        // Heavy work must never run on the main actor during boot.
                        RomDatabase.refresh()

                        if let updatesController {
                            await updatesController.importROMDirectories()
                        }

                        RomDatabase.sharedInstance.recoverAllSaveStates()

                        if migratorEnabled, let migrator = romMigrator {
                            do {
                                try await migrator.fixOrphanedFiles()
                                try await migrator.fixPartialPaths()
                            } catch {
                                ELOG("Error: \(error.localizedDescription)")
                            }
                        }

                        // UI-affecting work should happen on main.
                        if hasLibraryVC {
                            await MainActor.run { [weak self] in
                                self?.gameLibraryViewController?.checkROMs(false)
                            }
                        }

                        promise(.success(()))
                    }
                }
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // NOTE:
        // We intentionally do NOT auto-post `.PVReimportLibrary` at boot.
        // A full library reimport is extremely expensive and will make the UI feel hung on cold launches.
        // The user can trigger it manually from Settings / menu when needed.

        /// Refresh the library
        NotificationCenter.default.publisher(for: .PVRefreshLibrary)
            .receive(on: DispatchQueue.global(qos: .userInitiated)) // Move off main thread for potentially long refresh
            .flatMap { _ -> Future<Void, Error> in // Explicit return type
                Future<Void, Error> { promise in
                    Task.detached(priority: .userInitiated) { [weak self] in // Detached task for the whole refresh operation
                        guard let self = self else {
                            promise(.failure(NSError(domain: "PVAppDelegate", code: 0, userInfo: [NSLocalizedDescriptionKey: "AppDelegate deallocated"])))
                            return
                        }

                        ILOG("Starting library refresh process...")
                        var checkRomTask: Task<Void, Never>?
                        var recoverSavesTask: Task<Void, Never>?
                        var fixFilesTask: Task<Void, Error>? // Can throw

                        do {
                            // Launch tasks concurrently using Task handles
                            checkRomTask = Task { @MainActor [weak self] in // Needs main actor potentially
                                guard let self = self else { return }
                                if let libraryVC = self.gameLibraryViewController {
                                     libraryVC.checkROMs(false) // Assuming this triggers necessary background work
                                     DLOG("checkROMs called.")
                                } else if let updates = self.appState?.libraryUpdatesController {
                                     await updates.importROMDirectories()
                                     DLOG("importROMDirectories called.")
                                } else {
                                     WLOG("Neither gameLibraryViewController nor libraryUpdatesController available for ROM check.")
                                }
                            }

                            recoverSavesTask = Task.detached { // Can run detached
                                DLOG("Starting save state recovery...")
                                RomDatabase.sharedInstance.recoverAllSaveStates()
                                DLOG("Finished save state recovery.")
                            }

                            if PVFeatureFlags.shared.isEnabled(.romPathMigrator) {
                                fixFilesTask = Task.detached { @MainActor in
                                    DLOG("Starting ROM path migration fixes...")
                                    try await AppState.shared.gameLibrary?.romMigrator.fixOrphanedFiles()
                                    try await AppState.shared.gameLibrary?.romMigrator.fixPartialPaths()
                                    DLOG("Finished ROM path migration fixes.")
                                }
                            }

                            // Await all necessary tasks
                            await checkRomTask?.value // Wait for check/import to finish
                            await recoverSavesTask?.value // Wait for save recovery

                            if let fixTask = fixFilesTask {
                                try await fixTask.value // Wait for migration and propagate error if any
                            }

                            ILOG("Library refresh process completed successfully.")
                            // Post completion notification *before* resolving the promise
                            NotificationCenter.default.post(name: .PVRefreshLibraryFinished, object: nil)
                            promise(.success(())) // Signal Future success AFTER all tasks are done

                        } catch {
                            ELOG("Library refresh process failed: \(error.localizedDescription)")
                            promise(.failure(error)) // Signal Future failure
                        }
                     }
                 }
             }
            .receive(on: DispatchQueue.main) // Switch back to main thread for sink
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    ILOG("Library refresh Future completed. Posting PVRefreshLibraryFinished notification.")
                    NotificationCenter.default.post(name: .PVRefreshLibraryFinished, object: nil)
                case .failure(let error):
                    ELOG("Library refresh Future failed: \(error.localizedDescription). Not posting finished notification.")
                    // Optionally post an error notification here if needed
                }
            }, receiveValue: { _ in /* No value emitted by Future<Void, Error> */ })
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

    /// Setup JIT wait screen if needed — call after the root view controller is established.
    ///
    /// JIT acquisition (attemptToAcquireJitOnStartup) is now called directly from
    /// application(_:didFinishLaunchingWithOptions:) so it runs as early as possible.
    /// This helper only handles the wait-screen UI which requires a root view controller.
    @MainActor
    private func setupJITIfNeeded() {
        // JIT acquisition (attemptToAcquireJitOnStartup) is called earlier in
        // application(_:didFinishLaunchingWithOptions:) so it runs before any core is loaded.
        // This method only handles the wait-screen UI, which must be called after the
        // root view controller is established (it presents a modal view controller).
#if (os(iOS) || os(tvOS)) && !APP_STORE && canImport(PVJIT)
        // The wait screen suggests third-party JIT tools (AltStore, StikDebug, etc.)
        // which could trigger App Store review rejections — only show in non-App Store builds.
        DispatchQueue.main.async { [weak self] in
            self?.showJITWaitScreen()
        }
#endif
    }

    private var autoLockTask: Task<Void, Never>?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ILOG("PVAppDelegate: Application did finish launching")

        // Restore critical user preferences from iCloud KVS (survives reinstalls)
        iCloudSettingsSync.setup()

        RealmConfiguration.setDefaultRealmConfig()

        // Register MetricKit subscriber to capture hang / crash diagnostics passively
        #if !os(tvOS)
        if #available(iOS 14.0, *) {
            registerMetricKitSubscriber()
        }
        #endif

        // Attempt JIT acquisition as early as possible so that cores queried later
        // see the correct `DOLJitManager.acquired` state.  This is safe in App Store
        // builds — it only reads CS_DEBUGGED / entitlements; it never shows UI or
        // suggests sideloading.  The JIT wait-screen (which references sideloading
        // tools and requires a root view controller) is handled in setupJITIfNeeded()
        // which must be called after the root VC is established.
        #if (os(iOS) || os(tvOS)) && canImport(PVJIT)
        if Defaults[.autoJIT] {
            DOLJitManager.shared.attemptToAcquireJitOnStartup()
        }
        #endif

        Task { @MainActor in
            await initializeAppComponents()
        }
        configureApplication(application, launchOptions: launchOptions)

        // Register BGTaskScheduler handlers at app launch
        // This must be after DB registration
        registerBGTaskSchedulerHandlers()

        return true
    }

    /// Register `PVSceneDelegate` as the scene delegate so iOS routes
    /// Home Screen Quick Action taps to it rather than SwiftUI's private no-op class.
    #if os(iOS) || targetEnvironment(macCatalyst)
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = PVSceneDelegate.self
        return config
    }
    #endif

    /// Register BGTaskScheduler handlers at the earliest possible point in the app lifecycle
    private func registerBGTaskSchedulerHandlers() {
        DLOG("Registering BGTaskScheduler handlers at app launch")

        // Register background refresh task for CloudKit sync
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.provenance-emu.provenance.cloudkit-sync", using: nil) { [weak self] task in
            guard let self = self else {
                ELOG("AppDelegate deallocated when handling background task")
                task.setTaskCompleted(success: false)
                return
            }

            self.handleCloudKitSyncTask(task as! BGProcessingTask)
        }

        DLOG("BGTaskScheduler handlers registered successfully")
    }

    // TODO: Move to ProvenanceApp
    @MainActor
    private func initializeAppComponents() async {
        loadRocketSimConnect()

        let orchestrator = BootstrapOrchestrator()
            .with(LoggingBootstrapTask())
            .with(SentryBootstrapTask(isAppStore: isAppStore))
            .with(AppCenterBootstrapTask(isAppStore: isAppStore))
            .with(SettingsBundleBootstrapTask())
            .with(ThemeBootstrapTask())
            .with(iCloudBootstrapTask())
            .with(WebServerBootstrapTask(delegate: self))

        await orchestrator.run()

        // Apply any pending RetroArch config migrations (partial key updates)
        await RetroArchConfigMigrator.applyPendingMigrations()

        // Register the RetroArch quick-settings view so the pause menu can show it
        // (PVUIBase can't import PVSwiftUI directly, so we use a static registry)
        PauseMenuViewRegistry.registerRetroArchSettingsView {
            AnyView(NavigationStack { RetroArchQuickSettingsView() })
        }
        PauseMenuViewRegistry.registerAppSettingsView { dismissAction in
            let conflictsController = AppState.shared.libraryUpdatesController
                ?? PVGameLibraryUpdatesController(gameImporter: GameImporter.shared)
            return AnyView(
                NavigationStack {
                    PVSettingsView(
                        conflictsController: conflictsController,
                        menuDelegate: self.pauseMenuSettingsDelegate,
                        dismissAction: { dismissAction?() }
                    )
                }
            )
        }

        _initThemeListener()

        // Legacy PVOpenIntent donation removed — Siri shortcuts are now handled
        // by LaunchGameIntent in PVAppIntents via processPendingAppIntents().

        // Register the ROM File Provider domain so Files.app shows Provenance as a location.
        // Supported on iOS, Mac Catalyst, and visionOS (FileProvider is unavailable on tvOS).
        registerFileProviderDomain()
    }

    public func configureApplication(_ application: UIApplication,  launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        // Note: Shortcuts are handled via scene delegate methods in SwiftUI apps
        // This is kept for backwards compatibility but shortcuts should come through scene delegate
        DLOG("configureApplication launchOptions: \(launchOptions?.debugDescription ?? "nil")")

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

    var currentThemeObservation: Any? // AnyCancellable?
    var userInterfaceStyleObservation: Any?
    var oldPalette: (any UXThemePalette)?

    @MainActor
    func _initThemeListener() {
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
            .dropFirst()
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
        // Hold a background-task assertion so the async save chain (serialize -> write ->
        // Realm register) can finish before iOS suspends the app; without it the autosave
        // can be lost. Mirrors the CloudKit pattern. @MainActor keeps bgTaskID race-free.
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        bgTaskID = application.beginBackgroundTask(withName: "PVSaveCoreState") {
            application.endBackgroundTask(bgTaskID)
            bgTaskID = .invalid
        }
        Task { @MainActor in
            do {
                try await self.saveCoreState()
            } catch {
                ELOG("Autosave on resign-active failed: \(error.localizedDescription)")
            }
            if bgTaskID != .invalid {
                application.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
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
#if !os(tvOS)
        if #available(iOS 14.0, tvOS 14.0, *) {
            unregisterMetricKitSubscriber()
        }
#endif
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

