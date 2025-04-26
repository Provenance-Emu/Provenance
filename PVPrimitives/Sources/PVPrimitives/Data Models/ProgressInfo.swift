//
//  ProgressInfo.swift
//  PVPrimitives
//
//  Created by Joseph Mattiello on 4/26/25.
//

import Foundation

/// Progress information for various operations
public struct ProgressInfo: Identifiable, Equatable {
    public let id = UUID()
    public let current: Int
    public let total: Int
    public var detail: String?
    
    public init(current: Int, total: Int, detail: String? = nil) {
        self.current = current
        self.total = total
        self.detail = detail
    }
}
