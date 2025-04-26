//
//  FileErrorInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

// Detailed error/info structs
public struct FileErrorInfo: Identifiable, Hashable {
    public let id = UUID()
    public let error: String
    public let path: String
    public let filename: String
    public let timestamp: Date
    public let errorType: String? // Specific type like 'timeout', 'access_denied' etc.
    
    public init(error: String, path: String, filename: String, timestamp: Date = .now, errorType: String? = nil) {
        self.error = error
        self.path = path
        self.filename = filename
        self.timestamp = timestamp
        self.errorType = errorType
    }
}
