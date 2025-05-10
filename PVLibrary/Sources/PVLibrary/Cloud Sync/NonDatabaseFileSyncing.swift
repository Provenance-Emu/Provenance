//
//  NonDatabaseFileSyncing.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Protocol for non-database file sync operations
public protocol NonDatabaseFileSyncing: SyncProvider {
    /// Get all files in the specified directories
    /// - Returns: Array of file URLs
    func getAllFiles(in directory: String) async -> [URL]

    /// Check if a file is downloaded locally
    /// - Parameter filename: The filename to check
    /// - Returns: True if the file is downloaded locally
    func isFileDownloaded(filename: String, in directory: String) async -> Bool
}
