//
//  AppBootupState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import Observation
import PVLogging

/// A class to manage the bootup state of the application
@MainActor
//@Observable
public class AppBootupState: ObservableObject {
    /// Enum representing different states during the bootup process
    public enum State: Equatable {
        case notStarted
        case initializingDatabase
        case databaseInitialized
        case scanningCores
        case initializingLibrary
        case completed
        case error(Error)

        /// Custom equality check for State enum
        public static func == (lhs: AppBootupState.State, rhs: AppBootupState.State) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.initializingDatabase, .initializingDatabase),
                 (.databaseInitialized, .databaseInitialized),
                 (.scanningCores, .scanningCores),
                 (.initializingLibrary, .initializingLibrary),
                 (.completed, .completed):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }

        /// Computed property to get a human-readable description of the state
        public var localizedDescription: String {
            switch self {
            case .notStarted:
                return "Starting..."
            case .initializingDatabase:
                return "Preparing database..."
            case .databaseInitialized:
                return "Loading game library..."
            case .scanningCores:
                return "Scanning emulator cores..."
            case .initializingLibrary:
                return "Scanning games..."
            case .completed:
                return "Ready"
            case .error(let error):
                let errorMsg = error.localizedDescription
                if errorMsg.contains("database") || errorMsg.contains("realm") {
                    return "Database error. Try restarting the app. If the problem persists, check available storage space."
                } else if errorMsg.contains("permission") || errorMsg.contains("access") {
                    return "Permission error. Check app permissions in Settings."
                } else {
                    return "Loading error: \(errorMsg). Try restarting the app."
                }
            }
        }

        /// Whether the state is an error state
        public var isErrorState: Bool {
            if case .error = self {
                return true
            }
            return false
        }

        /// Deterministic progress fraction (0.0–1.0) for this boot stage.
        ///
        /// Use this to drive real progress UI instead of fake animations.
        /// Intermediate values between states can be supplied via
        /// ``AppBootupState/updateTaskProgress(_:fraction:)`` for finer-grained
        /// reporting within a stage.
        public var baseProgress: Double {
            switch self {
            case .notStarted:             return 0.0
            case .initializingDatabase:   return 0.05
            case .databaseInitialized:    return 0.15
            case .scanningCores:          return 0.20
            case .initializingLibrary:    return 0.55
            case .completed:              return 1.0
            case .error:                  return 0.0
            }
        }
    }

    /// The name of the task currently executing, suitable for display in the boot UI.
    @Published public private(set) var currentTaskName: String = ""

    /// Real boot progress in the range 0.0–1.0.
    ///
    /// Automatically advances to ``State/baseProgress`` on each state transition.
    /// Call ``updateTaskProgress(_:fraction:)`` for sub-step granularity within a stage.
    @Published public private(set) var stateProgress: Double = 0.0

    /// Optional secondary detail line shown below `currentTaskName` during slow sub-steps.
    ///
    /// Set via ``updateSubTask(_:progress:)``. Cleared automatically on each state transition.
    @Published public private(set) var subTaskMessage: String = ""

    /// Fine-grained progress 0.0–1.0 within the current sub-task.
    ///
    /// `nil` hides the secondary progress bar in the boot UI.
    /// Set via ``updateSubTask(_:progress:)``. Cleared automatically on each state transition.
    @Published public private(set) var subTaskProgress: Double? = nil

    /// The current state of the bootup process
    @Published public private(set) var currentState: State = .notStarted {
        willSet {
            objectWillChange.send()
        }
        didSet {
            ILOG("Did set currentState to \(currentState.localizedDescription)")
            if currentState == .completed {
                isBootupCompleted = true
                /// Force a UI update
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
    }

    /// Whether the bootup process has completed
    @Published public private(set) var isBootupCompleted = false {
        willSet {
            objectWillChange.send()
        }
    }

    /// Update the secondary detail line shown below the main task name.
    ///
    /// Call this for long-running sub-phases (e.g., libretro core probing) to surface
    /// progress to the user. Cleared automatically when ``transition(to:)`` is called.
    ///
    /// - Parameters:
    ///   - message: Human-readable description (e.g., `"Probing snes9x_libretro… 3/24"`).
    ///   - progress: Optional fine-grained progress 0.0–1.0, or `nil` to hide the bar.
    public func updateSubTask(_ message: String, progress: Double? = nil) {
        subTaskMessage = message
        subTaskProgress = progress
        objectWillChange.send()
    }

    /// Update the displayed task name and optional sub-step progress within the current stage.
    ///
    /// - Parameters:
    ///   - taskName: Human-readable name of the current sub-task (e.g. "Scanning ROMs…").
    ///   - fraction: Fine-grained progress 0.0–1.0 within the current boot stage.
    ///     The final ``stateProgress`` value is interpolated between the current
    ///     state's ``State/baseProgress`` and the next stage's base progress.
    public func updateTaskProgress(_ taskName: String, fraction: Double = 0.0) {
        currentTaskName = taskName
        let base = currentState.baseProgress
        let next = nextStateBaseProgress(after: currentState)
        stateProgress = base + (next - base) * max(0, min(1, fraction))
        objectWillChange.send()
    }

    /// Returns the base progress of the state that follows `state` in the normal
    /// boot sequence (used for interpolating sub-step progress).
    private func nextStateBaseProgress(after state: State) -> Double {
        switch state {
        case .notStarted:           return State.initializingDatabase.baseProgress
        case .initializingDatabase: return State.databaseInitialized.baseProgress
        case .databaseInitialized:  return State.scanningCores.baseProgress
        case .scanningCores:        return State.initializingLibrary.baseProgress
        case .initializingLibrary:  return State.completed.baseProgress
        case .completed, .error:    return state.baseProgress
        }
    }

    /// Function to transition to a new state
    public func transition(to state: State) {
        // Check if we're trying to transition when already completed
        // Allow error transitions even if completed
        guard !isBootupCompleted || state.isErrorState else {
            ELOG("Transition to state \(state.localizedDescription) while bootup is already completed")
            return
        }

        if state != currentState {
            ILOG("AppBootupState: Transitioning from \(currentState.localizedDescription) to \(state.localizedDescription)")

            // Advance progress to the new state's base value
            stateProgress = state.baseProgress
            currentTaskName = state.localizedDescription

            // Clear sub-task detail when entering a new stage
            subTaskMessage = ""
            subTaskProgress = nil

            // Update the state
            currentState = state

            // Force UI updates by sending objectWillChange multiple times with delays
            objectWillChange.send()

            // Schedule additional notifications for important state transitions
            switch state {
            case .completed:
                // For completed state, use more aggressive refresh strategy
                ILOG("AppBootupState: Completed state reached, using aggressive refresh strategy")

                // Send multiple notifications with different delays
                for delay in [0.05, 0.1, 0.2, 0.5, 1.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        ILOG("AppBootupState: Sending delayed notification at \(delay)s")
                        self.objectWillChange.send()
                    }
                }

                // Post a notification that other components can listen for
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("BootupCompleted"), object: nil)
                }

            case .databaseInitialized:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.objectWillChange.send()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.objectWillChange.send()
                }

            default:
                break
            }
        }
    }
}
