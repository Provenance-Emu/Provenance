//
//  CloudSyncErrorHandler.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation
import Combine

/// Error handler for sync errors
public actor CloudSyncErrorHandler: SyncErrorHandler {
    /// Number of errors
    public var numberOfErrors: Int {
        get async {
            await errors.count
        }
    }
    static let shared = CloudSyncErrorHandler()
    private let errors = ConcurrentQueue<iCloudSyncError>()
    
    /// Initialize a new error handler
    public init() {
        // Initialize the error handler
    }
    
    /// Handle an error
    /// - Parameter error: The error to handle
    public func handle(error: any Error) async {
        await handleError(error, file: nil)
    }
    
    /// Handle an error with a file
    /// - Parameters:
    ///   - error: The error to handle
    ///   - file: The file associated with the error
    public func handleError(_ error: any Error, file: URL?) async {
        ELOG("Cloud sync error: \(error.localizedDescription) for file: \(file?.lastPathComponent ?? "unknown")")
        await errors.enqueue(entry: iCloudSyncError(file: file?.pathDecoded, error: error))
    }
    
    /// Clear all errors
    public func clear() async {
        await errors.clear()
    }
    
    /// Get all error summaries
    public var allErrorSummaries: [String] {
        get async throws {
            await try errors.map { $0.summary }
        }
    }
    
    /// Get all full errors
    public var allFullErrors: [String] {
        get async throws {
            await try errors.map { "\($0.error)" }
        }
    }
    
    /// Get all errors
    public var allErrors: [iCloudSyncError] {
        get async {
            await errors.allElements
        }
    }
    
    public var isEmpty: Bool {
        get async {
            await errors.isEmpty
        }
    }
}
