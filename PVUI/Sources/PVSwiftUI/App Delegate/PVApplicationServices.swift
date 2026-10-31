//  PVApplicationServices.swift
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

// Import necessary modules for core functionality
import RealmSwift
import UIKit
// Import custom modules for Provenance-specific functionality
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVUIBase
import PVShaders
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

#if canImport(FreemiumKit)
import FreemiumKit
#endif

/// Process-wide services. SwiftUI owns the window hierarchy and scene lifecycle.
@MainActor
public final class PVApplicationServices: NSObject, ObservableObject {
    public static let shared = PVApplicationServices()
    private var hasStarted = false
    private var previousScenePhase: ScenePhase?

    /// Starts services once, before SwiftUI constructs the scene content.
    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        appState = AppState.shared
        launchServices()
    }

    /// Called from the aggregate SwiftUI scene phase, once for all windows.
    public func handleScenePhaseChange(_ phase: ScenePhase) {
        defer { previousScenePhase = phase }
        if ApplicationSceneTransition.shouldSave(from: previousScenePhase, to: phase) {
            willResignActive()
        }
        switch phase {
        case .active:
            refreshEntitlements()
            didBecomeActive()
        case .inactive:
            break
        case .background:
            didEnterBackground()
        @unknown default:
            break
        }
    }
    private let pauseMenuSettingsDelegate = MockPVMenuDelegate()

    /// Shared app state used by background services
    public private(set) var appState: AppState? {
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

    private var cancellables = Set<AnyCancellable>()
    @MainActor private var libraryNotificationHandlersInstalled = false

    /// Registers the Scan ROMs / Update Metadata / Reset Library observers if no UI
    /// mode has done so yet. Only `setupSwiftUIInterface` used to register them, so in
    /// the TV Media and single-page UIs those notifications were posted with nobody
    /// listening (#3672).
    @MainActor
    public func installLibraryNotificationHandlersIfNeeded() {
        guard !libraryNotificationHandlersInstalled else { return }
        _initLibraryNotificationHandlers()
    }

    @MainActor
    func _initLibraryNotificationHandlers() {
        ILOG("Initializing library notification handlers")
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        libraryNotificationHandlersInstalled = true

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
                        let (updatesController, romMigrator) = await MainActor.run {
                            (
                                self.appState?.libraryUpdatesController,
                                self.appState?.gameLibrary?.romMigrator
                            )
                        }
                        // Synchronous — no actor hop needed (PVFeatureFlags is thread-safe)
                        let migratorEnabled = PVFeatureFlags.shared.isEnabled(.romPathMigrator)

                        // Heavy work must never run on the main actor during boot.
                        RomDatabase.refresh()

                        if let updatesController {
                            await updatesController.importROMDirectories()
                        }

                        if LibraryLocation.current == .pickedFolder {
                            // Review Focus 3: a ROM another app removed shows as missing, never as gone.
                            _ = await GameFileStatusService.shared.refreshAllStatuses()
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
                            promise(.failure(NSError(domain: "PVApplicationServices", code: 0, userInfo: [NSLocalizedDescriptionKey: "Application services deallocated"])))
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
                                if let updates = self.appState?.libraryUpdatesController {
                                     await updates.importROMDirectories()
                                     DLOG("importROMDirectories called.")
                                } else {
                                     WLOG("libraryUpdatesController not available for ROM check.")
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
                        ILOG("PVApplicationServices: Completed ResetLibrary, Re-Importing")
                        try RomDatabase.sharedInstance.deleteAllData()
                        Task {
                            await GameImporter.shared.initSystems()
                            if let updates = self.appState?.libraryUpdatesController {
                                await updates.importROMDirectories()
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

        #if !os(tvOS)
        // Foregrounding rescans a picked folder. The scene delegate owns the lifecycle, so this listens for the notification.
        LibraryRescanRequester.shared.startObservingForeground()
        // An iCloud Drive picked folder: download placeholders other apps add, and rescan when they arrive. Idempotent.
        PickedFolderCloudWatcher.shared.startIfNeeded {
            LibraryRescanRequester.shared.requestRescan(reason: "iCloud metadata update")
        }
        #endif
    }
    // Initialize the UI theme
    @MainActor
    func _initUITheme() {
        ThemeManager.applySavedTheme()
#if os(tvOS)
        UIWindow.appearance().tintColor = .provenanceBlue
#endif
    }

    private var autoLockTask: Task<Void, Never>?

    private func launchServices() {
        // Establish the launch-timeline origin before any other work, so every
        // `LAUNCH:` log line's `t+` column is measured from the same point.
        PVLaunchProfiler.markProcessStart()
        ILOG("PVApplicationServices: Application did finish launching")

        // Restore critical user preferences from iCloud KVS (survives reinstalls)
        PVLaunchProfiler.measureSync("launch.iCloudSettingsSync") {
            // Filter selections, parameters and favorites sync as merged blobs.
            ShaderLibraryStore.shared.register()
            iCloudSettingsSync.setup()
        }

        // Cross-app entitlements over the shared same-team keychain. Honor an
        // active iFly Pro first (it may unlock Plus), then mirror our own Plus
        // out for iFly (now + a delayed pass for StoreKit's async load).
        Task { @MainActor in
            CrossAppEntitlementReader.applySiblingGrantIfNeeded()
            CrossAppEntitlementPublisher.publishPlusStateAtLaunch()
        }

        PVLaunchProfiler.measureSync("launch.setDefaultRealmConfig") {
            RealmConfiguration.setDefaultRealmConfig()
        }

        // Capture the configured Realm and install file-event handlers before server startup.
        PVWebFileEventObserver.shared.start()

        // Register MetricKit subscriber to capture hang / crash diagnostics passively
        #if !os(tvOS)
        if #available(iOS 14.0, *) {
            registerMetricKitSubscriber()
        }
        #endif

        // Report app-extension invocations that were killed since we last ran.
        // Deliberately NOT gated on MetricKit, which is unavailable on tvOS.
        reportPendingExtensionTerminations()

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
        observeIdleTimerSetting()

        // Register BGTaskScheduler handlers at app launch
        // This must be after DB registration
        registerBGTaskSchedulerHandlers()

    }

    /// Register BGTaskScheduler handlers at the earliest possible point in the app lifecycle
    private func registerBGTaskSchedulerHandlers() {
        DLOG("Registering BGTaskScheduler handlers at app launch")

        // Register background refresh task for CloudKit sync
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.provenance-emu.provenance.cloudkit-sync", using: nil) { [weak self] task in
            guard let self = self else {
                ELOG("Application services deallocated when handling background task")
                task.setTaskCompleted(success: false)
                return
            }

            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                self.handleCloudKitSyncTask(processingTask)
            }
        }

        DLOG("BGTaskScheduler handlers registered successfully")
    }

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
            .with(SkinIndexPrewarmBootstrapTask())
            .with(WebServerBootstrapTask())

        await PVLaunchProfiler.measure("launch.bootstrapOrchestrator") {
            await orchestrator.run()
        }

        PauseMenuViewRegistry.registerAppSettingsView { dismissAction in
            let conflictsController = AppState.shared.libraryUpdatesController
                ?? PVGameLibraryUpdatesController(gameImporter: GameImporter.shared)
            /// The registry hands this view to arbitrary presenters, so it must carry its
            /// own environment rather than rely on inheriting one.
            ///
            /// It previously injected nothing and only survived because the pause menu
            /// presents it with `.sheet` from inside `PVGameMenuOverlay`'s hierarchy,
            /// which wraps its content in `.environmentObject(FreemiumKit.shared)` —
            /// SwiftUI sheets inherit the presenter's environment. Any UIKit presenter
            /// (a `UIHostingController`, e.g. the ⌘, menu-bar action) gets a fresh,
            /// empty environment, so `PaidFeatureView` hit its `EnvironmentObject`
            /// fatalError as soon as settings appeared over a running game.
            ///
            /// Matches the environment supplied by the library's settings sheet.
            return AnyView(
                NavigationStack {
                    PVSettingsView(
                        conflictsController: conflictsController,
                        menuDelegate: self.pauseMenuSettingsDelegate,
                        dismissAction: { dismissAction?() }
                    )
                }
                .environmentObject(conflictsController)
#if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
#endif
                .environmentObject(SettingsNavigator.shared)
            )
        }

        PauseMenuViewRegistry.registerControllerRemapView { controller, dismissAction in
            AnyView(InGameControllerRemapView(controller: controller, dismissAction: dismissAction))
        }

        _initThemeListener()

        // Once per launch, a delayed low-priority pass replaces dead artwork URLs and re-downloads
        // cached "artwork" files that are not images, so existing libraries self-heal.
        Task { await ArtworkSearchQueue.shared.scheduleLaunchArtworkRepair() }

        // Legacy PVOpenIntent donation removed — Siri shortcuts are now handled
        // by LaunchGameIntent in PVAppIntents via processPendingAppIntents().

        // Register the ROM File Provider domain so Files.app shows Provenance as a location.
        // Supported on iOS, Mac Catalyst, and visionOS (FileProvider is unavailable on tvOS).
        registerFileProviderDomain()
    }

    private func observeIdleTimerSetting() {
        autoLockTask?.cancel()
        autoLockTask = Task { @MainActor in
            // Keep UIKit access out of the synchronous SwiftUI App initializer.
            for await value in Defaults.updates(.disableAutoLock) {
                guard !Task.isCancelled else { break }
                UIApplication.shared.isIdleTimerDisabled = value
            }
        }
    }

    deinit {
        // Cancel the task when the delegate is deallocated
        autoLockTask?.cancel()
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

    func saveCoreState() async throws {
        if let core = appState?.emulationUIState.core, core.isOn, let emulator = appState?.emulationUIState.emulator {
            if Defaults[.autoSave], core.supportsSaveStates {
                ILOG("PVApplicationServices: Saving Core State\n")
                try await emulator.autoSaveState()
            }
        }
        if isAppStore {
#if !os(tvOS)
            appRatingSignifigantEvent()
#endif
        }
    }

    func pauseCore() {
        if let core = appState?.emulationUIState.core, core.isOn && core.isRunning {
            ILOG("PVApplicationServices: Pausing Core\n")
            core.setPauseEmulation(true)
        }
        if isAppStore {
#if !os(tvOS)
            appRatingSignifigantEvent()
#endif
        }
    }

    private func willResignActive() {
        let application = UIApplication.shared
        let emulationState = appState?.emulationUIState
        emulationState?.isInBackground = true
        pauseCore()
        guard Defaults[.autoSave], let core = emulationState?.core, core.isOn, core.supportsSaveStates else { return }
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

    private func didEnterBackground() {
        appState?.emulationUIState.isInBackground = true
        pauseCore()
    }

    private func refreshEntitlements() {
        // Re-check both directions (a purchase/restore may have happened in
        // either app since launch; FreemiumKit exposes no purchase hook to ride).
        Task { @MainActor in
            CrossAppEntitlementReader.applySiblingGrantIfNeeded()
            CrossAppEntitlementPublisher.publishPlusState()
        }
    }

    private func didBecomeActive() {
        appState?.emulationUIState.isInBackground = false
    }

    /// Flushes the running core when the OS delivers a process-termination callback.
    public func prepareForTermination() {
        if let core = appState?.emulationUIState.core, core.isOn {
            core.stopEmulation()
        }
        #if !os(tvOS)
        unregisterMetricKitSubscriber()
        #endif
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
}

/// Saves once when leaving active, including transitions that skip the inactive phase.
enum ApplicationSceneTransition {
    static func shouldSave(from previous: ScenePhase?, to current: ScenePhase) -> Bool {
        previous == .active && current != .active
    }
}
