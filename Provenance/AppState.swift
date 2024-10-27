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
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Defaults

// Main AppState class
@MainActor
class AppState: ObservableObject {
    /// Computed property to access current bootup state
    var bootupState: AppBootupState.State { bootupStateManager.currentState }

    /// User default for UI preference
    @Published
    var useUIKit: Bool = Defaults[.useUIKit]

    /// Instance of AppBootupState to manage bootup process
    let bootupStateManager = AppBootupState()

    /// Optional properties for game-related functionalities
    var gameImporter: GameImporter?
    /// Optional property for the game library
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>?
    /// Optional property for the library updates controller
    var libraryUpdatesController: PVGameLibraryUpdatesController?

    /// Whether the app has been initialized
    @Published var isInitialized = false {
        didSet {
            ILOG("AppState: isInitialized changed to \(isInitialized)")
        }
    }

    /// Task for observing changes to useUIKit
    private var useUIKitObservationTask: Task<Void, Never>?

    /// Initializer
    init() {
        ILOG("AppState initialized")
        useUIKitObservationTask = Task { @MainActor in
            for await value in Defaults.updates(.useUIKit) {
                useUIKit = value
            }
        }
    }

    /// Method to start the bootup sequence
    func startBootupSequence() {
        ILOG("AppState: Starting bootup sequence")
        if isInitialized {
            ILOG("AppState: Already initialized, skipping bootup sequence")
            return
        }
        initializeDatabase()
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
        bootupStateManager.transition(to: .initializingLibrary)
        ILOG("AppState: Starting GameImporter.shared.initSystems()")
        await GameImporter.shared.initSystems()
        ILOG("AppState: GameImporter.shared.initSystems() completed")
        ILOG("AppState: Reloading RomDatabase cache")
        RomDatabase.reloadCache()
        ILOG("AppState: RomDatabase cache reloaded")
        await finalizeBootup()
    }

    @MainActor
    private func finalizeBootup() async {
        ILOG("AppState: Finalizing bootup")
        gameImporter = GameImporter.shared
        gameLibrary = PVGameLibrary<RealmDatabaseDriver>(database: RomDatabase.sharedInstance)
        libraryUpdatesController = PVGameLibraryUpdatesController(gameImporter: gameImporter!)

        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        await libraryUpdatesController?.addImportedGames(to: CSSearchableIndex.default(), database: RomDatabase.sharedInstance)
        #endif

        bootupStateManager.transition(to: .completed)
        ILOG("AppState: Bootup finalized")
        isInitialized = true
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
}

struct TimeoutError: Error {
    let seconds: TimeInterval
}
