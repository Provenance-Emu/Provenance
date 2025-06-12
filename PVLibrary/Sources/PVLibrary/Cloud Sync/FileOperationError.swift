//
//  FileOperationError.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

/// Errors specific to file operations
public enum FileOperationError: Error {
    case downloadFailed
    case chunkTransferFailed
    case sourceFileNotFound
    case destinationDirectoryCreationFailed
    case invalidFileHandle
}
