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
            case (let error):
                return "Error with library: \(error)"
            }
        }
    }

    /// The current state of the bootup process
    @Published public  private(set) var currentState: State = .notStarted {
        didSet {
            if currentState == .completed {
                isBootupCompleted = true
            }
        }
    }

    /// Whether the bootup process has completed
    @Published public private(set) var isBootupCompleted = false

    /// Function to transition to a new state
    public func transition(to state: State) {
        guard !isBootupCompleted else { return }
        currentState = state
    }
}
