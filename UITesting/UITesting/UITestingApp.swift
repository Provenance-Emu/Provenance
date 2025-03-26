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

#if canImport(FreemiumKit)
import FreemiumKit
#endif

@main
struct UITestingApp: SwiftUI.App {
    @ObservedObject private var themeManager = ThemeManager.shared

    // Use the shared AppState for state management
    @StateObject private var appState = AppState.shared
    @StateObject private var sceneCoordinator = SceneCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Use EnvironmentObject for bootup state manager
    
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

    @StateObject
    private var mockImportStatusDriverData = MockImportStatusDriverData()


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

    /// SwiftUI wrapper for PVEmulatorViewController
    struct EmulatorViewControllerWrapper: UIViewControllerRepresentable {
        let game: PVGame
        let coreInstance: PVEmulatorCore

        func makeUIViewController(context: Context) -> PVEmulatorViewController {
            let emulatorViewController = PVEmulatorViewController(game: game, core: coreInstance)
            return emulatorViewController
        }

        func updateUIViewController(_ uiViewController: PVEmulatorViewController, context: Context) {
            // Update the view controller if needed
        }
    }

    // MARK: - View Builders

    // State to track emulator preparation status
    @State private var emulatorError: String? = nil
    @State private var coreInstance: PVEmulatorCore? = nil

    /// Prepare the emulator core instance
    private func prepareEmulatorCore(forGame game: PVGame?) {
            // TODO: We already have the default GameLaunchingViewController.swift protocol to use to find the right core
    }


    /// Creates the game controls view when a test game is available
    @ViewBuilder
    private func gameLibraryView() -> some View {
        // TODO: Cells for PVGames or emtpy library
    }

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
        
    var body: some Scene {
        // Main window group for the UI
        WindowGroup(id: "main") {            
            ContentView()
            .handlesExternalEvents(preferring: ["main"], allowing: ["main"])
            .preferredColorScheme(ThemeManager.shared.currentPalette.dark ? .dark : .light)
            .environmentObject(appState)
            .environmentObject(ThemeManager.shared)
            .environmentObject(sceneCoordinator)
#if canImport(FreemiumKit)
            .environmentObject(FreemiumKit.shared)
#endif
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                appState.startBootupSequence()

                /// Swizzle sendEvent(UIEvent)
                if !appState.sendEventWasSwizzled {
                    // UIApplication.swizzleSendEvent()
                    appState.sendEventWasSwizzled = true
                }

                // Check if we need to open the emulator scene based on app open action
                if case .completed = appState.bootupStateManager.currentState {
                    ILOG("UITestingApp: Bootup state is completed, ready for user interaction")
                    
                    // Force UI refresh after a short delay to ensure the UI updates
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        ILOG("UITestingApp: Forcing UI refresh after bootup completion")
                        
                        // Temporarily change state and change it back to force refresh
                        let currentState = appState.bootupStateManager.currentState
                        appState.bootupStateManager.transition(to: .notStarted)
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        appState.bootupStateManager.transition(to: currentState)
                    }
                }
            }

            // Handle scene phase changes for import pausing
            appState.handleScenePhaseChange(newPhase)
        }
        
        // Add the emulator scene as a separate scene
        EmulatorScene()
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
