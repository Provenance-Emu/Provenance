//
//  UITestingApp.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import SwiftUI
import UIKit
import Perception
import PVUIBase
import PVLibrary
import PVRealm
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import PVFileSystem
import RealmSwift
import PVSystems
import PVPlists
import PVCoreLoader

#if canImport(FreemiumKit)
import FreemiumKit
#endif



@main
struct UITestingApp: SwiftUI.App {
    @State private var showingRealmSheet = false
    @State private var showingMockSheet = false
    @State private var showingSettings = false
    @State private var showImportStatus = false
    @State private var showGameMoreInfo = false
    @State private var showGameMoreInfoRealm = false
    @State private var showArtworkSearch = false
    @State private var showFreeROMs = false
    @State private var showDeltaSkinList = false
    @State private var showEmulatorScene = false
    @State private var showEmulatorInCurrentScene = false
    
    // Use the real AppState for now, but we'll use our mockImportStatusDriverData for the importer
    @StateObject private var appState = AppState.shared
    @StateObject private var sceneCoordinator = SceneCoordinator.shared
    
    // Store the test game and loading state
    @State private var testGame: PVGame?
    @State private var isInitializing = false
    @State private var initializationError: String?
    
    // Initialize the in-memory Realm and systems
    init() {
        setupInMemoryRealm()
        
        // We'll initialize the systems in onAppear instead
    }
    
    // Setup in-memory Realm for testing
    private func setupInMemoryRealm() {
        // Configure Realm for in-memory storage
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "UITestingRealm"
        
        // Set this as the default configuration
        Realm.Configuration.defaultConfiguration = config
        
        ILOG("Configured in-memory Realm for testing")
    }
    
    // Initialize systems and create test game
    private func initializeSystemsAndTestGame() async throws {
        ILOG("UITestingApp: Initializing test environment")
        
        // Scan for real systems and cores from plists
        ILOG("UITestingApp: Scanning for real systems and cores from plists")
        await scanForRealSystemsAndCores()
        
        // Create a mock NES system for testing if needed
        let realm = try await Realm()
        try await realm.asyncWrite {
            // Check if we already have a NES system
            let existingSystems = realm.objects(PVSystem.self).where { $0.identifier == "com.provenance.nes" }
            
            if existingSystems.isEmpty {
                ILOG("UITestingApp: Creating mock NES system")
                let nesSystem = PVSystem()
                nesSystem.identifier = "com.provenance.nes"
                nesSystem.name = "Nintendo Entertainment System"
                nesSystem.shortName = "NES"
                nesSystem.manufacturer = "Nintendo"
                nesSystem.bit = 8
                nesSystem.releaseYear = 1985
                realm.add(nesSystem)
                ILOG("UITestingApp: Added mock NES system to database")
                
                let newCore = PVCore(withIdentifier: "com.mock.", principleClass: "", supportedSystems: [nesSystem], name: "Mock NES", url: "https://mock.com", version: "1.0")
                realm.add(newCore)

            } else {
                ILOG("UITestingApp: NES system already exists in database")
            }
        }
        
        // Check systems after initialization
        let systems = realm.objects(PVSystem.self)
        ILOG("UITestingApp: Found \(systems.count) systems in database")
        
        // Install the test ROM to trigger automatic import
        try await installTestROM()
        
        // Wait a moment for the import to process
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Find the NES system
        ILOG("UITestingApp: Looking for NES system")
        let nesSystem = SystemIdentifier.NES.system
        guard let system = nesSystem else {
            // Debug: Print out all available systems and cores
            ELOG("UITestingApp: Failed to find NES system. Dumping all systems and cores for debugging:")
            
            do {
                let realm = try await Realm()
                
                // Print all systems
                let systems = realm.objects(PVSystem.self)
                ELOG("UITestingApp: Available Systems (\(systems.count)):")
                for (index, sys) in systems.enumerated() {
                    ELOG("  [\(index)] System: \(sys.name) (ID: \(sys.identifier), Manufacturer: \(sys.manufacturer))")
                }
                
                // Print all cores
                let cores = realm.objects(PVCore.self)
                ELOG("UITestingApp: Available Cores (\(cores.count)):")
                for (index, core) in cores.enumerated() {
                    ELOG("  [\(index)] Core: \(core.projectName) (Systems: \(core.supportedSystems.map { $0.shortName }.joined(separator: ", ")))")
                }
                
                // Print system identifiers
                ELOG("UITestingApp: System Identifiers:")
                for identifier in SystemIdentifier.allCases {
                    ELOG("  Identifier: \(identifier.rawValue) -> System: \(identifier.system?.name ?? "nil")")
                }
                
            } catch {
                ELOG("UITestingApp: Error accessing Realm for debugging: \(error)")
            }
            
            let error = NSError(domain: "UITestingApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to find NES system"])
            ELOG("UITestingApp: Failed to find NES system")
            throw error
        }
        
