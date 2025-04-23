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
        case initializingLibrary
        case completed
        case error(Error)

        /// Custom equality check for State enum
        public static func == (lhs: AppBootupState.State, rhs: AppBootupState.State) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted),
                 (.initializingDatabase, .initializingDatabase),
                 (.databaseInitialized, .databaseInitialized),
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
                return "Not Started"
            case .initializingDatabase:
                return "Initializing Database"
            case .databaseInitialized:
                return "Database Initialized"
            case .initializingLibrary:
                return "Initializing Library"
            case .completed:
                return "Bootup Completed"
            case .error(let error):
                return "Error with library: \(error.localizedDescription)"
            }
        }

        /// Whether the state is an error state
        public var isErrorState: Bool {
            if case .error = self {
                return true
            }
            return false
        }
    }

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
