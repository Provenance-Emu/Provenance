//
//  UITestingApp.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVThemes
import PVUIBase
import PVLibrary
import PVRealm
import PVEmulatorCore
import PVLogging
import RealmSwift
import PVSystems
import PVMediaCache
import PVCoreLoader
import PVPrimitives
import ObjectiveC

#if canImport(FreemiumKit)
import FreemiumKit
#endif

@main
struct UITestingApp: SwiftUI.App {
    // Static shared instance for access from other components
    static var shared: UITestingApp!
    @UIApplicationDelegateAdaptor(PVAppDelegate.self) var appDelegate

    init() {
        UITestingApp.shared = self
        // Use in-memory SwiftData store for UITesting to avoid schema migration crashes
        if let container = try? PVSwiftDataSchema.makePVModelContainer(inMemory: true) {
            PVSwiftDataSchema.setSharedContainer(container)
        }
    }

    @ObservedObject private var themeManager = ThemeManager.shared

    // Use the shared AppState for state management
    @StateObject private var appState = AppState.shared
    @StateObject private var sceneCoordinator = SceneCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    // Add a state variable to force view refreshes
    @State private var viewRefreshTrigger = UUID()

    // Add a timer to periodically force UI updates during bootup
    private let bootupRefreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // Tab selection state
    @State private var selectedTab = 0

//
//    // Setup in-memory Realm for testing
//    private func setupInMemoryRealm() {
//        // Configure Realm for in-memory storage
//        var config = Realm.Configuration()
//        config.inMemoryIdentifier = "UITestingRealm"
//
//        // Set this as the default configuration
//        Realm.Configuration.defaultConfiguration = config
//
//        ILOG("Configured in-memory Realm for testing")
//    }

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
            appState.gameImporter?.startProcessing()
        } catch {
            ELOG("UITestingApp: Error copying ROM: \(error)")
            throw error
        }
        appState.gameImporter?.resume()
    }

    // MARK: - UIViewControllerRepresentable for PVEmulatorViewController

    // MARK: - View Builders

    // State to track emulator preparation status
    @State private var emulatorError: String? = nil
    @State private var coreInstance: PVEmulatorCore? = nil


    // MARK: - Launch Methods

    /// Launch the emulator directly using the shared AppState
    private func launchEmulatorDirect(with game: PVGame) async {
        ILOG("UITestingApp: Direct launch of emulator with game: \(game.title) (ID: \(game.id))")
        ILOG("UITestingApp: Game details - System: \(game.system?.name ?? "nil"), Core: \(game.userPreferredCoreID ?? "nil")")

        // Set the current game in EmulationUIState directly using the original game
        await MainActor.run {
            ILOG("UITestingApp: Setting current game directly in AppState.shared.emulationUIState (using original reference)")
            AppState.shared.emulationUIState.currentGame = game
        }

        // Verify the game was set correctly in the shared instance
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("UITestingApp: Successfully set current game in shared EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
        } else {
            ELOG("UITestingApp: Failed to set current game in shared EmulationUIState")
        }


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
                self.coreInstance = nil
                self.emulatorError = nil
                ILOG("UITestingApp: Set flag to show emulator in current scene")
            }
        }
    }

    /// Update home indicator settings when scene phase changes
    private func updateHomeIndicatorSettings() {
        // Find all windows in all connected scenes and update home indicator settings
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.setHomeIndicatorAutoHidden(true)
                }
            }
        }
    }

    // MARK: - Mock Library

    /// Populates the default Realm with mock games when the library is empty.
    /// Triggered on simulator or when `-useMockLibrary` launch argument is set.
    private func populateMockLibraryIfNeeded() {
        #if DEBUG
        let shouldPopulate = LaunchArgument.useMockLibrary.isEnabled || AppState.shared.isSimulator
        guard shouldPopulate else { return }

        guard let realm = try? Realm() else {
            ELOG("UITestingApp: Cannot open Realm for mock library")
            return
        }

        // Only populate if the library is empty
        guard realm.objects(PVGame.self).isEmpty else {
            ILOG("UITestingApp: Library already has games, skipping mock population")
            return
        }

        ILOG("UITestingApp: Populating mock library")

        let mockGames: [(title: String, systemID: String, developer: String, publisher: String, genres: String, year: String)] = [
            ("Super Mario World", SystemIdentifier.SNES.rawValue, "Nintendo EAD", "Nintendo", "Platform, Action", "1990"),
            ("The Legend of Zelda: A Link to the Past", SystemIdentifier.SNES.rawValue, "Nintendo EAD", "Nintendo", "Action, Adventure", "1991"),
            ("Super Metroid", SystemIdentifier.SNES.rawValue, "Nintendo R&D1", "Nintendo", "Action, Adventure", "1994"),
            ("Chrono Trigger", SystemIdentifier.SNES.rawValue, "Square", "Square", "RPG", "1995"),
            ("Super Mario Bros.", SystemIdentifier.NES.rawValue, "Nintendo", "Nintendo", "Platform", "1985"),
            ("The Legend of Zelda", SystemIdentifier.NES.rawValue, "Nintendo", "Nintendo", "Action, Adventure", "1986"),
            ("Mega Man 2", SystemIdentifier.NES.rawValue, "Capcom", "Capcom", "Platform, Action", "1988"),
            ("Sonic the Hedgehog", SystemIdentifier.Genesis.rawValue, "Sonic Team", "Sega", "Platform", "1991"),
            ("Streets of Rage 2", SystemIdentifier.Genesis.rawValue, "Sega", "Sega", "Beat 'em up", "1992"),
            ("Pokemon Red", SystemIdentifier.GB.rawValue, "Game Freak", "Nintendo", "RPG", "1996"),
            ("Tetris", SystemIdentifier.GB.rawValue, "Nintendo", "Nintendo", "Puzzle", "1989"),
            ("Pokemon FireRed", SystemIdentifier.GBA.rawValue, "Game Freak", "Nintendo", "RPG", "2004"),
            ("Metroid Fusion", SystemIdentifier.GBA.rawValue, "Nintendo R&D1", "Nintendo", "Action, Adventure", "2002"),
            ("Super Mario 64", SystemIdentifier.N64.rawValue, "Nintendo EAD", "Nintendo", "Platform", "1996"),
            ("The Legend of Zelda: Ocarina of Time", SystemIdentifier.N64.rawValue, "Nintendo EAD", "Nintendo", "Action, Adventure", "1998"),
            ("Final Fantasy VII", SystemIdentifier.PSX.rawValue, "Square", "Square", "RPG", "1997"),
            ("Castlevania: Symphony of the Night", SystemIdentifier.PSX.rawValue, "Konami", "Konami", "Action, RPG", "1997"),
        ]

        do {
            try realm.write {
                for mock in mockGames {
                    let system = realm.objects(PVSystem.self).filter("identifier == %@", mock.systemID).first
                    let game = PVGame()
                    game.title = mock.title
                    game.systemIdentifier = mock.systemID
                    game.system = system
                    game.md5Hash = UUID().uuidString
                    game.developer = mock.developer
                    game.publisher = mock.publisher
                    game.genres = mock.genres
                    game.publishDate = mock.year
                    game.regionName = "USA"
                    game.playCount = Int.random(in: 0...50)
                    game.rating = Int.random(in: 3...5)
                    game.timeSpentInGame = Int.random(in: 0...7200)
                    let filename = mock.title.lowercased().replacingOccurrences(of: " ", with: "_") + ".rom"
                    game.file = PVFile(withPartialPath: filename, relativeRoot: .caches, size: Int.random(in: 1024...4_194_304), md5: game.md5Hash)
                    realm.add(game)
                }
            }
            ILOG("UITestingApp: Added \(mockGames.count) mock games to library")
        } catch {
            ELOG("UITestingApp: Failed to populate mock library: \(error)")
        }
        #endif
    }

    var body: some Scene {
        // Main window group for the UI
        WindowGroup(id: "main") {
            ContentView()
                .id(viewRefreshTrigger) // Force view refresh when this changes
                .handlesExternalEvents(preferring: ["main"], allowing: ["main"])
                .preferredColorScheme(ThemeManager.shared.currentPalette.dark ? .dark : .light)
                .environmentObject(appState)
                .environmentObject(ThemeManager.shared)
                .environmentObject(sceneCoordinator)
                .environmentObject(appDelegate)
                .hideHomeIndicator() // Hide the home indicator
#if canImport(FreemiumKit)
                .environmentObject(FreemiumKit.shared)
#endif
                .onAppear {
#if canImport(FreemiumKit)
                    FreemiumKit.shared.overrideForDebug(purchasedTier: 1)
#endif
                    appDelegate.appState = appState
                }
                .onReceive(bootupRefreshTimer) { _ in
                    // Only refresh during bootup process
                    if appState.bootupStateManager.currentState != .completed {
                        viewRefreshTrigger = UUID()
                    }
                }
                .onReceive(appState.bootupStateManager.$currentState) { newState in
                    // Force refresh when bootup state changes
                    ILOG("UITestingApp: Bootup state changed to \(newState.localizedDescription), forcing UI refresh")
                    viewRefreshTrigger = UUID()

                    // Add additional refresh after a short delay for .completed state
                    if newState == .completed {
                        // Populate mock library if on simulator with empty library
                        populateMockLibraryIfNeeded()
                        // Cancel the timer when bootup completes
                        bootupRefreshTimer.upstream.connect().cancel()

                        // Schedule multiple refreshes with different delays
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                            viewRefreshTrigger = UUID()
//                        }
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            viewRefreshTrigger = UUID()
//                        }
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            viewRefreshTrigger = UUID()
//                        }
                    }
                }
                .onReceive(appState.$isInitialized) { initialized in
                    ILOG("UITestingApp: isInitialized changed to \(initialized)")
                    if initialized {
                        // Force refresh when initialized changes to true
                        viewRefreshTrigger = UUID()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    ILOG("UITestingApp: App became active, forcing UI refresh")
                    viewRefreshTrigger = UUID()

                    // Check if we're in a state that should show the main view
                    if appState.bootupStateManager.currentState == .completed {
                        ILOG("UITestingApp: App is in completed state, forcing additional refreshes")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            viewRefreshTrigger = UUID()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BootupCompleted"))) { _ in
                    ILOG("UITestingApp: Received BootupCompleted notification, forcing UI refresh")
                    viewRefreshTrigger = UUID()

                    // Schedule multiple refreshes with different delays
//                    for delay in [0.1, 0.3, 0.5, 1.0] {
//                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                            ILOG("UITestingApp: Forcing refresh after BootupCompleted at \(delay)s")
//                            viewRefreshTrigger = UUID()
//                        }
//                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BootupStateChanged"))) { notification in
                    if let stateName = notification.userInfo?["state"] as? String {
                        ILOG("UITestingApp: Received BootupStateChanged notification: \(stateName)")
                        viewRefreshTrigger = UUID()

                        // If the state is "Bootup Completed", schedule additional refreshes
                        if stateName == "Bootup Completed" {
                            for delay in [0.1, 0.3, 0.5, 1.0] {
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    ILOG("UITestingApp: Forcing refresh after BootupStateChanged at \(delay)s")
                                    viewRefreshTrigger = UUID()
                                }
                            }
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()

                /// Swizzle sendEvent(UIEvent)
                if !appState.sendEventWasSwizzled {
                    // UIApplication.swizzleSendEvent()
                    appState.sendEventWasSwizzled = true
                }

                // Hide home indicator when app becomes active
                updateHomeIndicatorSettings()

                // Force UI refresh when becoming active
                viewRefreshTrigger = UUID()
            }

            // Handle scene phase changes for import pausing
            appState.handleScenePhaseChange(newPhase)
        }


        // Add the emulator scene as a separate scene
        TestEmulatorScene()
    }
}

/// Hack to get touches send to RetroArch

extension UIApplication {

    /// Swap implipmentations of sendEvent() while
    /// maintaing a reference back to the original
    @objc static func swizzleSendEvent() {
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            let swizzledSelector = #selector(UIApplication.pv_sendEvent(_:))
            let orginalStoreSelector = #selector(UIApplication.originalSendEvent(_:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                let swizzledMethod = class_getInstanceMethod(self, swizzledSelector),
                  let orginalStoreMethod = class_getInstanceMethod(self, orginalStoreSelector)
            else { return }
            method_exchangeImplementations(originalMethod, orginalStoreMethod)
            method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /// Placeholder for storing original selector
    @objc func originalSendEvent(_ event: UIEvent) { }

    /// The sendEvent that will be called
    @objc func pv_sendEvent(_ event: UIEvent) {
//        print("Handling touch event: \(event.type.rawValue ?? -1)")
        if let core = AppState.shared.emulationUIState.core {
            core.sendEvent(event)
        }

        originalSendEvent(event)
    }
}

/// A dedicated UIViewControllerRepresentable for controlling home indicator visibility
struct HomeIndicatorController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        HomeIndicatorManagerController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Force update of home indicator status
        uiViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        uiViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    private class HomeIndicatorManagerController: UIViewController {
        override var prefersHomeIndicatorAutoHidden: Bool {
            return true
        }

        override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
            return .all
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()

            // Also set for the parent view controller if any
            parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
            parent?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }
}
