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
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let containerVC = EmulatorContainerViewController()
        context.coordinator.containerViewController = containerVC
        
        // Check if we have a game to launch
        if let game = appState.emulationUIState.currentGame {
            ILOG("EmulatorContainerView: Found game to launch: \(game.title)")
            Task {
                await containerVC.load(game, sender: nil, core: nil, saveState: nil)
            }
        } else {
            WLOG("EmulatorContainerView: No game found to launch")
        }
        
        return containerVC
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
        // Implementation of core selection presentation
        guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
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
    
    @MainActor
    func load(_ game: PVGame, sender: Any?, core: PVCore?, saveState: PVSaveState?) async {
        do {
            try await canLoad(game)
            
            // Store the game in the app state
            AppState.shared.emulationUIState.currentGame = game
            
            ILOG("EmulatorContainerViewController: Loading game: \(game.title)")
            
            // If a core is specified, use it, otherwise use the default core or present core selection
            if let core = core {
                ILOG("EmulatorContainerViewController: Using specified core: \(core.projectName)")
                await presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? view)
            } else if let saveState = saveState, let core = saveState.core {
                ILOG("EmulatorContainerViewController: Using core from save state: \(core.projectName)")
                await presentEMU(withCore: core, forGame: game, source: sender as? UIView ?? view)
                
                // Load the save state after the emulator is initialized
                if let emulatorVC = self.emulatorViewController {
                    await emulatorVC.loadSaveState(saveState)
                }
            } else if let system = game.system, let defaultCore = system.cores.first {
                ILOG("EmulatorContainerViewController: Using default core: \(defaultCore.projectName)")
                await presentEMU(withCore: defaultCore, forGame: game, source: sender as? UIView ?? view)
            } else {
                ILOG("EmulatorContainerViewController: No core specified, presenting core selection")
                presentCoreSelection(forGame: game, sender: sender)
            }
            
            // Update recent games
            updateRecentGames(game)
            
        } catch let error as GameLaunchingError {
            handleGameLaunchingError(error, forGame: game)
        } catch {
            displayAndLogError(withTitle: "Error", message: "An unknown error occurred: \(error.localizedDescription)", customActions: nil)
        }
    }
    
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


