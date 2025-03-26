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

/// Coordinator for managing scene transitions in the app
@MainActor
public class SceneCoordinator: ObservableObject {
    public static let shared = SceneCoordinator()
    
    private init() {}
    
    public enum Scenes {
        case main
        case emulator
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
        
        ILOG("SceneCoordinator: Opening main scene")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Opens the emulator scene with the current game from AppState
    public func openEmulatorScene() {
        guard let url = URL(string: "provenance://emulator") else {
            ELOG("Failed to create URL for emulator scene")
            return
        }
        
        ILOG("SceneCoordinator: Opening emulator scene")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Returns to the main scene
    public func returnToMainScene() {
        guard let url = URL(string: "provenance://main") else {
            ELOG("Failed to create URL for main scene")
            return
        }
        
        ILOG("SceneCoordinator: Returning to main scene")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    /// Handles closing the emulator and returning to the main scene
    public func closeEmulator() {
        // Clear the emulation state
        AppState.shared.emulationUIState.core = nil
        AppState.shared.emulationUIState.emulator = nil
        AppState.shared.emulationUIState.currentGame = nil
        
        // Return to the main scene
        returnToMainScene()
    }
}
