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
}

/// CloudKit retry strategy for handling transient errors
public enum CloudKitRetryStrategy {
    /// Retry as `SyncRetryPolicy` (PVCloudSync) decides
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
                    await progressTracker?.updateProgress(Double(retryCount) / Double(maxRetries) * 0.5)
                    Task { @MainActor in
                        progressTracker?.currentOperation += " (Retry \(retryCount)/\(maxRetries))"
                    }
                }
                
                return try await operation()
            } catch let error as CKError {
                lastError = error
                
                // The shared policy: the server's retry-after when it gives one, otherwise
                // exponential backoff, and no retry for errors that cannot succeed.
                guard let delay = CloudSyncSafetyNet.retryDelay(
                    after: error,
                    attempt: retryCount + 1,
                    maximumAttempts: maxRetries
                ) else {
                    ELOG("CloudKit operation not retried: \(error.localizedDescription)")
                    throw error
                }
                retryCount += 1
                DLOG("Retrying CloudKit operation in \(delay)s (\(retryCount)/\(maxRetries)): \(error.localizedDescription)")
                Task { @MainActor in
                    progressTracker?.currentOperation = "Waiting to retry... (\(Int(delay))s)"
                }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
