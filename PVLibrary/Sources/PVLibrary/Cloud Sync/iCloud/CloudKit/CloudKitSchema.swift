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
        case file = "File" // Generic file type for non-DB files (Screenshots, Battery States, etc.)
        case metadata = "Metadata" // For general sync metadata, like last sync tokens
        // Note: Screenshots and other non-DB files use the generic "File" record type with directory filtering
    }
    
    /// Field keys for the ROM record type.
    public struct ROMFields {
        public static let recordType = RecordType.rom.rawValue
        
        // Core Identifiers & File Info
        public static let md5 = "md5" // String, Indexed
        public static let systemIdentifier = "systemIdentifier" // String
        public static let fileData = "fileData" // CKAsset (standardized asset field name)
        public static let isArchive = "isArchive" // Bool (True if fileData is a zip)
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
    
    // Note: Screenshots and other non-database files are handled using the generic "File" record type
    // with directory-based filtering. This approach is simpler and avoids schema complexity.
    
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
    
    /// Centralized record ID generation for consistency across all record types
    public enum RecordIDGenerator {
        /// Generate a record ID for a ROM based on its MD5 hash
        /// - Parameter md5: The MD5 hash of the ROM
        /// - Returns: A CKRecord.ID with format "rom_<md5>"
        public static func romRecordID(md5: String) -> CKRecord.ID {
            return CKRecord.ID(recordName: "rom_\(md5)")
        }
        
        /// Generate a record ID for a save state
        /// - Parameters:
        ///   - gameID: The game ID this save state belongs to
        ///   - filename: The save state filename
        /// - Returns: A CKRecord.ID with format "savestate_<gameID>_<filename>"
        public static func saveStateRecordID(gameID: String, filename: String) -> CKRecord.ID {
            // Use a sanitized filename for the record ID
            let sanitizedFilename = filename.replacingOccurrences(of: ".", with: "_")
            return CKRecord.ID(recordName: "savestate_\(gameID)_\(sanitizedFilename)")
        }
        
        /// Generate a record ID for a BIOS file
        /// - Parameters:
        ///   - systemID: The system identifier
        ///   - md5: The MD5 hash of the BIOS
        /// - Returns: A CKRecord.ID with format "bios_<systemID>_<md5>"
        public static func biosRecordID(systemID: String, md5: String) -> CKRecord.ID {
            return CKRecord.ID(recordName: "bios_\(systemID)_\(md5)")
        }
        
        // Note: Screenshots and other non-database files use the generic fileRecordID method
        // since they are handled as File records with directory filtering
        
        /// Generate a record ID for a generic file
        /// - Parameters:
        ///   - directory: The directory name
        ///   - filename: The filename
        ///   - uniqueID: A unique identifier (e.g., UUID or hash)
        /// - Returns: A CKRecord.ID with format "file_<directory>_<uniqueID>"
        public static func fileRecordID(directory: String, filename: String, uniqueID: String) -> CKRecord.ID {
            return CKRecord.ID(recordName: "file_\(directory)_\(uniqueID)")
        }
        
        /// Extract MD5 from a ROM record ID
        /// - Parameter recordID: The CKRecord.ID to extract from
        /// - Returns: The MD5 hash if the record ID is valid, nil otherwise
        public static func extractMD5FromRomRecordID(_ recordID: CKRecord.ID) -> String? {
            let recordName = recordID.recordName
            guard recordName.starts(with: "rom_") else { return nil }
            return String(recordName.dropFirst(4)) // Remove "rom_" prefix
        }
        
        /// Extract game ID and filename from a save state record ID
        /// - Parameter recordID: The CKRecord.ID to extract from
        /// - Returns: A tuple of (gameID, filename) if valid, nil otherwise
        public static func extractFromSaveStateRecordID(_ recordID: CKRecord.ID) -> (gameID: String, filename: String)? {
            let recordName = recordID.recordName
            guard recordName.starts(with: "savestate_") else { return nil }
            
            let components = recordName.dropFirst(10).components(separatedBy: "_") // Remove "savestate_" prefix
            guard components.count >= 2 else { return nil }
            
            let gameID = components[0]
            let filename = components.dropFirst().joined(separator: "_").replacingOccurrences(of: "_", with: ".")
            return (gameID: gameID, filename: filename)
        }
    }
}
