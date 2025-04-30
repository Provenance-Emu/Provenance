//
//  CloudKitSyncAnalytics.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging
import Combine

/// Analytics class for tracking CloudKit sync operations
public class CloudKitSyncAnalytics: ObservableObject {
    /// Shared instance for app-wide access
    public static let shared = CloudKitSyncAnalytics()
    
    // MARK: - Properties
    
    /// Total number of sync operations
    @Published public var totalSyncs: Int = 0
    
    /// Number of successful sync operations
    @Published public var successfulSyncs: Int = 0
    
    /// Number of failed sync operations
    @Published public var failedSyncs: Int = 0
    
    /// Total bytes uploaded
    @Published public var totalBytesUploaded: Int64 = 0
    
    /// Total bytes downloaded
    @Published public var totalBytesDownloaded: Int64 = 0
    
    /// Last sync time
    @Published public var lastSyncTime: Date?
    
    /// Average sync duration in seconds
    @Published public var averageSyncDuration: TimeInterval = 0
    
    /// Current sync operation (if any)
    @Published public var currentSyncOperation: String = ""
    
    /// Is a sync operation currently in progress
    @Published public var isSyncing: Bool = false
    
    /// Last sync error (if any)
    @Published public var lastSyncError: Error?
    
    /// Sync history (last 10 operations)
    @Published public var syncHistory: [SyncOperation] = []
    
    /// Maximum number of sync history items to keep
    private let maxHistoryItems = 10
    
    /// Current sync start time
    private var syncStartTime: Date?
    
    /// UserDefaults keys for persistence
    private enum Keys {
        static let totalSyncs = "com.provenance-emu.provenance.cloudkit.totalSyncs"
        static let successfulSyncs = "com.provenance-emu.provenance.cloudkit.successfulSyncs"
        static let failedSyncs = "com.provenance-emu.provenance.cloudkit.failedSyncs"
        static let totalBytesUploaded = "com.provenance-emu.provenance.cloudkit.totalBytesUploaded"
        static let totalBytesDownloaded = "com.provenance-emu.provenance.cloudkit.totalBytesDownloaded"
        static let lastSyncTime = "com.provenance-emu.provenance.cloudkit.lastSyncTime"
        static let averageSyncDuration = "com.provenance-emu.provenance.cloudkit.averageSyncDuration"
        static let syncHistory = "com.provenance-emu.provenance.cloudkit.syncHistory"
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Public Methods
    
    /// Start tracking a new sync operation
    /// - Parameter operation: Description of the operation
    @MainActor
    public func startSync(operation: String) {
        currentSyncOperation = operation
        isSyncing = true
        syncStartTime = Date()
        
        DLOG("Started CloudKit sync operation: \(operation)")
    }
    
    /// Record a successful sync operation
    /// - Parameters:
    ///   - bytesUploaded: Bytes uploaded during this operation
    ///   - bytesDownloaded: Bytes downloaded during this operation
    @MainActor
    public func recordSuccessfulSync(bytesUploaded: Int64 = 0, bytesDownloaded: Int64 = 0) {
        guard isSyncing else { return }
        
        let now = Date()
        let syncDuration = syncStartTime.map { now.timeIntervalSince($0) } ?? 0
        
        // Update counters
        totalSyncs += 1
        successfulSyncs += 1
        totalBytesUploaded += bytesUploaded
        totalBytesDownloaded += bytesDownloaded
        lastSyncTime = now
        
        // Update average duration
        if totalSyncs > 1 {
            averageSyncDuration = ((averageSyncDuration * Double(totalSyncs - 1)) + syncDuration) / Double(totalSyncs)
        } else {
            averageSyncDuration = syncDuration
        }
        
        // Add to history
        addToHistory(
            SyncOperation(
                timestamp: now,
                operation: currentSyncOperation,
                duration: syncDuration,
                bytesUploaded: bytesUploaded,
                bytesDownloaded: bytesDownloaded,
                success: true,
                error: nil
            )
        )
        
        // Reset current operation
        isSyncing = false
        syncStartTime = nil
        
        // Save to UserDefaults
        saveToUserDefaults()
        
        DLOG("""
             Completed CloudKit sync operation: \(currentSyncOperation)
             Duration: \(String(format: "%.2f", syncDuration))s
             Uploaded: \(ByteCountFormatter.string(fromByteCount: bytesUploaded, countStyle: .file))
             Downloaded: \(ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file))
             """)
    }
    
    /// Record a failed sync operation
    /// - Parameter error: The error that occurred
    public func recordFailedSync(error: Error) {
        guard isSyncing else { return }
        
        let now = Date()
        let syncDuration = syncStartTime.map { now.timeIntervalSince($0) } ?? 0
        
        // Update counters
        totalSyncs += 1
        failedSyncs += 1
        lastSyncTime = now
        lastSyncError = error
        
        // Add to history
        Task { @MainActor in
            addToHistory(
                SyncOperation(
                    timestamp: now,
                    operation: currentSyncOperation,
                    duration: syncDuration,
                    bytesUploaded: 0,
                    bytesDownloaded: 0,
                    success: false,
                    error: error
                )
            )
        }
        
        // Reset current operation
        isSyncing = false
        syncStartTime = nil
        
        // Save to UserDefaults
        saveToUserDefaults()
        
        ELOG("""
             Failed CloudKit sync operation: \(currentSyncOperation)
             Duration: \(String(format: "%.2f", syncDuration))s
             Error: \(error.localizedDescription)
             """)
    }
    
