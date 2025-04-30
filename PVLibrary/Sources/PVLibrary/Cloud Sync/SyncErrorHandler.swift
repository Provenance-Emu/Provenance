//
//  SyncErrorHandler.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging


/// Protocol for handling sync errors
public protocol SyncErrorHandler {
    /// Get all error summaries
    var allErrorSummaries: [String] { get async throws }
    
    /// Get all full errors
    var allFullErrors: [String] { get async throws }
    
    /// Get all errors
    var allErrors: [iCloudSyncError] { get async }

    /// true if number of errors is 0 and false otherwise
    var isEmpty: Bool { get async }
    
    /// Number of errors
    var numberOfErrors: Int { get async }
    
    /// Handle an error with a file
    /// - Parameters:
    ///   - error: The error to handle
    ///   - file: The file associated with the error
    func handleError(_ error: Error, file: URL?) async
    
    /// Clear all errors
    func clear() async
    
    /// Handle an error with optional context
    /// - Parameter error: The error to handle
    func handle(error: Error) async
}