        ILOG("UITestingApp: Found NES system: \(system.name)")
        
        // Get the first core for the NES system
        guard let core = system.cores.first else {
            ELOG("UITestingApp: No cores available for NES system. System details:")
            ELOG("  System: \(system.name) (ID: \(system.identifier))")
            ELOG("  Cores count: \(system.cores.count)")
            ELOG("  Manufacturer: \(system.manufacturer)")
            ELOG("  Extensions: \(system.extensions.joined(separator: ", "))")
            
            let error = NSError(domain: "UITestingApp", code: 2, userInfo: [NSLocalizedDescriptionKey: "No cores available for NES system"])
            ELOG("UITestingApp: No cores available for NES system")
            throw error
        }
        
        ILOG("UITestingApp: Using core: \(core.projectName)")
        
        // Get the path to the test ROM in the app bundle
        ILOG("UITestingApp: Looking for test ROM in app bundle")
        guard let testROMURL = Bundle.main.url(forResource: "240p", withExtension: "nes") else {
            let error = NSError(domain: "UITestingApp", code: 3, userInfo: [NSLocalizedDescriptionKey: "Test ROM not found in app bundle"])
            ELOG("UITestingApp: Test ROM not found in app bundle")
            throw error
        }
        
        ILOG("UITestingApp: Found test ROM at: \(testROMURL.path)")
        
        // Create a PVFile for the ROM
        ILOG("UITestingApp: Creating PVFile for ROM")
        let file = PVFile(withURL: testROMURL)
        
        // Create a game for the test ROM
        ILOG("UITestingApp: Creating PVGame for ROM")
        let game = PVGame()
        game.title = "240p Test Suite"
        game.systemIdentifier = system.identifier
        game.system = system
        game.romPath = testROMURL.path
        game.file = file
        
