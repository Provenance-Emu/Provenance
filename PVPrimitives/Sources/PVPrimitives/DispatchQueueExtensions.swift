//
//  DispatchQueueExtensions.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

// Actor to safely track tokens that have been executed
private actor OnceTracker {
    // Singleton instance
    static let shared = OnceTracker()
    
    // Set of tokens that have been executed
    private var executedTokens: Set<String> = []
    
    // Check if a token has been executed and mark it as executed if not
    func checkAndMarkExecuted(_ token: String) -> Bool {
        if executedTokens.contains(token) {
            return false
        }
        
        executedTokens.insert(token)
        return true
    }
}

/// Extensions for DispatchQueue
public extension DispatchQueue {
    /// Execute a block of code only once during the lifetime of the application
    /// - Parameters:
    ///   - token: A unique token to identify this execution
    ///   - block: The block to execute
    static func once(token: String, block: @escaping @Sendable () -> Void) {
        // Create a detached task to handle the async actor call
        Task.detached { 
            // Check if the token has been executed before
            if await OnceTracker.shared.checkAndMarkExecuted(token) {
                // If not, execute the block on the main actor
                await MainActor.run {
                    block()
                }
            }
        }
    }
}
