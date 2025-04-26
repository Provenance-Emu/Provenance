//
//  PendingRecoveryInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

// Detailed error/info structs
public struct PendingRecoveryInfo: Identifiable, Hashable {
    public let id = UUID()
    public let filename: String
    public let path: String
    public let timestamp: Date
    
    public init(filename: String, path: String, timestamp: Date = .now) {
        self.filename = filename
        self.path = path
        self.timestamp = timestamp
    }
}
