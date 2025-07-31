//
//  FileCopyProgressTracker.swift
//  PVLibrary
//
//  Created by Cascade on 7/31/25.
//

import Foundation
import Combine
import PVLogging

/// Actor-based tracker for file copy operations with progress monitoring
@globalActor
public actor FileCopyProgressTracker {
    public static let shared = FileCopyProgressTracker()
    
    // MARK: - Types
    
    /// Represents a file copy operation
    public struct FileCopyOperation {
        public let id: UUID
        public let sourceURL: URL
        public let destinationURL: URL
        public let filename: String
        public let sourceType: SourceType
        public let totalBytes: Int64
        public let startTime: Date
        public var copiedBytes: Int64
        public var status: Status
        public var error: Error?
        
        public enum SourceType {
            case local
            case iCloud
            case ubiquityContainer
            case unknown
            
            public var displayName: String {
                switch self {
                case .local: return "Local"
                case .iCloud: return "iCloud"
                case .ubiquityContainer: return "Cloud"
                case .unknown: return "Unknown"
                }
            }
        }
        
        public enum Status {
            case pending
            case downloading
            case copying
            case completed
            case failed
            
            public var displayName: String {
                switch self {
                case .pending: return "Pending"
                case .downloading: return "Downloading"
                case .copying: return "Copying"
                case .completed: return "Complete"
                case .failed: return "Failed"
                }
            }
        }
        
        /// Progress percentage (0.0 to 1.0)
        public var progress: Double {
            guard totalBytes > 0 else { return 0.0 }
            return Double(copiedBytes) / Double(totalBytes)
        }
        
        /// Formatted file size string
        public var formattedSize: String {
            return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
        
        /// Formatted progress string
        public var progressText: String {
            let copiedFormatted = ByteCountFormatter.string(fromByteCount: copiedBytes, countStyle: .file)
            let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(copiedFormatted) / \(totalFormatted)"
        }
    }
    
    // MARK: - Properties
    
    private var activeOperations: [UUID: FileCopyOperation] = [:]
    private var completedOperations: [UUID: FileCopyOperation] = [:]
    
    // Progress tracking
    private let progressSubject = CurrentValueSubject<[FileCopyOperation], Never>([])
    public nonisolated var progressPublisher: AnyPublisher<[FileCopyOperation], Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Start tracking a file copy operation
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Returns: Operation ID for tracking
    public func startCopyOperation(sourceURL: URL, destinationURL: URL) -> UUID {
        let operation = FileCopyOperation(
            id: UUID(),
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            filename: sourceURL.lastPathComponent,
            sourceType: determineSourceType(for: sourceURL),
            totalBytes: getFileSize(for: sourceURL),
            startTime: Date(),
            copiedBytes: 0,
            status: .pending,
            error: nil
        )
        
        activeOperations[operation.id] = operation
        
        ILOG("📁 Started tracking file copy: \(operation.filename) (\(operation.formattedSize)) from \(operation.sourceType.displayName)")
        
        updateProgress()
        return operation.id
    }
    
    /// Update progress for a copy operation
    /// - Parameters:
    ///   - operationId: Operation ID
    ///   - copiedBytes: Number of bytes copied so far
    ///   - status: Current status
    public func updateProgress(operationId: UUID, copiedBytes: Int64, status: FileCopyOperation.Status) {
        guard var operation = activeOperations[operationId] else { return }
        
        operation.copiedBytes = copiedBytes
        operation.status = status
        activeOperations[operationId] = operation
        
        VLOG("📁 Progress update: \(operation.filename) - \(operation.progressText) (\(Int(operation.progress * 100))%)")
        
        updateProgress()
    }
    
    /// Complete a copy operation
    /// - Parameters:
    ///   - operationId: Operation ID
    ///   - success: Whether the operation succeeded
    ///   - error: Error if operation failed
    public func completeCopyOperation(operationId: UUID, success: Bool, error: Error? = nil) {
        guard var operation = activeOperations[operationId] else { return }
        
        operation.status = success ? .completed : .failed
        operation.error = error
        
        if success {
            operation.copiedBytes = operation.totalBytes
            ILOG("✅ File copy completed: \(operation.filename)")
        } else {
            ELOG("❌ File copy failed: \(operation.filename) - \(error?.localizedDescription ?? "Unknown error")")
        }
        
        // Move to completed operations
        activeOperations.removeValue(forKey: operationId)
        completedOperations[operationId] = operation
        
        updateProgress()
        
        // Clean up completed operations after a delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            await cleanupCompletedOperation(operationId: operationId)
        }
    }
    
    /// Get all active copy operations
    public func getActiveOperations() -> [FileCopyOperation] {
        return Array(activeOperations.values).sorted { $0.startTime < $1.startTime }
    }
    
    /// Get all operations (active and recently completed)
    public func getAllOperations() -> [FileCopyOperation] {
        let active = Array(activeOperations.values)
        let completed = Array(completedOperations.values)
        return (active + completed).sorted { $0.startTime < $1.startTime }
    }
    
    /// Cancel a copy operation
    /// - Parameter operationId: Operation ID to cancel
    public func cancelCopyOperation(operationId: UUID) {
        guard let operation = activeOperations[operationId] else { return }
        
        activeOperations.removeValue(forKey: operationId)
        ILOG("🚫 Cancelled file copy: \(operation.filename)")
        
        updateProgress()
    }
    
    /// Clear all completed operations
    public func clearCompleted() {
        completedOperations.removeAll()
        updateProgress()
    }
    
    // MARK: - Private Implementation
    
    private func updateProgress() {
        let allOperations = getAllOperations()
        progressSubject.send(allOperations)
    }
    
    private func cleanupCompletedOperation(operationId: UUID) {
        completedOperations.removeValue(forKey: operationId)
        updateProgress()
    }
    
    private func determineSourceType(for url: URL) -> FileCopyOperation.SourceType {
        let urlString = url.absoluteString.lowercased()
        
        if urlString.contains("icloud") {
            return .iCloud
        } else if urlString.contains("ubiquity") || url.hasDirectoryPath && url.path.contains("ubiquity") {
            return .ubiquityContainer
        } else if url.isFileURL {
            return .local
        } else {
            return .unknown
        }
    }
    
    private func getFileSize(for url: URL) -> Int64 {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            WLOG("Failed to get file size for \(url.path): \(error.localizedDescription)")
            return 0
        }
    }
}
