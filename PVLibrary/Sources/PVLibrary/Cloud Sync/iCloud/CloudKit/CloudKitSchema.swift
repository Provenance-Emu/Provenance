//
//  CloudKitSchema.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit
import PVLogging

/// This file defines the CloudKit schema used by Provenance for sync across all platforms
/// It also provides functions to create the schema programmatically
///
/// Record Types:
/// 1. ROM - Represents a ROM file in the cloud
/// 2. SaveState - Represents a save state file in the cloud
/// 3. BIOS - Represents a BIOS file in the cloud
/// 4. File - Generic file type for other files

/// CloudKit schema definition for Provenance
public enum CloudKitSchema {
    /// Flag to track if schema has been initialized
    private static var isSchemaInitialized = false
    
    /// Record types used in the public CloudKit database.
    public enum RecordType: String, CaseIterable {
        case rom = "ROM" // Changed from Game to ROM for clarity, or keep Game if preferred?
        case saveState = "SaveState"
        case bios = "BIOS"
        case screenshot = "Screenshot"
        case artwork = "Artwork"
        case file = "File" // Generic file type, maybe used by non-DB syncer?
        case metadata = "Metadata" // For general sync metadata, like last sync tokens
    }
    
    /// Field keys for the ROM record type.
    public struct ROMFields {
        public static let recordType = RecordType.rom.rawValue
        
        // Core Identifiers & File Info
        public static let md5 = "md5" // String, Indexed
        public static let systemIdentifier = "systemIdentifier" // String
        public static let romFile = "romFile" // CKAsset
        public static let isArchive = "isArchive" // Bool (True if romFile is a zip)
        public static let fileSize = "fileSize" // Int64
        public static let originalFilename = "originalFilename" // String
        public static let relatedFilenames = "relatedFilenames" // [String]?

        // OpenVGDB Metadata (Optional Strings)
        public static let title = "title" // String (Maybe redundant if derived from originalFilename, but good for display)
        public static let gameDescription = "gameDescription"
        public static let boxBackArtworkURL = "boxBackArtworkURL"
        public static let developer = "developer"
        public static let publisher = "publisher"
        public static let publishDate = "publishDate"
        public static let genres = "genres" // Comma-separated String?
        public static let referenceURL = "referenceURL"
        public static let releaseID = "releaseID"
        public static let regionName = "regionName"
        public static let regionID = "regionID" // Int64?
        public static let systemShortName = "systemShortName"
        public static let language = "language"

        // User Stats & Info
        public static let lastPlayed = "lastPlayed" // Date?
        public static let playCount = "playCount" // Int64
        public static let timeSpentInGame = "timeSpentInGame" // Int64 (seconds)
        public static let rating = "rating" // Int64 (-1 to 5)
        public static let isFavorite = "isFavorite" // Bool
        public static let isDeleted = "isDeleted" // Boolean flag for soft delete
        public static let importDate = "importDate" // Date?

        // Sync Metadata
        public static let lastModifiedDevice = "lastModifiedDevice" // String? (Identifier for device)
        // CloudKit system fields like creationDate, modificationDate are implicit
    }
    
    /// Field keys for the SaveState record type.
    public struct SaveStateFields {
        public static let recordType = RecordType.saveState.rawValue
        
        public static let filename = "filename" // String
        public static let directory = "directory" // String (e.g., "BIOS", "Saves", "Cheats")
        public static let systemIdentifier = "systemIdentifier" // String? (Optional, e.g., for BIOS)
        public static let gameID = "gameID" // String? (Optional, e.g., for Saves)
        public static let fileData = "fileData" // CKAsset
        public static let fileSize = "fileSize" // Int64
        public static let lastModified = "lastModified" // Date
        public static let md5 = "md5" // String? (Optional, e.g., for BIOS verification)
        // Add other relevant fields specific to generic files if needed
    }
    
    /// Field keys for the Metadata record type (e.g., for sync tokens).
    public struct MetadataFields {
        public static let recordType = RecordType.metadata.rawValue
        
        // Add relevant fields for metadata if needed
    }
    
    /// Field keys for the BIOS record type.
    public struct BIOSAttributes {
        /// System identifier
        public static let systemIdentifier = "systemIdentifier" // String
        /// MD5 hash of the BIOS
        public static let md5Hash = "md5Hash" // String
        /// Description of the BIOS
        public static let description = "description" // String
        /// All BIOS-specific attributes
        public static let all = [systemIdentifier, md5Hash, description]
    }
    
    /// CloudKit indexes to create
    public enum Indexes {
        /// File record indexes
        public enum File {
            /// Directory index
            public static let directory = "directory"
            
            /// System index
            public static let system = "system"
            
            /// Filename index
            public static let filename = "filename"
            
            /// Game ID index
            public static let gameID = "gameID"
            
            /// Save state ID index
            public static let saveStateID = "saveStateID"
            
            /// MD5 hash index
            public static let md5 = "md5"
        }
    }
    
    /// Initialize the CloudKit schema programmatically
    /// This creates the necessary record types and indexes in CloudKit
    /// - Parameter database: The CloudKit database to initialize (usually privateDatabase)
    /// - Returns: A boolean indicating success or failure
    @discardableResult
    public static func initializeSchema(in database: CKDatabase) async -> Bool {
        // Check if schema has already been initialized to prevent repeated initialization
        guard !isSchemaInitialized else {
            DLOG("CloudKit schema already initialized, skipping")
            return true
        }
        
        do {
            DLOG("Initializing CloudKit schema...")
            
            // Create record types
            try await createRecordTypes(in: database)
            
            // Mark as initialized
            isSchemaInitialized = true
            
            DLOG("CloudKit schema initialized successfully")
            return true
        } catch {
            ELOG("Failed to initialize CloudKit schema: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Create record types in CloudKit
    /// - Parameter database: The CloudKit database to create record types in
    private static func createRecordTypes(in database: CKDatabase) async throws {
        // Create each record type
        for recordType in RecordType.allCases {
            try await createRecordType(recordType.rawValue, in: database)
        }
    }
    
    /// Create a single record type in CloudKit
    /// - Parameters:
    ///   - recordType: The record type to create
    ///   - database: The CloudKit database to create the record type in
    private static func createRecordType(_ recordType: String, in database: CKDatabase) async throws {
        DLOG("Creating/updating record type: \(recordType)")
        
        // Note: CloudKit schema is automatically created when records are saved
        // We don't need to explicitly create test records anymore
        // The schema will be properly initialized when real records are saved
        
        // Just log that we're initializing this record type
        DLOG("Initialized record type: \(recordType)")
        
        // No need to create and delete test records, which can cause clutter
        // CloudKit will create the schema when actual records are saved
    }
}
