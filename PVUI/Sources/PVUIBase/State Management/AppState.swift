//
//  ProvenanceApp.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

// Import necessary modules
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
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Defaults

// Main AppState class
@MainActor
public class AppState: ObservableObject {

    @ObservedObject
    public static private(set) var shared: AppState = .init()

    /// Computed property to access current bootup state
    public var bootupState: AppBootupState.State {
        bootupStateManager.currentState
    }

    /// Hold the emulation core and other info
    @Published
    public var emulationUIState :EmulationUIState = .init()
    
    /// Hold the emulation core and other info
    @Published
    public var emulationState :EmulationState = .shared

    /// User default for UI preference
    @Published
    public var useUIKit: Bool = Defaults[.useUIKit]

    /// Instance of AppBootupState to manage bootup process
    public let bootupStateManager = AppBootupState()

    /// Optional properties for game-related functionalities
    @Published
    public var gameImporter: GameImporter?
    /// Optional property for the game library
    public var gameLibrary: PVGameLibrary<RealmDatabaseDriver>?
    /// Optional property for the library updates controller
    @Published
    public var libraryUpdatesController: PVGameLibraryUpdatesController?

    public let hudCoordinator = HUDCoordinator()

    /// Whether the app has been initialized
    @Published
    public var isInitialized = false {
        didSet {
            ILOG("AppState: isInitialized changed to \(isInitialized)")
            if isInitialized {
                ILOG("AppState: Bootup sequence completed, UI should update now")
            }
        }
    }

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

    /// Task for observing changes to useUIKit
    private var useUIKitObservationTask: Task<Void, Never>?

    /// Settings factory for creating settings view controllers
    public var settingsFactory: PVSettingsViewControllerFactory?

    /// Import options presenter for showing import UI
    public var importOptionsPresenter: PVImportOptionsPresenter?

    /// Initializer
    private init() {
        ILOG("AppState: Initializing")
        useUIKitObservationTask = Task { @MainActor in
            for await value in Defaults.updates(.useUIKit) {
                useUIKit = value
            }
        }

        ILOG("AppState: Initialization completed")
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
                try await withTimeout(seconds: 30) {
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
        ILOG("AppState: Reloading RomDatabase cache")
        await RomDatabase.reloadCache()
        ILOG("AppState: RomDatabase cache reloaded")

        // Initialize gameLibrary
        self.gameLibrary = PVGameLibrary<RealmDatabaseDriver>(database: RomDatabase.sharedInstance)
        ILOG("AppState: GameLibrary initialized")

        // Initialize gameImporter
        self.gameImporter = GameImporter.shared
        ILOG("AppState: GameImporter set")

        // Initialize libraryUpdatesController with the gameImporter
        self.libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: self.gameImporter!)
        ILOG("AppState: LibraryUpdatesController initialized")

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
                try await withTimeout(seconds: 120) { // Increased from 30 to 120 seconds
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

        bootupStateManager.transition(to: .completed)
        ILOG("AppState: Bootup state transitioned to completed")
        ILOG("AppState: Bootup finalized")

        Task.detached {
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
