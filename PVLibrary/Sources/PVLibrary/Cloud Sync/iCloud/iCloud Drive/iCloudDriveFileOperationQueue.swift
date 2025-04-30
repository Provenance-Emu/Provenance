//
//  FileOperationQueue.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// An actor to manage concurrent file operations with a limited queue
public actor iCloudDriveFileOperationQueue {
    private var operations: [FileOperation] = []
    private var runningOperations: Int = 0
    private let maxConcurrentOperations: Int
    private var isProcessing = false
    
    struct FileOperation: Identifiable {
        let id = UUID()
        let sourceFile: URL
        let destFile: URL
        let priority: TaskPriority
        let completion: (Bool) -> Void
    }
    
    init(maxConcurrentOperations: Int = 3) {
        self.maxConcurrentOperations = maxConcurrentOperations
    }
    
    /// Add a file operation to the queue
    func addOperation(sourceFile: URL, destFile: URL, priority: TaskPriority = .medium, completion: @escaping (Bool) -> Void) {
        let operation = FileOperation(sourceFile: sourceFile, destFile: destFile, priority: priority, completion: completion)
        operations.append(operation)
        DLOG("Added file operation to queue: \(sourceFile.lastPathComponent) (Queue size: \(operations.count))")
        
        if !isProcessing {
            processQueue()
        }
    }
    
    /// Process the queue of file operations
    private func processQueue() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            while !operations.isEmpty && runningOperations < maxConcurrentOperations {
                let operation = operations.removeFirst()
                runningOperations += 1
                
                Task(priority: operation.priority) {
                    let success = await iCloudDriveSync.moveFile(from: operation.sourceFile, to: operation.destFile)
                    await MainActor.run {
                        operation.completion(success)
                    }
                    decrementRunningOperations()
                }
            }
            
            isProcessing = operations.isEmpty && runningOperations == 0
            
            // If we still have operations but hit the concurrent limit, wait for some to complete
            if !operations.isEmpty && runningOperations >= maxConcurrentOperations {
                // Wait a bit and check again
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                processQueue()
            }
        }
    }
    
    /// Decrement the running operations counter and process more if available
    private func decrementRunningOperations() {
        runningOperations -= 1
        if !operations.isEmpty {
            processQueue()
        } else if runningOperations == 0 {
            isProcessing = false
        }
    }
    
    /// Clear all pending operations
    func clearQueue() {
        operations.removeAll()
    }
    
    /// Get the current queue status
    func getQueueStatus() -> (pending: Int, running: Int) {
        return (operations.count, runningOperations)
    }
}
