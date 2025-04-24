//
//  CloudKitSchema.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
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
    
    /// Record types used in CloudKit
    public enum RecordType {
        /// ROM record type - represents a ROM file in the cloud
        public static let rom = "ROM"
        
        /// SaveState record type - represents a save state file in the cloud
        public static let saveState = "SaveState"
        
        /// BIOS record type - represents a BIOS file in the cloud
        public static let bios = "BIOS"
        
        /// File record type - generic file type for other files
        public static let file = "File"
        
        /// All record types used in the app
        public static let all = [rom, saveState, bios, file]
    }
    
    /// Common file attributes for all record types
    public enum FileAttributes {
        /// Directory containing the file (e.g., "ROMs", "Saves", "BIOS")
        public static let directory = "directory"
        
        /// System identifier or subdirectory (e.g., "SNES", "NES")
        public static let system = "system"
        
        /// Filename of the file
        public static let filename = "filename"
        
        /// File data as a CKAsset
        public static let fileData = "fileData"
        
        /// Last modified date
        public static let lastModified = "lastModified"
        
        /// MD5 hash of the file (if available)
        public static let md5 = "md5"
        
        /// ID of the game this file belongs to (for save states)
        public static let gameID = "gameID"
        
        /// ID of the save state this file belongs to (for save states)
        public static let saveStateID = "saveStateID"
        
        /// All common attributes used in file records
        public static let all = [directory, system, filename, fileData, lastModified, md5, gameID, saveStateID]
    }
    
    /// ROM-specific attributes
    public enum ROMAttributes {
        /// Game title
        public static let title = "title"
        
        /// System identifier
        public static let systemIdentifier = "systemIdentifier"
        
        /// MD5 hash of the ROM
        public static let md5Hash = "md5Hash"
        
        /// Game description
        public static let description = "description"
        
        /// Game region
        public static let region = "region"
        
        /// All ROM-specific attributes
        public static let all = [title, systemIdentifier, md5Hash, description, region]
    }
    
    /// SaveState-specific attributes
    public enum SaveStateAttributes {
        /// Save state description
        public static let description = "description"
        
        /// Game ID this save state belongs to
        public static let gameID = "gameID"
        
        /// Screenshot of the save state as a CKAsset
        public static let screenshot = "screenshot"
        
        /// All SaveState-specific attributes
        public static let all = [description, gameID, screenshot]
    }
    
    /// BIOS-specific attributes
    public enum BIOSAttributes {
        /// System identifier
        public static let systemIdentifier = "systemIdentifier"
        
        /// MD5 hash of the BIOS
        public static let md5Hash = "md5Hash"
        
        /// Description of the BIOS
        public static let description = "description"
        
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
        for recordType in RecordType.all {
            try await createRecordType(recordType, in: database)
        }
    }
    
    /// Create a single record type in CloudKit
    /// - Parameters:
    ///   - recordType: The record type to create
    ///   - database: The CloudKit database to create the record type in
    private static func createRecordType(_ recordType: String, in database: CKDatabase) async throws {
        DLOG("Creating/updating record type: \(recordType)")
        
        // Note: CloudKit automatically indexes some fields when they're used in queries
        // We'll create test records with the fields we want to use in queries
        // This approach works because CloudKit will index fields that are frequently queried
        DLOG("Creating test records with queryable fields for: \(recordType)")
        
        // As a fallback, create a test record to ensure the record type exists
        let record = CKRecord(recordType: recordType)
        
        // Add some common attributes based on the record type
        switch recordType {
        case RecordType.rom:
            record[FileAttributes.directory] = "ROMs"
            record[ROMAttributes.title] = "Test ROM"
        case RecordType.saveState:
            record[FileAttributes.directory] = "Save States"
            record[SaveStateAttributes.description] = "Test Save State"
        case RecordType.bios:
            record[FileAttributes.directory] = "BIOS"
            record[BIOSAttributes.description] = "Test BIOS"
        case RecordType.file:
            record[FileAttributes.directory] = "Files"
            record[FileAttributes.filename] = "test.file"
        default:
            break
        }
        
        do {
            // Try to save the record to create the record type
            _ = try await database.save(record)
            DLOG("Created test record for type: \(recordType)")
            
            // Delete the test record
            try await database.deleteRecord(withID: record.recordID)
            DLOG("Deleted test record for: \(recordType)")
        } catch let error as CKError {
            // If the error is not that the record type already exists, rethrow
            if error.code != .serverRecordChanged && error.code != .unknownItem {
                throw error
            }
            DLOG("Record type already exists or couldn't be created: \(recordType)")
        }
    }
}
