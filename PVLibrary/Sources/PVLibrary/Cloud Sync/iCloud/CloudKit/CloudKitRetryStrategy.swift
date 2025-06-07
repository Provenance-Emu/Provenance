//
//  CloudKitRetryStrategy.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging

/// Extension to identify recoverable CloudKit errors
extension CKError {
    /// Check if this error is recoverable with a retry
    public var isRecoverableCloudKitError: Bool {
        switch self.code {
        case .networkFailure,
             .networkUnavailable,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy,
             .resultsTruncated:
            return true
        default:
            return false
        }
    }
    
    /// Get a recommended retry delay for this error
    public var recommendedRetryDelay: TimeInterval {
        if let retryAfter = self.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return retryAfter
        }
        
        // Default delays based on error type
        switch self.code {
        case .requestRateLimited:
            return 5.0
        case .zoneBusy:
            return 3.0
        case .serviceUnavailable:
            return 2.0
        case .networkFailure, .networkUnavailable:
            return 1.0
        default:
            return 1.0
        }
    }
}

/// CloudKit retry strategy for handling transient errors
public enum CloudKitRetryStrategy {
    /// Retry with exponential backoff
    /// - Parameters:
    ///   - operation: The CloudKit operation to retry
    ///   - maxRetries: Maximum number of retry attempts
    ///   - progressTracker: Optional progress tracker for UI updates
    /// - Returns: The result of the operation
    public static func retryCloudKitOperation<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int = 3,
        progressTracker: SyncProgressTracker? = nil
    ) async throws -> T {
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                // If we're retrying, update the progress tracker
                if retryCount > 0 && progressTracker != nil {
                    progressTracker?.updateProgress(Double(retryCount) / Double(maxRetries) * 0.5)
                    progressTracker?.currentOperation += " (Retry \(retryCount)/\(maxRetries))"
                }
                
                return try await operation()
            } catch let error as CKError {
                lastError = error
                
                // Only retry for specific error codes that are recoverable
                if error.isRecoverableCloudKitError {
                    retryCount += 1
                    
                    // Log the retry attempt
                    DLOG("""
                         Retrying CloudKit operation after error: \(error.localizedDescription)
                         Retry \(retryCount)/\(maxRetries)
                         """)
                    
                    // Use the recommended delay or exponential backoff
                    let delay = error.recommendedRetryDelay
                    
                    // Update progress tracker if available
                    progressTracker?.currentOperation = "Waiting to retry... (\(Int(delay))s)"
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Non-recoverable error
                    ELOG("Non-recoverable CloudKit error: \(error.localizedDescription)")
                    throw error
                }
            } catch {
                // Other non-CloudKit error
                ELOG("Non-CloudKit error: \(error.localizedDescription)")
                throw error
            }
        }
        
        // If we've exhausted all retries
        ELOG("CloudKit operation failed after \(maxRetries) retries")
        throw lastError!
    }
}
