//
//  LibretroDBError.swift
//  PVLookup
//
//  Created by Joseph Mattiello on 12/15/24.
//

/// Errors that can occur when working with LibretroDB
enum LibretroDBError: Error {
    case invalidMetadata
    case databaseError(String)
}
