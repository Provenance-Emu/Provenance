//
//  ArchiveEntryInfo.swift
//  PVArchiving
//
//  Created by Joseph Mattiello on 3/28/26.
//

import Foundation

/// Lightweight description of a single entry inside an archive.
/// Backends populate this when listing contents without extracting.
public struct ArchiveEntryInfo: Sendable, Equatable {
    public let name: String
    public let size: Int64?
    public let isDirectory: Bool
    public let crc: UInt32?

    public init(name: String, size: Int64? = nil, isDirectory: Bool = false, crc: UInt32? = nil) {
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.crc = crc
    }
}
