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
import PVUIBase
import PVUIKit
import PVSwiftUI
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
class AppState: ObservableObject {
    /// Computed property to access current bootup state
    var bootupState: AppBootupState.State {
        bootupStateManager.currentState
    }

    /// User default for UI preference
    @Published
    var useUIKit: Bool = Defaults[.useUIKit]

    /// Instance of AppBootupState to manage bootup process
    let bootupStateManager = AppBootupState()

    /// Optional properties for game-related functionalities
    @Published var gameImporter: GameImporter?
    /// Optional property for the game library
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>?
    /// Optional property for the library updates controller
    @Published var libraryUpdatesController: PVGameLibraryUpdatesController?

    /// Whether the app has been initialized
    @Published var isInitialized = false {
        didSet {
            ILOG("AppState: isInitialized changed to \(isInitialized)")
            if isInitialized {
                ILOG("AppState: Bootup sequence completed, UI should update now")
            }
        }
    }

    private let disposeBag = DisposeBag()


    /// Task for observing changes to useUIKit
    private var useUIKitObservationTask: Task<Void, Never>?

    /// Initializer
    init() {
        ILOG("AppState: Initializing")
        useUIKitObservationTask = Task { @MainActor in
            for await value in Defaults.updates(.useUIKit) {
                useUIKit = value
            }
        }
        self.libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: GameImporter.shared)
        ILOG("AppState: Initialization completed")
    }

    /// Method to start the bootup sequence
    func startBootupSequence() {
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
    private func initializeDatabase() {
        ILOG("AppState: Starting database initialization")
        bootupStateManager.transition(to: .initializingDatabase)
        Task { @MainActor in
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
    }

    @MainActor
    private func initializeLibrary() async {
        ILOG("AppState: Initializing library")
        ILOG("AppState: Starting GameImporter.shared.initSystems()")
        await GameImporter.shared.initSystems()
        ILOG("AppState: GameImporter.shared.initSystems() completed")
        ILOG("AppState: Reloading RomDatabase cache")
        RomDatabase.reloadCache()
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
                try await withTimeout(seconds: 30) {
                    await self.libraryUpdatesController?.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance)
                }
                ILOG("AppState: Finished adding imported games to CSSearchableIndex")
            } catch let error as TimeoutError {
                ELOG("AppState: Timeout while adding imported games to CSSearchableIndex: \(error)")
            } catch {
                ELOG("AppState: Error adding imported games to CSSearchableIndex: \(error)")
            }
        }
        #endif

        bootupStateManager.transition(to: .completed)
        ILOG("AppState: Bootup state transitioned to completed")
        ILOG("AppState: Bootup finalized")

        Task {
            try? await withTimeout(seconds: 5) {
                self.setupShortcutsListener()
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
    func setupShortcutsListener() {
        guard let gameLibrary = gameLibrary else {
            ELOG("gameLibrary not yet initialized")
            return
        }
#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        // Setup shortcuts for favorites and recent games
        Observable.combineLatest(
            gameLibrary.favorites.mapMany { $0.asShortcut(isFavorite: true) },
            gameLibrary.recents.mapMany { $0.game?.asShortcut(isFavorite: false) }
        ) { $0 + $1 }
            .bind(onNext: { shortcuts in
                UIApplication.shared.shortcutItems = shortcuts
            })
            .disposed(by: disposeBag)
#endif
    }

    @MainActor
    func initializeComponents() async {
        ILOG("AppState: Starting component initialization")
        // Initialize gameLibrary, gameImporter, libraryUpdatesController here
        // Add logging after each initialization
        ILOG("AppState: Component initialization completed")
    }
}

struct TimeoutError: Error {
    let seconds: TimeInterval
}
