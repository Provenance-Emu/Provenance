//
//  CloudKitConflictResolver.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging

/// Strategies for resolving CloudKit record conflicts
public enum CloudKitConflictResolutionStrategy {
    /// Use the client record (local)
    case clientRecord
    /// Use the server record (remote)
    case serverRecord
    /// Use the newest record based on modification date
    case newestRecord
    /// Use the oldest record based on modification date
    case oldestRecord
    /// Merge the records using custom logic
    case customMerge
}

/// CloudKit conflict resolver for handling record conflicts
public class CloudKitConflictResolver {
    /// Shared instance for app-wide access
    public static let shared = CloudKitConflictResolver()
    
    /// Default strategy for resolving conflicts
    public var defaultStrategy: CloudKitConflictResolutionStrategy = .newestRecord
    
    /// Private initializer for singleton
    private init() {}
    
    /// Resolve a conflict between a client and server record
    /// - Parameters:
    ///   - clientRecord: The local record
    ///   - serverRecord: The server record
    ///   - strategy: The strategy to use for resolution (defaults to the instance's defaultStrategy)
    /// - Returns: The resolved record
    public func resolveConflict(
        clientRecord: CKRecord,
        serverRecord: CKRecord,
        strategy: CloudKitConflictResolutionStrategy? = nil
    ) -> CKRecord {
        let resolutionStrategy = strategy ?? defaultStrategy
        
        DLOG("""
             Resolving CloudKit conflict for record: \(clientRecord.recordID.recordName)
             Strategy: \(resolutionStrategy)
             """)
        
        switch resolutionStrategy {
        case .clientRecord:
            return clientRecord
            
        case .serverRecord:
            return serverRecord
            
        case .newestRecord:
            if let clientDate = clientRecord.modificationDate,
               let serverDate = serverRecord.modificationDate {
                return clientDate > serverDate ? clientRecord : serverRecord
            } else if clientRecord.modificationDate != nil {
                return clientRecord
            } else {
                return serverRecord
            }
            
        case .oldestRecord:
            if let clientDate = clientRecord.modificationDate,
               let serverDate = serverRecord.modificationDate {
                return clientDate < serverDate ? clientRecord : serverRecord
            } else if serverRecord.modificationDate != nil {
                return serverRecord
            } else {
                return clientRecord
            }
            
        case .customMerge:
            return mergeRecords(clientRecord: clientRecord, serverRecord: serverRecord)
        }
    }
    
    /// Merge two records using custom logic based on record type
    /// - Parameters:
    ///   - clientRecord: The local record
    ///   - serverRecord: The server record
    /// - Returns: The merged record
    private func mergeRecords(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        // Start with the server record as the base
        let mergedRecord = serverRecord
        
        // Apply record-type specific merge logic
        switch clientRecord.recordType {
        case "ROM":
            return mergeROMRecords(clientRecord: clientRecord, serverRecord: mergedRecord)
            
        case "SaveState":
            return mergeSaveStateRecords(clientRecord: clientRecord, serverRecord: mergedRecord)
            
        case "BIOS":
            return mergeBIOSRecords(clientRecord: clientRecord, serverRecord: mergedRecord)
            
        default:
            // For unknown record types, prefer the newest record
            if let clientDate = clientRecord.modificationDate,
               let serverDate = serverRecord.modificationDate,
               clientDate > serverDate {
                return clientRecord
            } else {
                return serverRecord
            }
        }
    }
    
    /// Merge ROM records with custom logic
    /// - Parameters:
    ///   - clientRecord: The local ROM record
    ///   - serverRecord: The server ROM record
    /// - Returns: The merged ROM record
    private func mergeROMRecords(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        let mergedRecord = serverRecord
        
        // For ROMs, we generally want to keep most metadata from the server
        // but update certain fields if the client has newer information
        
        // If client has a title and server doesn't, use client's title
        if serverRecord["title"] == nil && clientRecord["title"] != nil {
            mergedRecord["title"] = clientRecord["title"]
        }
        
        // Always use the client's MD5 if available (it's a computed property)
        if let clientMD5 = clientRecord["md5"] {
            mergedRecord["md5"] = clientMD5
        }
        
        // Keep the most recent file data
        if let clientModDate = clientRecord.modificationDate,
           let serverModDate = serverRecord.modificationDate,
           clientModDate > serverModDate,
           let clientFileData = clientRecord["fileData"] as? CKAsset {
            mergedRecord["fileData"] = clientFileData
        }
        
        return mergedRecord
    }
    
    /// Merge SaveState records with custom logic
    /// - Parameters:
    ///   - clientRecord: The local SaveState record
    ///   - serverRecord: The server SaveState record
    /// - Returns: The merged SaveState record
    private func mergeSaveStateRecords(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        let mergedRecord = serverRecord
        
        // For save states, we almost always want the newest one
        // as it represents the latest game progress
        if let clientModDate = clientRecord.modificationDate,
           let serverModDate = serverRecord.modificationDate,
           clientModDate > serverModDate {
            
            // Use the newer save state data
            if let clientFileData = clientRecord["fileData"] as? CKAsset {
                mergedRecord["fileData"] = clientFileData
            }
            
            // Use the newer screenshot if available
            if let clientScreenshot = clientRecord["screenshot"] as? CKAsset {
                mergedRecord["screenshot"] = clientScreenshot
            }
            
            // Use the newer description if available
            if let clientDescription = clientRecord["description"] {
                mergedRecord["description"] = clientDescription
            }
        }
        
        return mergedRecord
    }
    
    /// Merge BIOS records with custom logic
    /// - Parameters:
    ///   - clientRecord: The local BIOS record
    ///   - serverRecord: The server BIOS record
    /// - Returns: The merged BIOS record
    private func mergeBIOSRecords(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        // For BIOS files, we typically want to keep the one with the correct MD5
        // as these are reference files that shouldn't change
        
        // If both have MD5 hashes, compare them to known good values
        if let clientMD5 = clientRecord["md5"] as? String,
           let serverMD5 = serverRecord["md5"] as? String,
           let systemID = serverRecord["systemIdentifier"] as? String {
            
            // In a real implementation, we would check against known good BIOS MD5 values
            // For now, we'll just use the server version as the "source of truth"
            return serverRecord
        }
        
        // If we can't determine based on MD5, use the server version
        return serverRecord
    }
    
    /// Handle a CloudKit conflict error by resolving the conflict
    /// - Parameters:
    ///   - error: The CloudKit error
    ///   - database: The CloudKit database
    /// - Returns: The resolved record if successful
    public func handleConflictError(
        _ error: CKError,
        database: CKDatabase
    ) async throws -> CKRecord? {
        // Check if this is a conflict error
        guard error.code == .serverRecordChanged else {
            // Not a conflict error, rethrow
            throw error
        }
        
        // Extract the client and server records from the error
        guard let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
              let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
            ELOG("Missing client or server record in conflict error")
            throw error
        }
        
        // Resolve the conflict
        let resolvedRecord = resolveConflict(clientRecord: clientRecord, serverRecord: serverRecord)
        
        // Save the resolved record
        do {
            DLOG("Saving resolved record: \(resolvedRecord.recordID.recordName)")
            return try await database.save(resolvedRecord)
        } catch {
            ELOG("Failed to save resolved record: \(error.localizedDescription)")
            throw error
        }
    }
}
