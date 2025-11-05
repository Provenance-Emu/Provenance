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

    // Sync status manager for showing progress during game launch
    @Published public var syncStatusManager = GameSyncStatusManager()

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

        ILOG("skins: Setting SkinImporterInjector service to DeltaSkinManager.shared in SceneCoordinator")
        SkinImporterInjector.shared.service = DeltaSkinManager.shared
        ILOG("skins: SkinImporterInjector service set in SceneCoordinator")

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

    /// Launch a specific game with error handling and sync validation
    public func launchGame(_ game: PVGame) {
        ILOG("SceneCoordinator: Launching game: \(game.title) (ID: \(game.id))")

        // Validate and sync game before launch
        Task { @MainActor in
            await launchGameWithValidation(game)
        }
    }

    /// Launch game with sync validation
    private func launchGameWithValidation(_ game: PVGame) async {
        // Show sync status overlay
        syncStatusManager.show(
            gameTitle: game.title,
            statusMessage: "Checking game file...",
            onCancel: { [weak self] in
                self?.syncStatusManager.hide()
                self?.openMainScene()
            }
        )

        // Create validator if cloud sync is enabled
        let validator: GameSyncValidator?
        if Defaults[.iCloudSync] {
            validator = GameSyncValidator(cloudSyncManager: CloudSyncManager.shared)
        } else {
            validator = nil
        }

        // Validate game availability
        if let validator = validator {
            let isValid = await validator.ensureGameReady(game) { [weak self] progressMessage in
                Task { @MainActor in
                    self?.syncStatusManager.update(statusMessage: progressMessage)
                }
                ILOG("Game sync progress: \(progressMessage)")
            }

            if isValid {
                syncStatusManager.complete()
            } else {
                syncStatusManager.error("Game file is not available. Please ensure iCloud sync is enabled and the game is synced.")
                // Show error alert after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Cannot Launch Game",
                        message: "The game file is not available on this device.\n\nTo fix this:\n1. Make sure iCloud sync is enabled in Settings\n2. Wait for the game to finish syncing (check the cloud icon)\n3. Try launching again\n\nIf the problem persists, try removing and re-importing the game."
                    )
                }
                return
            }
        } else {
            // No cloud sync - just verify file exists
            syncStatusManager.update(statusMessage: "Verifying file...")

            guard let fileURL = game.file?.url,
                  FileManager.default.fileExists(atPath: fileURL.path) else {
                syncStatusManager.error("Game file not found. Please verify the ROM file exists.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.syncStatusManager.hide()
                    self?.showGameLaunchError(
                        title: "Game File Not Found",
                        message: "The game file could not be found on your device.\n\nThis can happen if:\n• The file was deleted\n• The file was moved\n• There's a storage issue\n\nTry removing the game from your library and re-importing it."
                    )
                }
                return
            }

            syncStatusManager.complete()
        }

        // Small delay to show completion status
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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
            showGameLaunchError(
                title: "Failed to Launch Game",
                message: "Could not prepare the game for launch. This may be due to:\n\n• Missing or corrupted game file\n• Core not available or failed to load\n• Insufficient memory\n\nTry restarting the app, or remove and re-import the game if the problem persists."
            )
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

        // Reset the app open action FIRST to prevent any reopening attempts
        AppState.shared.appOpenAction = .none
        ILOG("SceneCoordinator: Reset appOpenAction to .none when closing emulator")

        // Clear the emulation state
        AppState.shared.emulationUIState.core = nil
        AppState.shared.emulationUIState.emulator = nil
        AppState.shared.emulationUIState.currentGame = nil
        ILOG("SceneCoordinator: Cleared emulation state")

        // Return to the main scene
        ILOG("SceneCoordinator: Calling openMainScene()")
        openMainScene()
        ILOG("SceneCoordinator: closeEmulator() completed")
    }
}