    /// Reset all analytics data
    public func resetAnalytics() {
        totalSyncs = 0
        successfulSyncs = 0
        failedSyncs = 0
        totalBytesUploaded = 0
        totalBytesDownloaded = 0
        lastSyncTime = nil
        averageSyncDuration = 0
        syncHistory.removeAll()
        
        // Save to UserDefaults
        saveToUserDefaults()
        
        DLOG("Reset CloudKit sync analytics")
    }
    
    // MARK: - Private Methods
    
    /// Add an operation to the sync history
    /// - Parameter operation: The operation to add
    @MainActor
    private func addToHistory(_ operation: SyncOperation) {
        // Add to front of array
        syncHistory.insert(operation, at: 0)
        
        // Trim if needed
        if syncHistory.count > maxHistoryItems {
            syncHistory = Array(syncHistory.prefix(maxHistoryItems))
        }
    }
    
    /// Save analytics data to UserDefaults
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        defaults.set(totalSyncs, forKey: Keys.totalSyncs)
        defaults.set(successfulSyncs, forKey: Keys.successfulSyncs)
        defaults.set(failedSyncs, forKey: Keys.failedSyncs)
        defaults.set(totalBytesUploaded, forKey: Keys.totalBytesUploaded)
        defaults.set(totalBytesDownloaded, forKey: Keys.totalBytesDownloaded)
        defaults.set(lastSyncTime, forKey: Keys.lastSyncTime)
        defaults.set(averageSyncDuration, forKey: Keys.averageSyncDuration)
        
        // Save history as data
        if let historyData = try? JSONEncoder().encode(syncHistory) {
            defaults.set(historyData, forKey: Keys.syncHistory)
        }
    }
    
    /// Load analytics data from UserDefaults
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        totalSyncs = defaults.integer(forKey: Keys.totalSyncs)
        successfulSyncs = defaults.integer(forKey: Keys.successfulSyncs)
        failedSyncs = defaults.integer(forKey: Keys.failedSyncs)
        totalBytesUploaded = Int64(defaults.integer(forKey: Keys.totalBytesUploaded))
        totalBytesDownloaded = Int64(defaults.integer(forKey: Keys.totalBytesDownloaded))
        lastSyncTime = defaults.object(forKey: Keys.lastSyncTime) as? Date
        averageSyncDuration = defaults.double(forKey: Keys.averageSyncDuration)
        
        // Load history from data
        if let historyData = defaults.data(forKey: Keys.syncHistory),
           let decodedHistory = try? JSONDecoder().decode([SyncOperation].self, from: historyData) {
            syncHistory = decodedHistory
        }
    }
}

/// Model representing a single sync operation
public struct SyncOperation: Codable, Identifiable {
    /// Unique identifier
    public var id = UUID()
    
    /// Timestamp when the operation occurred
    public let timestamp: Date
    
    /// Description of the operation
    public let operation: String
    
    /// Duration of the operation in seconds
    public let duration: TimeInterval
    
    /// Bytes uploaded during this operation
    public let bytesUploaded: Int64
    
    /// Bytes downloaded during this operation
    public let bytesDownloaded: Int64
    
    /// Whether the operation was successful
    public let success: Bool
    
    /// Error message if the operation failed
    public let errorMessage: String?
    
    /// Initializer
    /// - Parameters:
    ///   - timestamp: Timestamp when the operation occurred
    ///   - operation: Description of the operation
    ///   - duration: Duration of the operation in seconds
    ///   - bytesUploaded: Bytes uploaded during this operation
    ///   - bytesDownloaded: Bytes downloaded during this operation
    ///   - success: Whether the operation was successful
    ///   - error: Error if the operation failed
    public init(timestamp: Date, operation: String, duration: TimeInterval, bytesUploaded: Int64, bytesDownloaded: Int64, success: Bool, error: Error?) {
        self.timestamp = timestamp
        self.operation = operation
        self.duration = duration
        self.bytesUploaded = bytesUploaded
        self.bytesDownloaded = bytesDownloaded
        self.success = success
        self.errorMessage = error?.localizedDescription
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, operation, duration, bytesUploaded, bytesDownloaded, success, errorMessage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        operation = try container.decode(String.self, forKey: .operation)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        bytesUploaded = try container.decode(Int64.self, forKey: .bytesUploaded)
        bytesDownloaded = try container.decode(Int64.self, forKey: .bytesDownloaded)
        success = try container.decode(Bool.self, forKey: .success)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(operation, forKey: .operation)
        try container.encode(duration, forKey: .duration)
        try container.encode(bytesUploaded, forKey: .bytesUploaded)
        try container.encode(bytesDownloaded, forKey: .bytesDownloaded)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
    }
}
