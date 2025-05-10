//
//  TestSceneCoordinator.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import Foundation
import SwiftUI
import PVUIBase
import PVLibrary
import PVLogging
import Combine

/// A custom scene coordinator for the UITesting app that doesn't use URL schemes
@MainActor
public class TestSceneCoordinator: ObservableObject {
    public static let shared = TestSceneCoordinator()
    
    // Published property to track which scene should be shown
    @Published public var currentScene: Scene = .main
    
    // Track whether we should show the emulator
    @Published public var showEmulator: Bool = false
    
    // Cancellables for observation
    private var cancellables = Set<AnyCancellable>()
    
    public enum Scene {
        case main
        case emulator
    }
    
    private init() {
        // Observe the EmulationUIState for changes to currentGame
        AppState.shared.$emulationUIState
            .map { $0.currentGame != nil }
            .removeDuplicates()
            .sink { [weak self] hasGame in
                guard let self = self else { return }
                if hasGame {
                    ILOG("TestSceneCoordinator: Game detected in EmulationUIState, showing emulator scene")
                    self.showEmulator = true
                    self.currentScene = .emulator
                } else {
                    ILOG("TestSceneCoordinator: No game detected in EmulationUIState, returning to main scene")
                    self.showEmulator = false
                    self.currentScene = .main
                }
            }
            .store(in: &cancellables)
    }
    
    /// Opens the main scene
    public func openMainScene() {
        ILOG("TestSceneCoordinator: Opening main scene")
        currentScene = .main
        showEmulator = false
    }
    
    /// Opens the emulator scene
    public func openEmulatorScene() {
        ILOG("TestSceneCoordinator: Opening emulator scene")
        currentScene = .emulator
        showEmulator = true
    }
    
    /// Launch a specific game
    public func launchGame(_ game: PVGame) {
        ILOG("TestSceneCoordinator: Launching game: \(game.title) (ID: \(game.id))")
        
        // Set the current game in EmulationUIState
        AppState.shared.emulationUIState.currentGame = game
        
        // Verify the game was set correctly
        if let currentGame = AppState.shared.emulationUIState.currentGame {
            ILOG("TestSceneCoordinator: Successfully set current game in EmulationUIState: \(currentGame.title) (ID: \(currentGame.id))")
            
            // Open the emulator scene
            openEmulatorScene()
        } else {
            ELOG("TestSceneCoordinator: Failed to set current game in EmulationUIState")
        }
    }
    
    /// Handles closing the emulator and returning to the main scene
    public func closeEmulator() {
        ILOG("TestSceneCoordinator: Closing emulator")
        
        // Clear the emulation state
        AppState.shared.emulationUIState.core = nil
        AppState.shared.emulationUIState.emulator = nil
        AppState.shared.emulationUIState.currentGame = nil
        
        // Return to the main scene
        openMainScene()
    }
}
