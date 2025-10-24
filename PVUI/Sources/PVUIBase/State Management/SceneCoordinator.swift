//
//  SceneCoordinator.swift
//  PVUI
//
//  Created on 2025-03-25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit
import PVLogging
import PVLibrary
import Combine

// DeltaSkinManager already "conforms" to but does not
// know about SkinImporterServicing, since that's in PVLibrary
// and we don't want to require that dependency
extension DeltaSkinManager: SkinImporterServicing {

}

/// Coordinator for managing scene transitions in the app
@MainActor
public class SceneCoordinator: ObservableObject {
    public static let shared = SceneCoordinator()

    // Track whether we should show the emulator
    @Published public var showEmulator: Bool = false

    // Cancellables for observation
    private var cancellables = Set<AnyCancellable>()

    public enum Scenes {
        case main
        case emulator
    }

    // Published property to track which scene should be shown
    @Published public var currentScene: Scenes = .main

    private init() {
        // Observe the EmulationUIState for changes to currentGame
        AppState.shared.$emulationUIState
            .map { $0.currentGame != nil }
            .removeDuplicates()
            .sink { [weak self] hasGame in
                guard let self = self else { return }
                if hasGame {
                    ILOG("SceneCoordinator: Game detected in EmulationUIState, showing emulator scene")
                    self.showEmulator = true
                    self.currentScene = .emulator
                } else {
                    ILOG("SceneCoordinator: No game detected in EmulationUIState, returning to main scene")
                    self.showEmulator = false
                    self.currentScene = .main
                }
            }
            .store(in: &cancellables)
    }

    public func open(scene: Scenes) {
        switch scene {
        case .main:
            openMainScene()
        case .emulator:
            openEmulatorScene()
        }
    }

    public func openMainScene() {
        guard let url = URL(string: "provenance://main") else {
            ELOG("Failed to create URL for main scene")
            return
        }

        SkinImporterInjector.shared.service = DeltaSkinManager.shared

        ILOG("SceneCoordinator: Opening main scene")
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        ILOG("SceneCoordinator: Setting currentScene = .main and showEmulator = false")
        currentScene = .main
        showEmulator = false
        ILOG("SceneCoordinator: Main scene state updated - currentScene: \(currentScene), showEmulator: \(showEmulator)")
    }

    /// Opens the emulator scene with the current game from AppState
    public func openEmulatorScene() {
//        guard let url = URL(string: "provenance://emulator") else {
//            ELOG("Failed to create URL for emulator scene")
//            return
//        }
//
//        ILOG("SceneCoordinator: Opening emulator scene")
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        ILOG("SceneCoordinator: Opening emulator scene")
        currentScene = .emulator
        showEmulator = true
    }

    /// Launch a specific game with error handling
    public func launchGame(_ game: PVGame) {
        ILOG("SceneCoordinator: Launching game: \(game.title) (ID: \(game.id))")

        // Set the current game in EmulationUIState
        AppState.shared.emulationUIState.currentGame = game

        // Verify the game was set correctly
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("SceneCoordinator: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")

            // Open the emulator scene - errors will be handled by PVEmulatorViewController
            openEmulatorScene()
        } else {
            ELOG("SceneCoordinator: Failed to set current game in EmulationUIState")
            // Show error and stay in main scene
            showGameLaunchError(title: "Failed to Launch Game", message: "Could not prepare game for launch.")
        }
    }

    /// Show error alert for game launch failures and return to main scene
    private func showGameLaunchError(title: String, message: String) {
        // Ensure we're on the main scene
        openMainScene()

        // Show error alert
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {

                let alert = UIAlertController(
                    title: title,
                    message: message,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

                rootViewController.present(alert, animated: true)
            }
        }
    }

    /// Handles closing the emulator and returning to the main scene
    public func closeEmulator() {
        ILOG("SceneCoordinator: closeEmulator() called")

        // Clear the emulation state
        AppState.shared.emulationUIState.core = nil
        AppState.shared.emulationUIState.emulator = nil
        AppState.shared.emulationUIState.currentGame = nil
        ILOG("SceneCoordinator: Cleared emulation state")

        // Reset the app open action to prevent reopening the same game
        AppState.shared.appOpenAction = .none
        ILOG("SceneCoordinator: Reset appOpenAction to .none when closing emulator")

        // Return to the main scene
        ILOG("SceneCoordinator: Calling openMainScene()")
        openMainScene()
        ILOG("SceneCoordinator: closeEmulator() completed")
    }
}
