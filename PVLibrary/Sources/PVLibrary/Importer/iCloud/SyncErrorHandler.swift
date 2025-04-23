//
//  SyncErrorHandler.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Error struct for iCloud sync errors
public struct iCloudSyncError {
    /// The file associated with the error, if any
    let file: String?
    
    /// Summary of the error
    var summary: String {
        error.localizedDescription
    }
    
    /// The underlying error
    let error: Error
}

/// Protocol for handling sync errors
public protocol SyncErrorHandler {
    /// Get all error summaries
    var allErrorSummaries: [String] { get throws }
    
    /// Get all full errors
    var allFullErrors: [String] { get throws }
    
    /// Get all errors
    var allErrors: [iCloudSyncError] { get }
    
    /// Number of errors
    var numberOfErrors: Int { get }
    
    /// Handle an error with a file
    /// - Parameters:
    ///   - error: The error to handle
    ///   - file: The file associated with the error
    func handleError(_ error: Error, file: URL?)
    
    /// Clear all errors
    func clear()
    
    /// Handle an error with optional context
    /// - Parameter error: The error to handle
    func handle(error: Error)
}
