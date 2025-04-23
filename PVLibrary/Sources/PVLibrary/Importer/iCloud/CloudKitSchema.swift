//
//  CloudKitSchema.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import CloudKit

/// This file defines the CloudKit schema used by Provenance for tvOS sync
/// It serves as documentation for the record types and indexes that need to be created
/// in the CloudKit Dashboard for the app's container
///
/// Record Types:
/// 1. File - Represents a file in the cloud (ROM, save state, BIOS, etc.)
/// 2. Game - Represents metadata about a game
/// 3. SaveState - Represents metadata about a save state
///
/// Note: This file doesn't actually create the schema, it just documents it.
/// The schema must be created manually in the CloudKit Dashboard.

/// CloudKit schema definition for Provenance
public enum CloudKitSchema {
    /// Record types used in CloudKit
    public enum RecordType {
        /// File record type - represents a file in the cloud
        public static let file = "File"
        
        /// Game record type - represents metadata about a game
        public static let game = "Game"
        
        /// SaveState record type - represents metadata about a save state
        public static let saveState = "SaveState"
    }
    
    /// File record attributes
    public enum FileAttributes {
        /// Directory containing the file (e.g., "Roms", "Saves", "BIOS")
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
    }
    
    /// Game record attributes
    public enum GameAttributes {
        /// Game title
        public static let title = "title"
        
        /// System identifier
        public static let systemIdentifier = "systemIdentifier"
        
        /// ROM path
        public static let romPath = "romPath"
        
        /// MD5 hash of the ROM
        public static let md5Hash = "md5Hash"
        
        /// Game description
        public static let description = "description"
        
        /// Game region
        public static let region = "region"
        
        /// Game developer
        public static let developer = "developer"
        
        /// Game publisher
        public static let publisher = "publisher"
        
        /// Game genre
        public static let genre = "genre"
        
        /// Game release date
        public static let releaseDate = "releaseDate"
    }
    
    /// SaveState record attributes
    public enum SaveStateAttributes {
        /// Save state description
        public static let description = "description"
        
        /// Save state timestamp
        public static let timestamp = "timestamp"
        
        /// Game ID this save state belongs to
        public static let gameID = "gameID"
        
        /// Core identifier
        public static let coreIdentifier = "coreIdentifier"
        
        /// Core version
        public static let coreVersion = "coreVersion"
        
        /// Screenshot data as a CKAsset
        public static let screenshot = "screenshot"
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
        
        /// Game record indexes
        public enum Game {
            /// System identifier index
            public static let systemIdentifier = "systemIdentifier"
            
            /// MD5 hash index
            public static let md5Hash = "md5Hash"
            
            /// Title index
            public static let title = "title"
        }
        
        /// SaveState record indexes
        public enum SaveState {
            /// Game ID index
            public static let gameID = "gameID"
            
            /// Timestamp index
            public static let timestamp = "timestamp"
        }
    }
}
