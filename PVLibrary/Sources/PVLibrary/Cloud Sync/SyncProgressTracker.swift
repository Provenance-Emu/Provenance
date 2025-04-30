//
//  SyncProgressTracker.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import PVLogging

/// A singleton class to track CloudKit sync progress across the app
public class SyncProgressTracker: ObservableObject {
    /// Shared instance for app-wide access
    public static let shared = SyncProgressTracker()
    
    // MARK: - Properties
    
    /// Current operation being performed
    @Published public var currentOperation: String = ""
    
    /// Progress of the current operation (0.0 to 1.0)
    @Published public var progress: Double = 0
    
    /// Whether a sync operation is currently active
    @Published public var isActive: Bool = false
    
    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Subject for throttling progress updates
    private var progressSubject = PassthroughSubject<Double, Never>()
    
    /// Task that can be cancelled when an operation is stopped
    private var currentTask: Task<Void, Error>?
    
    // MARK: - Initialization
    
    private init() {
        setupProgressThrottling()
    }
    
    // MARK: - Public Methods
    
    /// Start tracking a new sync operation
    /// - Parameter operation: Description of the operation being performed
    public func startTracking(operation: String) {
        DLOG("Starting CloudKit operation: \(operation)")
        currentOperation = operation
        isActive = true
        progress = 0
    }
    
    /// Update the progress of the current operation
    /// - Parameter newProgress: Progress value between 0.0 and 1.0
    public func updateProgress(_ newProgress: Double) {
        progressSubject.send(min(max(newProgress, 0.0), 1.0))
    }
    
    /// Mark the current operation as complete
    public func completeOperation() {
        DLOG("Completed CloudKit operation: \(currentOperation)")
        progress = 1.0
        
        // Small delay before hiding to allow UI to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isActive = false
            self?.currentOperation = ""
            self?.progress = 0
        }
    }
    
    /// Cancel the current operation
    public func cancelOperation() {
        DLOG("Cancelled CloudKit operation: \(currentOperation)")
        currentTask?.cancel()
        currentTask = nil
        
        isActive = false
        currentOperation = ""
        progress = 0
    }
    
    /// Track an async operation with progress updates
    /// - Parameters:
    ///   - operation: Description of the operation
    ///   - task: The async task to execute
    /// - Returns: The result of the task
    public func trackOperation<T>(
        operation: String,
        task: @escaping (SyncProgressTracker) async throws -> T
    ) async throws -> T {
        // Cancel any existing operation
        cancelOperation()
        
        // Start tracking the new operation
        startTracking(operation: operation)
        
        do {
            // Create a new task that can be cancelled
            let result = try await task(self)
            completeOperation()
            return result
        } catch {
            // Handle errors
            ELOG("Error in CloudKit operation '\(operation)': \(error.localizedDescription)")
            isActive = false
            currentOperation = ""
            progress = 0
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Setup throttling for progress updates to avoid UI jank
    private func setupProgressThrottling() {
        progressSubject
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] newProgress in
                self?.progress = newProgress
            }
            .store(in: &cancellables)
    }
}