        // Add the game to Realm
        ILOG("UITestingApp: Adding game to Realm database")
        do {
            let realm = try await Realm()
            ILOG("UITestingApp: Realm opened successfully")
            
            // First check if the game already exists
            if let existingGame = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", "240p").first {
                ILOG("UITestingApp: Game already exists in Realm: \(existingGame.title)")
                
                // Store the existing game for later use
                await MainActor.run {
                    self.testGame = existingGame
                    ILOG("UITestingApp: Using existing game from Realm")
                }
            } else {
                // Add the new game to Realm
                try await realm.asyncWrite {
                    realm.add(game)
                    ILOG("UITestingApp: Added new game to Realm: \(game.title)")
                }
                
                // Store the new game for later use
                await MainActor.run {
                    self.testGame = game
                    ILOG("UITestingApp: Using newly added game from Realm")
                }
            }
        } catch {
            ELOG("UITestingApp: Error accessing Realm: \(error)")
            throw error
        }
    }

    @StateObject
    private var mockImportStatusDriverData = MockImportStatusDriverData()

    // Scan for real systems and cores from plists
    private func scanForRealSystemsAndCores() async {
        ILOG("UITestingApp: Starting scan for real systems and cores")
        
        do {
            // Find all system plists in the app bundle and packages
            let systemPlistURLs = findSystemPlistURLs()
            ILOG("UITestingApp: Found \(systemPlistURLs.count) system plist URLs")
            
            // Update systems from plists
            await PVEmulatorConfiguration.updateSystems(fromPlists: systemPlistURLs)
            ILOG("UITestingApp: Updated systems from plists")
            
            // Get core plists from CoreLoader
            let corePlists = CoreLoader.getCorePlists()
            ILOG("UITestingApp: Found \(corePlists.count) core plists")
            
            // Update cores from plists
            await PVEmulatorConfiguration.updateCores(fromPlists: corePlists)
            ILOG("UITestingApp: Updated cores from plists")
            
            // Log the systems and cores found
            let realm = try await Realm()
            let systems = realm.objects(PVSystem.self)
            let cores = realm.objects(PVCore.self)
            ILOG("UITestingApp: Found \(systems.count) systems and \(cores.count) cores after scanning")
            
            // Log the system identifiers
            for system in systems {
                ILOG("UITestingApp: Found system: \(system.name) (\(system.identifier))")
            }
        } catch {
            ELOG("UITestingApp: Error scanning for systems and cores: \(error)")
        }
    }
    
    // Find all system plist URLs in the app bundle and packages
    private func findSystemPlistURLs() -> [URL] {
        var urls: [URL] = []
        
        // Add system plist from the main bundle if it exists
        if let mainBundleURL = Bundle.main.url(forResource: "systems", withExtension: "plist") {
            urls.append(mainBundleURL)
            ILOG("UITestingApp: Found systems.plist in main bundle: \(mainBundleURL.path)")
        }
        
        // Add system plist from PVLibrary package if it exists
        let pvLibraryBundle = Bundle(for: GameImporter.self)
        if let pvLibraryURL = pvLibraryBundle.url(forResource: "systems", withExtension: "plist") {
            urls.append(pvLibraryURL)
            ILOG("UITestingApp: Found systems.plist in PVLibrary bundle: \(pvLibraryURL.path)")
        }
        
        // Add system plist from PVEmulatorCore package if it exists
        let pvEmulatorCoreBundle = Bundle(for: PVEmulatorConfiguration.self)
        if let pvEmulatorCoreURL = pvEmulatorCoreBundle.url(forResource: "systems", withExtension: "plist") {
            urls.append(pvEmulatorCoreURL)
            ILOG("UITestingApp: Found systems.plist in PVEmulatorCore bundle: \(pvEmulatorCoreURL.path)")
        }
        
        return urls
    }
    
    // Install the test ROM by copying it to the ROMs directory
    private func installTestROM() async throws {
        ILOG("UITestingApp: Installing test ROM")
        
        // Get the path to the test ROM in the app bundle
        guard let testROMURL = Bundle.main.url(forResource: "240p", withExtension: "nes") else {
            let error = NSError(domain: "UITestingApp", code: 3, userInfo: [NSLocalizedDescriptionKey: "Test ROM not found in app bundle"])
            ELOG("UITestingApp: Test ROM not found in app bundle")
            throw error
        }
        
        ILOG("UITestingApp: Found test ROM at: \(testROMURL.path)")
        
        // Get the Documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            let error = NSError(domain: "UITestingApp", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not access Documents directory"])
            ELOG("UITestingApp: Could not access Documents directory")
            throw error
        }
        
        // Create the ROMs/com.provenance.nes directory if it doesn't exist
        let romsDirectoryURL = documentsURL.appendingPathComponent("ROMs/com.provenance.nes", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: romsDirectoryURL, withIntermediateDirectories: true)
            ILOG("UITestingApp: Created ROMs directory at: \(romsDirectoryURL.path)")
        } catch {
            ELOG("UITestingApp: Error creating ROMs directory: \(error)")
            throw error
        }
        
        // Define the destination URL for the ROM
        let destinationURL = romsDirectoryURL.appendingPathComponent("240p-test.nes")
        
        // Check if the ROM already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            ILOG("UITestingApp: ROM already exists at destination, skipping copy")
            return
        }
        
        // Copy the ROM to the ROMs directory
        do {
            try FileManager.default.copyItem(at: testROMURL, to: destinationURL)
            ILOG("UITestingApp: Successfully copied ROM to: \(destinationURL.path)")
        } catch {
            ELOG("UITestingApp: Error copying ROM: \(error)")
            throw error
        }
    }
    
    /// Creates a save state for the specified game
    /// - Parameter game: The game to create a save state for
    /// - Returns: The created save state, or nil if creation failed
    private func createSaveState(for game: PVGame) async -> PVSaveState? {
        ILOG("UITestingApp: Creating save state for game: \(game.title)")
        
        // Get the Realm instance
        do {
            let realm = try await Realm()
            
            // Check if the game exists in the Realm
            guard let realmGame = realm.object(ofType: PVGame.self, forPrimaryKey: game.id) else {
                ELOG("UITestingApp: Game not found in Realm")
                return nil
            }
            
            // Create a new save state
//            let saveState = PVSaveState()
//            saveState.game = realmGame
//            saveState.core = realmGame.core
//            saveState.date = Date()
//            saveState.userDescription = "Test Save State"
//            
//            // Create a mock save state file
//            let saveStateFileName = "\(realmGame.id)_savestate.sav"
//            let saveStateFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(saveStateFileName)
            
            // Create an empty file for the save state
//            FileManager.default.createFile(atPath: saveStateFileURL.path, contents: Data(), attributes: nil)
            
            // Create a PVFile for the save state
//            let saveStateFile = PVFile()
//            saveStateFile.url = saveStateFileURL
//            saveStateFile.fileName = saveStateFileName
//            saveStateFile.fileExtension = "sav"
//            
//            // Assign the file to the save state
//            saveState.file = saveStateFile
//            
//            // Add the save state to the Realm
//            try await realm.asyncWrite {
//                realm.add(saveState)
//                realmGame.saveStates.append(saveState)
//            }
//            
            ILOG("UITestingApp: Created save state for game: \(realmGame.title)")
            return nil // saveState
        } catch {
            ELOG("UITestingApp: Failed to create save state: \(error)")
            return nil
        }
    }
    
    // MARK: - View Builders
    
    /// View for showing the emulator inline in the current scene
    @ViewBuilder
    private func inlineEmulatorView() -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Emulator View")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                if let game = testGame {
                    Text("Playing: \(game.title)")
                        .foregroundColor(.white)
                }
                
                Button("Close") {
                    showEmulatorInCurrentScene = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    /// Creates the initialization view based on the current state
    @ViewBuilder
    private func initializationView() -> some View {
        if isInitializing {
            VStack {
                Text("Initializing test game...").foregroundColor(.gray)
                ProgressView()
            }
        } else if let error = initializationError {
            VStack {
                Text("Initialization failed: \(error)").foregroundColor(.red)
                Button("Retry") {
                    initializationError = nil
                    isInitializing = true
                    Task {
                        do {
                            try await initializeSystemsAndTestGame()
                            isInitializing = false
                        } catch {
                            ELOG("UITestingApp: Retry initialization failed with error: \(error)")
                            initializationError = error.localizedDescription
                            isInitializing = false
                        }
                    }
                }
            }
        } else if testGame != nil {
            gameControlsView()
        } else {
            VStack {
                Text("Test game not initialized yet").foregroundColor(.orange)
                Button("Initialize Test Game") {
                    isInitializing = true
                    Task {
                        do {
                            try await initializeSystemsAndTestGame()
                            isInitializing = false
                        } catch {
                            ELOG("UITestingApp: Initialization failed with error: \(error)")
                            initializationError = error.localizedDescription
                            isInitializing = false
                        }
                    }
                }
            }
        }
    }
    
    /// Creates the game controls view when a test game is available
    @ViewBuilder
    private func gameControlsView() -> some View {
        Group {
            Button("Launch Emulator with Test ROM") {
                launchEmulatorWithTestROM()
            }
            
            Button("Launch Emulator (Direct)") {
                launchEmulatorDirect()
            }
        }
    }
    
    // MARK: - Launch Methods
    
    /// Launch the emulator with the test ROM using the standard approach
    private func launchEmulatorWithTestROM() {
        guard let game = testGame else { return }
        
        ILOG("UITestingApp: Launching emulator with game: \(game.title) (ID: \(game.id))")
        ILOG("UITestingApp: Game details - System: \(game.system?.name ?? "nil"), Core: \(game.userPreferredCoreID ?? "nil")")
        
        // Verify the game exists in Realm
        Task {
            do {
                let realm = try await Realm()
                
                // Try to find the game by different methods
                let gameByID: PVGame? = realm.object(ofType: PVGame.self, forPrimaryKey: game.id)
                let gamesByTitle: Results<PVGame> = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", "240p")
                let gamesByMD5: Results<PVGame> = realm.objects(PVGame.self).filter("id == %@", "06b44b6cbb2ecfca4325537ccb4d32a7")
                let gamesByFilename: Results<PVGame> = realm.objects(PVGame.self).filter("romPath CONTAINS[c] %@", "240p.nes")
                
                ILOG("UITestingApp: Search results - By ID: \(gameByID != nil ? "Found" : "Not found"), " +
                     "By Title: \(gamesByTitle.count), By MD5: \(gamesByMD5.count), By Filename: \(gamesByFilename.count)")
                
                // Use the first game found by any method
                let realmGame = gameByID ?? gamesByTitle.first ?? gamesByMD5.first ?? gamesByFilename.first
                
                if let realmGame = realmGame {
                    ILOG("UITestingApp: Found game in Realm: \(realmGame.title) (ID: \(realmGame.id))")
                    
                    // Update the testGame reference to use the one from Realm
                    await MainActor.run {
                        self.testGame = realmGame
                        ILOG("UITestingApp: Updated testGame reference to use the one from Realm")
                    }
                } else {
                    ELOG("UITestingApp: Game not found in Realm by any search method")
                }
            } catch {
                ELOG("UITestingApp: Error accessing Realm: \(error)")
            }
        }
        
        // Set the current game in EmulationUIState
        appState.emulationUIState.currentGame = game
        
        // Verify the game was set correctly
        if let currentGame = appState.emulationUIState.currentGame {
            ILOG("UITestingApp: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
        } else {
            ELOG("UITestingApp: Failed to set current game in EmulationUIState")
        }
        
        // Show the emulator scene directly
        showEmulatorScene = true
        
        ILOG("UITestingApp: Showing emulator scene directly via EmulationUIState")
        
        // Check if the device supports multiple scenes
        if UIApplication.shared.supportsMultipleScenes {
            // Create a window scene description for the emulator
            let windowScene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            if let windowScene = windowScene {
                ILOG("UITestingApp: Found active window scene, creating emulator scene")
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = windowScene
                
                // Log all connected scenes before activation
                ILOG("UITestingApp: Connected scenes before activation:")
                for (index, scene) in UIApplication.shared.connectedScenes.enumerated() {
                    ILOG("  [\(index)] Scene: \(scene), State: \(scene.activationState.rawValue)")
                }
                
                // Create a scene session request
                let request = UISceneSessionActivationRequest(options: options)
                
                // Use the recommended API instead of the deprecated one
                UIApplication.shared.activateSceneSession(for: request) { error in
                    ELOG("UITestingApp: Error activating emulator scene: \(error)")
                }
                
                // Log success since errorHandler is only called on error
                ILOG("UITestingApp: Successfully requested scene activation")
                
                // Log all connected scenes after activation
                ILOG("UITestingApp: Connected scenes after activation:")
                for (index, scene) in UIApplication.shared.connectedScenes.enumerated() {
                    ILOG("  [\(index)] Scene: \(scene), State: \(scene.activationState.rawValue)")
                }
            } else {
                ELOG("UITestingApp: Could not find active window scene")
            }
        } else {
            // Device doesn't support multiple scenes (e.g., iPhone simulator)
            ILOG("UITestingApp: Device doesn't support multiple scenes, using fallback approach")
            
            // Present the emulator directly in the current scene
            // This is a simplified approach - you may need to adjust based on your app's architecture
            DispatchQueue.main.async {
                // Set a flag to show the emulator in the current view hierarchy
                self.showEmulatorInCurrentScene = true
                ILOG("UITestingApp: Set flag to show emulator in current scene")
            }
        }
    }
    
    /// Launch the emulator directly using the shared AppState
    private func launchEmulatorDirect() {
        guard let game = testGame else { return }
        
        ILOG("UITestingApp: Direct launch of emulator with game: \(game.title) (ID: \(game.id))")
        ILOG("UITestingApp: Game details - System: \(game.system?.name ?? "nil"), Core: \(game.userPreferredCoreID ?? "nil")")
        
        // Verify the game exists in Realm and use the Realm version
        Task {
            do {
                let realm = try await Realm()
                
                // Try to find the game by different methods
                let gameByID = realm.object(ofType: PVGame.self, forPrimaryKey: game.id)
                let gamesByTitle = realm.objects(PVGame.self).filter("title CONTAINS[c] %@", "240p")
                let gamesByMD5 = realm.objects(PVGame.self).filter("id == %@", "06b44b6cbb2ecfca4325537ccb4d32a7")
                let gamesByFilename = realm.objects(PVGame.self).filter("romPath CONTAINS[c] %@", "240p.nes")
                
                ILOG("UITestingApp: Search results - By ID: \(gameByID != nil ? "Found" : "Not found"), " +
                     "By Title: \(gamesByTitle.count), By MD5: \(gamesByMD5.count), By Filename: \(gamesByFilename.count)")
                
                // Use the first game found by any method
                let realmGame = gameByID ?? gamesByTitle.first ?? gamesByMD5.first ?? gamesByFilename.first
                
                if let realmGame = realmGame {
                    ILOG("UITestingApp: Found game in Realm: \(realmGame.title) (ID: \(realmGame.id))")
                    
                    // Update the testGame reference and set it in AppState
                    await MainActor.run {
                        self.testGame = realmGame
                        ILOG("UITestingApp: Updated testGame reference to use the one from Realm")
                        
                        // Set the current game in EmulationUIState directly
                        ILOG("UITestingApp: Setting current game directly in AppState.shared.emulationUIState")
                        AppState.shared.emulationUIState.currentGame = realmGame
                    }
                } else {
                    ELOG("UITestingApp: Game not found in Realm by any search method")
                    
                    // Set the current game in EmulationUIState directly using the original game
                    await MainActor.run {
                        ILOG("UITestingApp: Setting current game directly in AppState.shared.emulationUIState (using original reference)")
                        AppState.shared.emulationUIState.currentGame = game
                    }
                }
            } catch {
                ELOG("UITestingApp: Error accessing Realm: \(error)")
                
                // Set the current game in EmulationUIState directly using the original game
                await MainActor.run {
                    ILOG("UITestingApp: Setting current game directly in AppState.shared.emulationUIState (using original reference)")
                    AppState.shared.emulationUIState.currentGame = game
                }
            }
        }
        
        // Verify the game was set correctly in the shared instance
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("UITestingApp: Successfully set current game in shared EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
        } else {
            ELOG("UITestingApp: Failed to set current game in shared EmulationUIState")
        }
        
        // Show the emulator scene directly
        showEmulatorScene = true
        
        ILOG("UITestingApp: Direct showing emulator scene")
        
        // Check if the device supports multiple scenes
        if UIApplication.shared.supportsMultipleScenes {
            // Create a window scene description for the emulator
            let windowScene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            if let windowScene = windowScene {
                ILOG("UITestingApp: Found active window scene, creating emulator scene")
                
                // Log the current state of the game in EmulationUIState
                ILOG("UITestingApp: Current game in shared EmulationUIState: \(AppState.shared.emulationUIState.currentGame?.title ?? "nil")")
                
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = windowScene
                
                // Log all connected scenes before activation
                ILOG("UITestingApp: Connected scenes before activation:")
                for (index, scene) in UIApplication.shared.connectedScenes.enumerated() {
                    ILOG("  [\(index)] Scene: \(scene), State: \(scene.activationState.rawValue)")
                }
                
                // Create a scene session request
                let request = UISceneSessionActivationRequest(options: options)
                
                // Use the recommended API instead of the deprecated one
                UIApplication.shared.activateSceneSession(for: request) { error in
                    ELOG("UITestingApp: Error activating emulator scene: \(error)")
                }
                
                // Log success since errorHandler is only called on error
                ILOG("UITestingApp: Successfully requested scene activation")
            } else {
                ELOG("UITestingApp: Could not find active window scene")
            }
        } else {
            // Device doesn't support multiple scenes (e.g., iPhone simulator)
            ILOG("UITestingApp: Device doesn't support multiple scenes, using fallback approach")
            
            // Present the emulator directly in the current scene
            DispatchQueue.main.async {
                // Set a flag to show the emulator in the current view hierarchy
                self.showEmulatorInCurrentScene = true
                ILOG("UITestingApp: Set flag to show emulator in current scene")
            }
        }
    }
    
    // MARK: - Scene Body
    
    var body: some Scene {
        // Main window group for the UI
        WindowGroup {
            ZStack {
                NavigationView {
                    List {
                        Section("Emulator Testing") {
                            initializationView()
                        }
                        
                        Section("UI Testing") {
                            Button("Test DeltaSkins List") {
                                showDeltaSkinList = true
                            }
                            Button("Show Realm Driver") {
                                showingRealmSheet = true
                            }
                            Button("Show Mock Driver") {
                                showingMockSheet = true
                            }
                            Button("Show Settings") {
                                showingSettings = true
                            }
                            Button("Show Import Queue") {
                                showImportStatus = true
                            }
                        }
                    }
                    .navigationTitle("UI Testing")
                }
                
                // Overlay the emulator view when needed
                if showEmulatorInCurrentScene {
                    inlineEmulatorView()
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's on top
                }
            }
            .onAppear {
                ILOG("UITestingApp: Main view appeared, starting initialization")
                
                // Initialize the mock importer first
                Task {
                    ILOG("UITestingApp: Initializing mock importer")
                    let importer = mockImportStatusDriverData.gameImporter
                    await importer.initSystems()
                    ILOG("UITestingApp: Mock importer initialized")
                }
                
                // Then initialize systems and test game if needed
                if testGame == nil && !isInitializing {
                    isInitializing = true
                    Task {
                        do {
                            try await initializeSystemsAndTestGame()
                            isInitializing = false
                        } catch {
                            ELOG("UITestingApp: Initialization failed with error: \(error)")
                            initializationError = error.localizedDescription
                            isInitializing = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRealmSheet) {
                let testRealm = try! RealmSaveStateTestFactory.createInMemoryRealm()
                let mockDriver = RealmSaveStateDriver(realm: testRealm)

                /// Get the first game from realm for the view model
                let game = testRealm.objects(PVGame.self).first!

                /// Create view model with game data
                let viewModel = ContinuesMagementViewModel(
                    driver: mockDriver,
                    gameTitle: game.title,
                    systemTitle: "Game Boy",
                    numberOfSaves: game.saveStates.count
                )

                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                        /// Load initial states through the publisher
                        mockDriver.loadSaveStates(forGameId: "1")
                    }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingMockSheet) {
                /// Create mock driver with sample data
                let mockDriver = MockSaveStateDriver(mockData: true)
                /// Create view model with mock driver
                let viewModel = ContinuesMagementViewModel(
                    driver: mockDriver,
                    gameTitle: mockDriver.gameTitle,
                    systemTitle: mockDriver.systemTitle,
                    numberOfSaves: 5, // Use a fixed number instead of async call
                    gameUIImage: mockDriver.gameUIImage
                )

                ContinuesMagementView(viewModel: viewModel)
                    .onAppear {
                    }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    // Use the existing MockGameImporter from mockImportStatusDriverData
                    let gameImporter = mockImportStatusDriverData.gameImporter
                    let pvgamelibraryUpdatesController = mockImportStatusDriverData.pvgamelibraryUpdatesController
                    let menuDelegate = MockPVMenuDelegate()

                    PVSettingsView(
                        conflictsController: pvgamelibraryUpdatesController,
                        menuDelegate: menuDelegate
                    ) {
                        showingSettings = false
                    }
                    .navigationBarHidden(true)
                }
                .navigationViewStyle(.stack)
            }
            .sheet(isPresented: $showImportStatus) {
                ImportStatusView(
                    updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                    gameImporter: mockImportStatusDriverData.gameImporter,
                    delegate: mockImportStatusDriverData) {
                        print("Import Status View Closed")
                    }
            }
            .sheet(isPresented: $showGameMoreInfo) {
                NavigationView {
                    let driver = MockGameLibraryDriver()
                    PagedGameMoreInfoView(viewModel: PagedGameMoreInfoViewModel(driver: driver))
                        .navigationTitle("Game Info")
                }
            }
            .sheet(isPresented: $showGameMoreInfoRealm) {
                if let driver = try? RealmGameLibraryDriver.previewDriver() {
                    NavigationView {
                        PagedGameMoreInfoView(viewModel: PagedGameMoreInfoViewModel(driver: driver))
                            .navigationTitle("Game Info")
                    }
                }
            }
            .sheet(isPresented: $showArtworkSearch) {
                NavigationView {
                    ArtworkSearchView { selection in
                        print("Selected artwork: \(selection.metadata.url)")
                        showArtworkSearch = false
                    }
                    .navigationTitle("Artwork Search")
                    #if !os(tvOS)
                    .background(Color(uiColor: .systemBackground))
                    #endif
                }
                #if !os(tvOS)
                .presentationBackground(Color(uiColor: .systemBackground))
                #endif
            }
            .sheet(isPresented: $showFreeROMs) {
                FreeROMsView { rom, url in
                    print("Downloaded ROM: \(rom.file) to: \(url)")
                }
            }
            .sheet(isPresented: $showDeltaSkinList) {
                NavigationView {
                    DeltaSkinListView(manager: DeltaSkinManager.shared)
                }
            }
            .onAppear {
#if canImport(FreemiumKit)
                FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
#endif
            }
        }
#if canImport(FreemiumKit)
        .environmentObject(FreemiumKit.shared)
#endif
        
        // Add the emulator scene as a separate scene
        EmulatorScene()
    }
}

class MockPVMenuDelegate: PVMenuDelegate {
    func didTapImports() {

    }

    func didTapSettings() {

    }

    func didTapHome() {

    }

    func didTapAddGames() {

    }

    func didTapConsole(with consoleId: String) {

    }

    func didTapCollection(with collection: Int) {

    }

    func closeMenu() {

    }
}

struct MainView_Previews: PreviewProvider {
    @State static private var showSaveStatesMock = false
    @State static private var showingSettings = false
    @State static private var showImportQueue = false
    @State static private var mockImportStatusDriverData = MockImportStatusDriverData()
    
    // Reference to shared AppState and SceneCoordinator for the preview
    private static let appState = AppState.shared
    private static let sceneCoordinator = SceneCoordinator.shared

    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Button("Show Realm Driver") { }
                    .buttonStyle(.borderedProminent)

                Button("Show Mock Driver") { }
                    .buttonStyle(.borderedProminent)

                Button("Show Settings") { }
                    .buttonStyle(.borderedProminent)

                Button("Show Import Queue") {
                    showImportQueue = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showingSettings) {
            // Use the existing PVGameLibraryUpdatesController from mockImportStatusDriverData
            let menuDelegate = MockPVMenuDelegate()

            PVSettingsView(
                conflictsController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                menuDelegate: menuDelegate) {

                }
        }
        .sheet(isPresented: .init(
            get: { mockImportStatusDriverData.isPresent },
            set: { mockImportStatusDriverData.isPresent = $0 }
        )) {
            ImportStatusView(
                updatesController: mockImportStatusDriverData.pvgamelibraryUpdatesController,
                gameImporter: mockImportStatusDriverData.gameImporter,
                delegate: mockImportStatusDriverData)
        }
        .onAppear {
#if canImport(FreemiumKit)
            FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
#endif
        }
        
        // Preview of the main app UI
    }
    

}
