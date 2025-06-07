//
//  ProgressInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

/// Progress information for various operations
public struct ProgressInfo: Identifiable, Equatable {
    public let id: String
    public let current: Int
    public let total: Int
    public var detail: String?
    
    public var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    public init(id: String = UUID().uuidString, current: Int, total: Int, detail: String? = nil) {
        self.id = id
        self.current = current
        self.total = total
        self.detail = detail
    }
}
