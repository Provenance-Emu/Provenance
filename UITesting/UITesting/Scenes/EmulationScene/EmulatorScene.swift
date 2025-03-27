//
//  EmulatorScene.swift
//  Provenance
//
//  Created on 2025-03-25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLibrary
import PVEmulatorCore
import PVCoreBridge
import PVLogging
import PVThemes
import RealmSwift

/// A SwiftUI scene for displaying the emulator screen and controls
struct EmulatorScene: Scene {
    @StateObject private var appState = AppState.shared
    @StateObject private var sceneCoordinator = SceneCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup(id: "emulator") {
            EmulatorContainerView()
                .environmentObject(appState)
                .environmentObject(sceneCoordinator)
                .preferredColorScheme(ThemeManager.shared.currentPalette.dark ? .dark : .light)
                .onAppear {
                    ILOG("EmulatorScene: Scene appeared")
                    ILOG("EmulatorScene: AppState.shared instance: \(AppState.shared)")
                    ILOG("EmulatorScene: Current EmulationUIState: \(appState.emulationUIState)")
                    
                    if let game = appState.emulationUIState.currentGame {
                        ILOG("EmulatorScene: Current game in EmulationUIState: \(game.title) (ID: \(game.id))")
                        ILOG("EmulatorScene: Game details - System: \(game.system?.name ?? "nil"), userPreferredCoreID: \(game.userPreferredCoreID ?? "nil")")
                    } else {
                        ELOG("EmulatorScene: No game found in EmulationUIState")
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        ILOG("EmulatorScene: Scene became active")
                        // Make sure the emulation doesn't pause when scene is active
                        if let core = appState.emulationUIState.core, 
                           let emulator = appState.emulationUIState.emulator,
                           !emulator.isShowingMenu {
                            core.setPauseEmulation(false)
                        }
                    } else if newPhase == .background {
                        ILOG("EmulatorScene: Scene went to background")
                        // Pause emulation when scene goes to background
                        if let core = appState.emulationUIState.core {
                            core.setPauseEmulation(true)
                        }
                    } else if newPhase == .inactive {
                        ILOG("EmulatorScene: Scene became inactive")
                    }
                }
        }
        .handlesExternalEvents(matching: ["emulator"])
        .commands {
            // Add any menu commands specific to the emulator scene
            CommandGroup(replacing: .appInfo) {
                Button("About Provenance Emulator") {
                    // Show about dialog
                }
            }
            
            CommandMenu("Emulation") {
                Button("Pause/Resume") {
                    if let core = appState.emulationUIState.core {
                        core.setPauseEmulation(!core.isOn)
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
                
                Button("Take Screenshot") {
                    if let emulator = appState.emulationUIState.emulator {
                        _ = emulator.captureScreenshot()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Save State") {
                    if let emulator = appState.emulationUIState.emulator {
                        Task {
                            try? await emulator.createNewSaveState(auto: false, screenshot: emulator.captureScreenshot())
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Load State") {
                    // Show load state UI
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Divider()
                
                Button("Quit Emulation") {
                    if let emulator = appState.emulationUIState.emulator {
                        Task {
                            await emulator.quit(optionallySave: true) {
                                // After quitting, return to the main scene
                                SceneCoordinator.shared.closeEmulator()
                            }
                        }
                    } else {
                        // If there's no emulator, just close the scene
                        SceneCoordinator.shared.closeEmulator()
                    }
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }
    }
}

/// A container view that manages the emulator view controller
struct EmulatorContainerView: UIViewControllerRepresentable, GameLaunchingViewController {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sceneCoordinator: SceneCoordinator
    
    // Use a coordinator to store the reference to the container view controller
    class Coordinator {
        var containerViewController: EmulatorContainerViewController?
        var parentView: EmulatorContainerView?
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    // State for core selection alert
    @State private var showCoreSelectionAlert = false
    @State private var gameForCoreSelection: PVGame? = nil
    
    func makeUIViewController(context: Context) -> UIViewController {
        ILOG("EmulatorContainerView: Creating container view controller")
        let containerVC = EmulatorContainerViewController()
        context.coordinator.containerViewController = containerVC
        context.coordinator.parentView = self
        
        // Log the state of AppState and EmulationUIState
        ILOG("EmulatorContainerView: AppState.shared instance: \(AppState.shared)")
        ILOG("EmulatorContainerView: Current EmulationUIState: \(appState.emulationUIState)")
        
        // Check if we have a game to launch
        if let game = appState.emulationUIState.currentGame {
            ILOG("EmulatorContainerView: Found game to launch: \(game.title) (ID: \(game.id))")
            ILOG("EmulatorContainerView: Game details - System: \(game.system?.name ?? "nil"), userPreferredCoreID: \(game.userPreferredCoreID ?? "nil")")
            
            Task {
                await handleGameLaunch(game: game, containerVC: containerVC)
            }
        } else {
            ELOG("EmulatorContainerView: No game found to launch in EmulationUIState")
            ELOG("EmulatorContainerView: This is likely because the EmulationUIState.currentGame property is not being properly set or observed")
        }
        
        return containerVC
    }
    
    /// Handles the game launch process, including core selection if needed
    private func handleGameLaunch(game: PVGame, containerVC: EmulatorContainerViewController) async {
        ILOG("EmulatorContainerView: Handling game launch for \(game.title)")
        
        // Check if the game has a system
        guard let system = game.system else {
            ELOG("EmulatorContainerView: Game has no system, cannot launch")
            displayAndLogError(withTitle: "Launch Error", message: "Cannot launch game: No system associated with this game.", customActions: nil)
            return
        }
        
        // Get available cores for the system
        let availableCores = system.cores
        ILOG("EmulatorContainerView: System \(system.name) has \(availableCores.count) available cores")
        
        // If there's only one core, use it
        if availableCores.count == 1, let singleCore = availableCores.first {
            ILOG("EmulatorContainerView: System has only one core (\(singleCore.projectName)), using it automatically")
            await containerVC.load(game, sender: nil, core: singleCore, saveState: nil)
            return
        }
        
        // If there are multiple cores, check for user preferred core
        if availableCores.count > 1 {
            ILOG("EmulatorContainerView: System has multiple cores, checking for user preferred core")
            
            // Check if the game has a user preferred core ID
            if let preferredCoreID = game.userPreferredCoreID, !preferredCoreID.isEmpty {
                ILOG("EmulatorContainerView: Game has user preferred core ID: \(preferredCoreID)")
                
                // Find the core with the matching ID
                if let preferredCore = availableCores.first(where: { $0.id == preferredCoreID }) {
                    ILOG("EmulatorContainerView: Found preferred core: \(preferredCore.projectName), using it")
                    await containerVC.load(game, sender: nil, core: preferredCore, saveState: nil)
                    return
                } else {
                    WLOG("EmulatorContainerView: Preferred core ID \(preferredCoreID) not found in available cores")
                }
            }
            
            // Check if the system has a user preferred core ID
            if let systemPreferredCoreID = system.userPreferredCoreID, !systemPreferredCoreID.isEmpty {
                ILOG("EmulatorContainerView: System has user preferred core ID: \(systemPreferredCoreID)")
                
                // Find the core with the matching ID
                if let preferredCore = availableCores.first(where: { $0.id == systemPreferredCoreID }) {
                    ILOG("EmulatorContainerView: Found system's preferred core: \(preferredCore.projectName), using it")
                    await containerVC.load(game, sender: nil, core: preferredCore, saveState: nil)
                    return
                } else {
                    WLOG("EmulatorContainerView: System's preferred core ID \(systemPreferredCoreID) not found in available cores")
                }
            }
            
            // If we get here, we need to show the core selection UI
            ILOG("EmulatorContainerView: No preferred core found, showing core selection UI")
            await MainActor.run {
                presentCoreSelection(forGame: game, sender: containerVC)
            }
            return
        }
        
        // If we get here, there are no cores available
        ELOG("EmulatorContainerView: No cores available for system \(system.name)")
        displayAndLogError(withTitle: "Launch Error", message: "Cannot launch game: No cores available for system \(system.name).", customActions: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view controller if needed
        if let containerVC = uiViewController as? EmulatorContainerViewController {
            context.coordinator.containerViewController = containerVC
        }
    }
    
    // MARK: - GameLaunchingViewController Protocol Implementation
    
    func load(_ game: PVRealm.PVGame, sender: Any?, core: PVRealm.PVCore?, saveState: PVRealm.PVSaveState?) async {
        ILOG("EmulatorContainerView: Delegating load to container view controller")
        if let containerVC = (UIApplication.shared.connectedScenes.first?.delegate as? UIWindowSceneDelegate)?.window??.rootViewController?.children.first as? EmulatorContainerViewController {
            await containerVC.load(game, sender: sender, core: core, saveState: saveState)
        } else {
            ELOG("EmulatorContainerView: No container view controller available to load game")
        }
    }
    
    func openSaveState(_ saveState: PVRealm.PVSaveState) async {
        ILOG("EmulatorContainerView: Delegating openSaveState to container view controller")
        if let containerVC = (UIApplication.shared.connectedScenes.first?.delegate as? UIWindowSceneDelegate)?.window??.rootViewController?.children.first as? EmulatorContainerViewController {
            await containerVC.openSaveState(saveState)
        } else {
            ELOG("EmulatorContainerView: No container view controller available to open save state")
        }
    }
    
    // Implementation of GameLaunchingViewController protocol
    func presentCoreSelection(forGame game: PVGame, sender: Any?) {
        ILOG("EmulatorContainerView: Presenting core selection for game: \(game.title)")
        
        // Store the game for core selection
        gameForCoreSelection = game
        
        guard let system = game.system else {
            ELOG("EmulatorContainerView: Game has no system, cannot present core selection")
            displayAndLogError(withTitle: "Launch Error", message: "Cannot launch game: No system associated with this game.", customActions: nil)
            return
        }
        
        // Get the available cores
        let availableCores = system.cores
        
        if availableCores.isEmpty {
            ELOG("EmulatorContainerView: No cores available for system \(system.name)")
            displayAndLogError(withTitle: "Launch Error", message: "Cannot launch game: No cores available for system \(system.name).", customActions: nil)
            return
        }
        
        // Present the core selection using UIKit alert controller
        guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
            ELOG("EmulatorContainerView: No root view controller available for presenting core selection")
            return
        }
        
        let alertController = UIAlertController(title: "Select Core", message: "Choose a core to run \(game.title)", preferredStyle: .actionSheet)
        
        // Add actions for each core
        for core in availableCores {
            let action = UIAlertAction(title: core.projectName, style: .default) { _ in
                ILOG("EmulatorContainerView: Selected core: \(core.projectName)")
                
                // Remember this core as the preferred core for this game
                Task {
                    do {
                        let realm = try await Realm()
                        try await realm.asyncWrite {
                            game.userPreferredCoreID = core.id
                        }
                        ILOG("EmulatorContainerView: Set preferred core ID \(core.id) for game \(game.title)")
                    } catch {
                        ELOG("EmulatorContainerView: Failed to set preferred core: \(error)")
                    }
                    
                    // Load the game with the selected core
                    if let containerVC = sender as? EmulatorContainerViewController {
                        await containerVC.load(game, sender: nil, core: core, saveState: nil)
                    } else {
                        await self.load(game, sender: sender, core: core, saveState: nil)
                    }
                }
            }
            alertController.addAction(action)
        }
        
        // Add a "Remember for all games of this system" option
        let rememberSystemAction = UIAlertAction(title: "Remember choice for all \(system.name) games", style: .default) { _ in
            // Show another alert to select which core to remember
            let systemCoreAlert = UIAlertController(title: "Select Default Core for \(system.name)", 
                                                  message: "This core will be used for all \(system.name) games", 
                                                  preferredStyle: .actionSheet)
            
            for core in availableCores {
                let coreAction = UIAlertAction(title: core.projectName, style: .default) { _ in
                    Task {
                        do {
                            let realm = try await Realm()
                            try await realm.asyncWrite {
                                // Set the preferred core for the system
                                system.userPreferredCoreID = core.id
                                // Also set it for this game
                                game.userPreferredCoreID = core.id
                            }
                            ILOG("EmulatorContainerView: Set preferred core ID \(core.id) for system \(system.name)")
                            
                            // Load the game with the selected core
                            if let containerVC = sender as? EmulatorContainerViewController {
                                await containerVC.load(game, sender: nil, core: core, saveState: nil)
                            } else {
                                await self.load(game, sender: sender, core: core, saveState: nil)
                            }
                        } catch {
                            ELOG("EmulatorContainerView: Failed to set preferred core for system: \(error)")
                        }
                    }
                }
                systemCoreAlert.addAction(coreAction)
            }
            
            systemCoreAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            if let popover = systemCoreAlert.popoverPresentationController, let sourceView = sender as? UIView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
            
            viewController.present(systemCoreAlert, animated: true, completion: nil)
        }
        alertController.addAction(rememberSystemAction)
        
        // Add a cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Configure popover for iPad
        if let popover = alertController.popoverPresentationController, let sourceView = sender as? UIView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        // Present the alert controller
        viewController.present(alertController, animated: true, completion: nil)
    }
    
    func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]?) {
        guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if let customActions = customActions {
            for action in customActions {
                alertController.addAction(action)
            }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        
        viewController.present(alertController, animated: true, completion: nil)
    }
    
    func updateRecentGames(_ game: PVGame) {
        // Update recent games in app state
        if let gameLibrary = appState.gameLibrary {
            // Add game to recent games list
            AppState.shared.emulationUIState.currentGame = game
        }
    }
}

/// A view controller that hosts the emulator view controller
class EmulatorContainerViewController: UIViewController, GameLaunchingViewController {
    // Delegate for handling quit completion
    var quitCompletionHandler: (() -> Void)?
    private var emulatorViewController: PVEmulatorViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    // Implementation of GameLaunchingViewController protocol
    func presentCoreSelection(forGame game: PVGame, sender: Any?) {
        let alertController = UIAlertController(title: "Select Core", message: "Choose a core to run \(game.title)", preferredStyle: .actionSheet)
        
        if let system = game.system {
            for core in system.cores {
                let action = UIAlertAction(title: core.projectName, style: .default) { _ in
                    Task {
                        await self.load(game, sender: sender, core: core, saveState: nil)
                    }
                }
                alertController.addAction(action)
            }
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alertController.popoverPresentationController, let sourceView = sender as? UIView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    func displayAndLogError(withTitle title: String, message: String, customActions: [UIAlertAction]?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if let customActions = customActions {
            for action in customActions {
                alertController.addAction(action)
            }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    func updateRecentGames(_ game: PVGame) {
        (self as GameLaunchingViewController).updateRecentGames(game)
        // Update recent games in app state
        if let gameLibrary = AppState.shared.gameLibrary {
            // Add game to recent games list
            AppState.shared.emulationUIState.currentGame = game
        }
    }
    
//    @MainActor
//    func load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
//        do {
//            try await canLoad(game)
//            
//            // Store the game in the app state
//            AppState.shared.emulationUIState.currentGame = game
//            
//            ILOG("EmulatorContainerViewController: Loading game: \(game.title)")
//            
//            // If a core is specified, use it, otherwise use the default core or present core selection
//            if let core = core {
//                ILOG("EmulatorContainerViewController: Using specified core: \(core.projectName)")
//                await presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? view)
//            } else if let saveState = saveState, let core = saveState.core {
//                ILOG("EmulatorContainerViewController: Using core from save state: \(core.projectName)")
//                await presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? view)
//                
//                // Load the save state after the emulator is initialized
//                if let emulatorVC = self.emulatorViewController {
//                    await emulatorVC.loadSaveState(saveState)
//                }
//            } else if let system = game.system, let defaultCore = system.cores.first {
//                ILOG("EmulatorContainerViewController: Using default core: \(defaultCore.projectName)")
//                await presentEMU(withCore: defaultCore, forGame: game, source: sender as? UIView ?? view)
//            } else {
//                ILOG("EmulatorContainerViewController: No core specified, presenting core selection")
//                presentCoreSelection(forGame: game, sender: sender)
//            }
//            
//            // Update recent games
//            updateRecentGames(game)
//            
//        } catch let error as GameLaunchingError {
//            handleGameLaunchingError(error, forGame: game)
//        } catch {
//            displayAndLogError(withTitle: "Error", message: "An unknown error occurred: \(error.localizedDescription)", customActions: nil)
//        }
//    }
    
    @MainActor
    func openSaveState(_ saveState: PVSaveState) async {
        ILOG("EmulatorContainerViewController: Opening save state: \(saveState.md5)")
        
        do {
            guard let game = saveState.game else {
                ELOG("EmulatorContainerViewController: Cannot open save state with no associated game")
                throw GameLaunchingError.generic("Game not found")
            }
            
            try await canLoad(game)
            
            // Store the game in the app state
            AppState.shared.emulationUIState.currentGame = game
            
            if let core = saveState.core {
                ILOG("EmulatorContainerViewController: Using core from save state: \(core.projectName)")
                await presentEMU(withCore: core, forGame: game, source: view)
                
                // Load the save state after the emulator is initialized
                if let emulatorVC = self.emulatorViewController {
                    await emulatorVC.loadSaveState(saveState)
                }
            } else if let system = game.system, let defaultCore = system.cores.first {
                ILOG("EmulatorContainerViewController: No core in save state, using default: \(defaultCore.projectName)")
                await presentEMU(withCore: defaultCore, forGame: game, source: view)
            } else {
                ILOG("EmulatorContainerViewController: No core specified, presenting core selection")
                presentCoreSelection(forGame: game, sender: nil)
            }
            
            // Update recent games
            updateRecentGames(game)
            
        } catch let error as GameLaunchingError {
            if let game = saveState.game {
                handleGameLaunchingError(error, forGame: game)
            } else {
                displayAndLogError(withTitle: "Error", message: "Failed to open save state: \(error.localizedDescription)", customActions: nil)
            }
        } catch {
            displayAndLogError(withTitle: "Error", message: "An unknown error occurred: \(error.localizedDescription)", customActions: nil)
        }
    }
    
    @MainActor
    private func presentEMU(withCore core: PVCore, forGame game: PVGame, source: UIView) async {
        do {
            ILOG("EmulatorContainerViewController: Creating emulator core for game: \(game.title) with core: \(core.projectName)")
            // Create emulator core instance
            guard let coreClass = NSClassFromString(core.principleClass) as? PVEmulatorCore.Type else {
                throw GameLaunchingError.generic("Could not create core class")
            }
            
            let emulatorCore = coreClass.init()
            
            // Create the emulator view controller
            let emulatorViewController = PVEmulatorViewController(game: game, core: emulatorCore)
            self.emulatorViewController = emulatorViewController
            
            // Set up quit completion handler
            quitCompletionHandler = { [weak self] in
                ILOG("EmulatorContainerViewController: Quit completion handler called")
                // Clear emulation state
                AppState.shared.emulationUIState.core = nil
                AppState.shared.emulationUIState.emulator = nil
                
                // Return to main scene
                SceneCoordinator.shared.closeEmulator()
            }
            
            // Store in app state
            AppState.shared.emulationUIState.emulator = emulatorViewController
            AppState.shared.emulationUIState.core = emulatorCore
            
            // Present the emulator view controller
            addChild(emulatorViewController)
            emulatorViewController.view.frame = view.bounds
            emulatorViewController.view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
            view.addSubview(emulatorViewController.view)
            emulatorViewController.didMove(toParent: self)
            
            // Initialize the emulator
            ILOG("EmulatorContainerViewController: Initializing core")
            emulatorViewController.initCore()
            
        } catch {
            ELOG("EmulatorContainerViewController: Failed to load emulator: \(error.localizedDescription)")
            displayAndLogError(withTitle: "Error", message: "Failed to load emulator: \(error.localizedDescription)", customActions: nil)
        }
    }
    

    
    private func handleGameLaunchingError(_ error: GameLaunchingError, forGame game: PVGame) {
        switch error {
        case .missingBIOSes(let missingBIOSes):
            let message = "Missing required BIOS files: \(missingBIOSes.joined(separator: ", "))"
            displayAndLogError(withTitle: "Missing BIOS Files", message: message, customActions: nil)
        case .systemNotFound:
            displayAndLogError(withTitle: "System Not Found", message: "The system for \(game.title) could not be found.", customActions: nil)
        case .generic(let message):
            displayAndLogError(withTitle: "Error", message: message, customActions: nil)
        }
    }
}


