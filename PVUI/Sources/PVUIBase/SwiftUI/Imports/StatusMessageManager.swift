//
//  StatusMessageManager.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import PVLibrary
// Import the StatusMessageViewModel
import PVUIBase

/// A message to be displayed in the status view
public struct StatusMessage: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let type: MessageType
    public let timestamp = Date()
    public let duration: TimeInterval
    
    public enum MessageType {
        case info
        case success
        case warning
        case error
        case progress
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .progress: return .purple
            }
        }
    }
    
    public init(message: String, type: MessageType = .info, duration: TimeInterval = 5.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
    
    public static func == (lhs: StatusMessage, rhs: StatusMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages status messages for the app
public class StatusMessageManager: ObservableObject {
    public static let shared = StatusMessageManager()
    
    @Published public private(set) var messages: [StatusMessage] = []
    @Published public private(set) var fileRecoveryProgress: (current: Int, total: Int)? = nil
    @Published public private(set) var isImportActive: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var messageTimers: [UUID: Timer] = [:]
    
    /// ViewModel to handle actor isolation
    @MainActor
    public let viewModel = StatusMessageViewModel()
    
    private init() {
        
        Task { @MainActor [weak self] in
            // Set up bindings to the ViewModel
            self?.viewModel.$fileRecoveryProgress
                .receive(on: RunLoop.main)
                .assign(to: &$fileRecoveryProgress)
            
            self?.viewModel.$isImportActive
                .receive(on: RunLoop.main)
                .assign(to: &$isImportActive)
        }
        
        // Subscribe to notifications for file recovery started
        NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryStarted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "Starting file recovery from iCloud Drive...",
                        type: .info,
                        duration: 3.0
                    ))
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to notifications for file recovery completed
        NotificationCenter.default.publisher(for: iCloudSync.iCloudFileRecoveryCompleted)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.addMessage(StatusMessage(
                        message: "File recovery from iCloud Drive completed",
                        type: .success,
                        duration: 5.0
                    ))
                }
            }
            .store(in: &cancellables)
    }
    
    /// Add a new status message
    /// - Parameter message: The message to add
    public func addMessage(_ message: StatusMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Add the message
            self.messages.append(message)
            
            // Set a timer to remove the message after its duration
            let timer = Timer.scheduledTimer(withTimeInterval: message.duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.removeMessage(withID: message.id)
                }
            }
            
            self.messageTimers[message.id] = timer
        }
    }
    
    /// Remove a message by its ID
    /// - Parameter id: The ID of the message to remove
    public func removeMessage(withID id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Remove the message
            self.messages.removeAll { $0.id == id }
            
            // Invalidate and remove the timer
            self.messageTimers[id]?.invalidate()
            self.messageTimers.removeValue(forKey: id)
        }
    }
    
    /// Clear all messages
    public func clearAllMessages() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Invalidate all timers
            for timer in self.messageTimers.values {
                timer.invalidate()
            }
            
            // Clear messages and timers
            self.messages.removeAll()
            self.messageTimers.removeAll()
        }
    }
    
    /// Update the file recovery progress
    /// - Parameters:
    ///   - current: Current number of files processed
    ///   - total: Total number of files to process
    public func updateFileRecoveryProgress(current: Int, total: Int) {
        Task { @MainActor in
            viewModel.fileRecoveryProgress = (current, total)
        }
    }
    
    /// Clear the file recovery progress
    public func clearFileRecoveryProgress() {
        Task { @MainActor in
            viewModel.clearFileRecoveryProgress()
        }
    }
    
    /// Set the import active state
    /// - Parameter active: Whether imports are active
    public func setImportActive(_ active: Bool) {
        Task { @MainActor in
            viewModel.setImportActive(active)
        }
    }
}

// Extension to add convenience methods for different message types
public extension StatusMessageManager {
    /// Add an info message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addInfo(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .info, duration: duration))
    }
    
    /// Add a success message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addSuccess(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .success, duration: duration))
    }
    
    /// Add a warning message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addWarning(_ message: String, duration: TimeInterval = 5.0) {
        addMessage(StatusMessage(message: message, type: .warning, duration: duration))
    }
    
    /// Add an error message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addError(_ message: String, duration: TimeInterval = 8.0) {
        addMessage(StatusMessage(message: message, type: .error, duration: duration))
    }
    
    /// Add a progress message
    /// - Parameters:
    ///   - message: The message text
    ///   - duration: How long to display the message
    func addProgress(_ message: String, duration: TimeInterval = 3.0) {
        addMessage(StatusMessage(message: message, type: .progress, duration: duration))
    }
}
