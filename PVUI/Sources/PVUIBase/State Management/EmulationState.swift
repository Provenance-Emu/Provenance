//
//  EmulationState.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import PVEmulatorCore
import PVCoreBridge
import SwiftUI
import PVLogging
import Perception

@MainActor
//@Observable
@Perceptible
public final class EmulationUIState : ObservableObject {
    public var core: PVEmulatorCore? {
        didSet {
            DLOG("Set core to \(core?.debugDescription ?? "nil")")
        }
    }
    public var emulator: PVEmualatorControllerProtocol?
    public var isInBackground: Bool = false
    
    /// The current game that should be loaded in the emulator scene
    public var currentGame: PVGame? = nil
    
    public func reset() -> (PVEmulatorCore?, PVEmualatorControllerProtocol?, PVGame?) {
        defer {
            core = nil
            emulator = nil
            currentGame = nil
        }
        return (core, emulator, currentGame)
    }
    
    /// Update state
//    public func update(_ update: (inout EmulationUIState) -> Void) {
//        var newState = state
//        update(&newState)
//        state = newState
//    }
}
