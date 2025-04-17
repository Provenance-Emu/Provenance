//
//  ProvenanceApp.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVEmulatorCore
import PVCoreBridge
import PVThemes
import PVSettings
import PVLogging
import Combine
import Observation
import RxSwift
import PVFeatureFlags
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Defaults


// Main AppState class
@MainActor
public class AppState: ObservableObject {

    public enum AppOpenAction {
        case none
        case openFile(URL)
        case openMD5(String)
        case openGame(PVGame)

        public var requiresEmulatorScene: Bool {
            switch self {
            case .openGame, .openMD5, .openFile:
                return true
            case .none:
                return false
            }
        }
    }

    @ObservedObject
    public static private(set) var shared: AppState = .init()

    /// Computed property to access current bootup state
    public var bootupState: AppBootupState.State {
        get {
            bootupStateManager.currentState
        }
    }

    /// Action to be performed after bootup
    @Published
    public var appOpenAction: AppOpenAction = .none

    /// Hold the emulation core and other info
    @Published
    public var emulationUIState :EmulationUIState = .init()

    /// Hold the emulation core and other info
    @Published
    public var emulationState :EmulationState = .shared

    /// User default for UI preference
    @Published
    public var mainUIMode: MainUIMode = Defaults[.mainUIMode]

    /// Instance of AppBootupState to manage bootup process
    @Published public private(set) var bootupStateManager: AppBootupState = AppBootupState() {
        willSet {
            objectWillChange.send()
        }
        didSet {
            // Force immediate notification
            objectWillChange.send()

            // Schedule delayed notifications to ensure UI updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.objectWillChange.send()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.objectWillChange.send()
            }

            // Post a notification for the bootup state change
            let stateName = bootupStateManager.currentState.localizedDescription
            ILOG("AppState: bootupStateManager changed to state: \(stateName)")

            // Post a notification for the bootup state change
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("BootupStateChanged"),
                    object: nil,
                    userInfo: ["state": stateName]
                )
            }
        }
    }

    /// Optional properties for game-related functionalities
    @Published
    public var gameImporter: GameImporter?

    /// Optional property for the game library
    @Published
    public var gameLibrary: PVGameLibrary<RealmDatabaseDriver>?

    /// Optional property for the library updates controller
    @Published
    public var libraryUpdatesController: PVGameLibraryUpdatesController?

    /// Coordinator for Popover HUD
    public let hudCoordinator = HUDCoordinator()

    /// Coordinator for Scene management
    @Published public var sceneCoordinator: SceneCoordinator?

    /// Whether the app has been initialized
    @Published public var isInitialized = false {
        willSet {
            objectWillChange.send()
        }
        didSet {
            ILOG("AppState: isInitialized changed to \(isInitialized)")
            if isInitialized {
                ILOG("AppState: Bootup sequence completed, UI should update now")
                /// Force a UI update when initialization completes
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
    }

    /// Tracks whether imports should be paused
    @Published private var shouldPauseImports: Bool = true

    /// Cancellable storage for Combine subscriptions
    private var importPauseSubscriptions = Set<AnyCancellable>()

    /// Timer for auto-resuming imports after initial delay
    private var initialImportResumeTimer: Timer?

    /// Initial delay before auto-resuming imports (in seconds)
    private let initialImportResumeDelay: TimeInterval = 10.0

    public var isAppStore: Bool {
        guard let appType = Bundle.main.infoDictionary?["PVAppType"] as? String else { return false }
        return appType.lowercased().contains("appstore")
    }

    public var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    public var sendEventWasSwizzled = false

    private let disposeBag = DisposeBag()

    /// Task for observing changes to mainUIMode
    private var mainUIModeObservationTask: Task<Void, Never>?

    /// Settings factory for creating settings view controllers
    public var settingsFactory: PVSettingsViewControllerFactory?

    /// Import options presenter for showing import UI
    public var importOptionsPresenter: PVImportOptionsPresenter?

    /// Initializer
    private init() {
        ILOG("AppState: Initializing")
        mainUIModeObservationTask = Task { @MainActor in
            for await value in Defaults.updates(.mainUIMode) {
                mainUIMode = value
            }
        }

        ILOG("AppState: Initialization completed")

        // Set up import pause monitoring
        setupImportPauseMonitoring()
    }

    /// Deinitializer
    deinit {
        // Clean up subscriptions
        importPauseSubscriptions.forEach { $0.cancel() }
        importPauseSubscriptions.removeAll()

        // Cancel timer
        initialImportResumeTimer?.invalidate()
        initialImportResumeTimer = nil

        // Cancel task
        mainUIModeObservationTask?.cancel()

        ILOG("AppState: Deinitialized")
    }

    /// Sets up monitoring of conditions that should pause imports
    private func setupImportPauseMonitoring() {
        ILOG("AppState: Setting up import pause monitoring")

        // Monitor emulation state - pause imports when emulation is active
        $emulationUIState
            .map { $0.core?.isOn == true }
            .removeDuplicates()
            .sink { [weak self] isEmulationActive in
                if isEmulationActive {
                    ILOG("AppState: Pausing imports due to active emulation")
                    self?.pauseImports(reason: "Emulation active")
                } else {
                    ILOG("AppState: Emulation inactive, can resume imports")
                    self?.resumeImportsIfNoOtherConditions(previousCondition: "Emulation")
                }
            }
            .store(in: &importPauseSubscriptions)

        // Monitor app background state
        $emulationUIState
            .map { $0.isInBackground }
            .removeDuplicates()
            .sink { [weak self] isInBackground in
                if isInBackground {
                    ILOG("AppState: Pausing imports due to app entering background")
                    self?.pauseImports(reason: "App in background")
                } else {
                    ILOG("AppState: App in foreground, can resume imports")
                    self?.resumeImportsIfNoOtherConditions(previousCondition: "Background")
                }
            }
            .store(in: &importPauseSubscriptions)

        // Schedule timer to auto-resume imports after initial delay
        scheduleInitialImportResume()
    }

    /// Schedules a timer to automatically resume imports after the initial delay
    private func scheduleInitialImportResume() {
        ILOG("AppState: Scheduling initial import resume after \(initialImportResumeDelay) seconds")

        // Cancel any existing timer
        initialImportResumeTimer?.invalidate()

        // Create new timer
        initialImportResumeTimer = Timer.scheduledTimer(withTimeInterval: initialImportResumeDelay, repeats: false) { [weak self] _ in
            ILOG("AppState: Initial import resume timer fired")
            self?.resumeImportsIfNoOtherConditions(previousCondition: "Initial delay")
        }
    }

    /// Pauses imports with a specific reason
    /// - Parameter reason: The reason for pausing imports
    public func pauseImports(reason: String) {
        ILOG("AppState: Pausing imports - Reason: \(reason)")
        shouldPauseImports = true
        gameImporter?.pause()
    }

    /// Resumes imports if there are no other conditions requiring them to be paused
    /// - Parameter previousCondition: The condition that was previously preventing imports
    public func resumeImportsIfNoOtherConditions(previousCondition: String) {
        // Check if there are any other conditions that require imports to be paused
        let emulationActive = emulationUIState.core?.isOn == true
        let isInBackground = emulationUIState.isInBackground
        let isInitialDelayActive = initialImportResumeTimer != nil && initialImportResumeTimer!.isValid

        if !emulationActive && !isInBackground && !isInitialDelayActive {
            ILOG("AppState: Resuming imports - \(previousCondition) condition cleared and no other blocking conditions")
            shouldPauseImports = false
            gameImporter?.resume()
        } else {
            var reasons = [String]()
            if emulationActive { reasons.append("Emulation active") }
            if isInBackground { reasons.append("App in background") }
            if isInitialDelayActive { reasons.append("Initial delay not expired") }

            ILOG("AppState: Not resuming imports - other conditions still active: \(reasons.joined(separator: ", "))")
        }
    }

    /// Manually forces imports to resume regardless of conditions
    public func forceResumeImports() {
        ILOG("AppState: Force resuming imports")
        shouldPauseImports = false
        cancelInitialImportResumeTimer()
        gameImporter?.resume()
    }

    /// Cancels the initial import resume timer
    public func cancelInitialImportResumeTimer() {
        if initialImportResumeTimer?.isValid == true {
            ILOG("AppState: Cancelling initial import resume timer")
            initialImportResumeTimer?.invalidate()
            initialImportResumeTimer = nil
        }
    }

    /// Manually forces imports to pause
    public func forcePauseImports() {
        ILOG("AppState: Force pausing imports")
        shouldPauseImports = true
        gameImporter?.pause()
    }

    /// Method to start the bootup sequence
    public func startBootupSequence() {
        ILOG("AppState: Starting bootup sequence")
        if isInitialized {
            ILOG("AppState: Already initialized, skipping bootup sequence")
            return
        }
        Task {
            do {
                try await withTimeout(seconds: 60) {
                    await self.initializeDatabase()
                }
            } catch {
                ELOG("AppState: Bootup sequence timed out or failed: \(error)")
                bootupStateManager.transition(to: .error(error))
            }
        }
    }

    /// Method to initialize the database
    @MainActor
    private func initializeDatabase() async {
        ILOG("AppState: Starting database initialization")
        bootupStateManager.transition(to: .initializingDatabase)
        do {
            ILOG("AppState: Calling RomDatabase.initDefaultDatabase()")
            try await RomDatabase.initDefaultDatabase()
            ILOG("AppState: Database initialization completed successfully")
            bootupStateManager.transition(to: .databaseInitialized)
            await initializeLibrary()
        } catch {
            ELOG("AppState: Error initializing database: \(error.localizedDescription)")
            bootupStateManager.transition(to: .error(error))
        }
    }

    @MainActor
    private func initializeLibrary() async {
        ILOG("AppState: Initializing library")
        ILOG("AppState: Starting GameImporter.shared.initSystems()")
        await GameImporter.shared.initSystems()
        ILOG("AppState: GameImporter.shared.initSystems() completed")

        // Initialize gameLibrary
        self.gameLibrary = PVGameLibrary<RealmDatabaseDriver>(database: RomDatabase.sharedInstance)
        ILOG("AppState: GameLibrary initialized")

        // Initialize gameImporter
        self.gameImporter = GameImporter.shared
        // Ensure the importer starts in a paused state
        self.gameImporter?.pause()
        ILOG("AppState: GameImporter set and initially paused")

        // Initialize libraryUpdatesController with the gameImporter
        self.libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: self.gameImporter!)
        ILOG("AppState: LibraryUpdatesController initialized")

        ILOG("AppState: Reloading RomDatabase cache")
        await RomDatabase.reloadCache()
        ILOG("AppState: RomDatabase cache reloaded")

        await finalizeBootup()
    }

    @MainActor
    private func finalizeBootup() async {
        ILOG("AppState: Finalizing bootup")

        if libraryUpdatesController == nil {
            ELOG("AppState: LibraryUpdatesController is nil in finalizeBootup")
        }

        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        ILOG("AppState: Starting detached task to add imported games to CSSearchableIndex")
        Task.detached { [weak self] in
            guard let self = self else { return }
            do {
                /// Increased timeout and added progress logging
                try await withTimeout(seconds: 30) {
                    await self.libraryUpdatesController?.addImportedGames(
                        to: CSSearchableIndex.default(),
                        database: RomDatabase.sharedInstance
                    )
                }
                ILOG("AppState: Finished adding imported games to CSSearchableIndex")
            } catch let error as TimeoutError {
                ELOG("AppState: Timeout while adding imported games to CSSearchableIndex: \(error)")
                /// Continue app initialization despite timeout
                ILOG("AppState: Continuing bootup despite Spotlight indexing timeout")
            } catch {
                ELOG("AppState: Error adding imported games to CSSearchableIndex: \(error)")
            }
        }
        #endif

        if PVFeatureFlagsManager.shared.isEnabled(.contentlessCores) {
            ILOG("AppState: RomDatabase Loading dummy cores...")
            try? await RomDatabase.addContentlessCores(overwrite: true)
            ILOG("AppState: RomDatabase dummy cores loaded.")
        } else {
            ILOG("AppState: RomDatabase Clearing dummy cores...")
            try? await RomDatabase.clearContentlessCores()
            ILOG("AppState: RomDatabase dummy cores cleared.")
        }

        ILOG("AppState: Bootup state transitioning to completed...")

        // Log the current state before transition
        ILOG("AppState: Current state before transition: \(bootupStateManager.currentState.localizedDescription)")

        // Transition to completed state
        bootupStateManager.transition(to: .completed)

        // Log the current state after transition
        ILOG("AppState: Current state after transition: \(bootupStateManager.currentState.localizedDescription)")

        // Force UI updates with more logging
        ILOG("AppState: Sending objectWillChange notification")
        objectWillChange.send()

        // Schedule additional UI updates with delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ILOG("AppState: Sending delayed objectWillChange notification (0.1s)")
            self.objectWillChange.send()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ILOG("AppState: Sending delayed objectWillChange notification (0.5s)")
            self.objectWillChange.send()
        }

        // Set isInitialized to trigger additional UI updates
        ILOG("AppState: Setting isInitialized to true")
        isInitialized = true

        ILOG("AppState: Bootup finalized")

        Task { @MainActor in
            try? await self.withTimeout(seconds: 15) {
                await self.setupShortcutsListener()
            }
        }
    }

    func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(seconds: seconds)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }


    @MainActor
    private func setupShortcutsListener() {
        guard let gameLibrary = gameLibrary else {
            ELOG("gameLibrary not yet initialized")
            return
        }
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        // Setup shortcuts for favorites and recent games
        let maxShortcuts = 6 // iOS typically shows 4-6 shortcuts
        Observable.combineLatest(
            gameLibrary.favorites.mapMany { $0.asShortcut(isFavorite: true) }.map { Array($0.prefix(3)) },
            gameLibrary.recents.mapMany { $0.game?.asShortcut(isFavorite: false) }.map { Array($0.prefix(3)) }
        ) { favorites, recents in
            Array((favorites + recents).prefix(maxShortcuts))
        }
        .bind(onNext: { shortcuts in
            UIApplication.shared.shortcutItems = shortcuts
        })
        .disposed(by: disposeBag)
#endif
    }

    /// Handles app state changes (active, inactive, background)
    /// - Parameter scenePhase: The new scene phase
    public func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        ILOG("AppState: Scene phase changed to \(scenePhase)")

        switch scenePhase {
        case .active:
            // App is active/in foreground
            emulationUIState.isInBackground = false
            // Don't automatically resume imports here - let the monitoring system handle it

        case .background:
            // App is in background
            emulationUIState.isInBackground = true
            pauseImports(reason: "App entered background")

        case .inactive:
            // App is inactive but not in background
            // We might want to pause imports here too
            pauseImports(reason: "App became inactive")

        @unknown default:
            WLOG("AppState: Unknown scene phase: \(scenePhase)")
        }
    }
}

struct TimeoutError: Error {
    let seconds: TimeInterval
}

#if os(iOS) || os(macOS)
@available(iOS 9.0, macOS 11.0, macCatalyst 11.0, *)
extension PVGame {
    func asShortcut(isFavorite: Bool) -> UIApplicationShortcutItem {
        guard !isInvalidated else {
            return UIApplicationShortcutItem(type: "kInvalidatedShortcut", localizedTitle: "Invalidated", localizedSubtitle: "Game is no longer valid", icon: .init(type: .play), userInfo: [:])
        }

        let icon: UIApplicationShortcutIcon = isFavorite ? .init(type: .favorite) : .init(type: .play)
        return UIApplicationShortcutItem(type: "kRecentGameShortcut",
                                         localizedTitle: title,
                                         localizedSubtitle: PVEmulatorConfiguration.name(forSystemIdentifier: systemIdentifier),
                                         icon: icon,
                                         userInfo: ["PVGameHash": md5Hash as NSSecureCoding])
    }
}
#endif
