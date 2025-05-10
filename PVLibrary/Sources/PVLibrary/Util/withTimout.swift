//
//  withTimout.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Execute an async operation with a timeout
/// - Parameters:
///   - timeout: Timeout in nanoseconds
///   - operation: The async operation to execute
/// - Throws: TimeoutError if the operation times out, or any error thrown by the operation
func withTimeout<T>(timeout: UInt64, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }
        
        // Add a timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: timeout)
            throw TimeoutError()
        }
        
        // Return the first result or throw the first error
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
