//
//  iCloudSyncError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Error struct for iCloud sync errors
public struct iCloudSyncError {
    /// The file associated with the error, if any
    let file: String?
    
    /// Summary of the error
    var summary: String {
        error.localizedDescription
    }
    
    /// The underlying error
    let error: Error
}
