//
//  CloudKitRecordCounts.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation

/// CloudKit record counts
public struct CloudKitRecordCounts {
    /// Number of ROM records
    public let roms: Int
    
    /// Number of save state records
    public let saveStates: Int
    
    /// Number of BIOS records
    public let bios: Int
    
    /// Total number of records
    public var total: Int { roms + saveStates + bios }
    
    /// Initialize a new CloudKitRecordCounts
    /// - Parameters:
    ///   - roms: Number of ROM records
    ///   - saveStates: Number of save state records
    ///   - bios: Number of BIOS records
    public init(roms: Int, saveStates: Int, bios: Int) {
        self.roms = roms
        self.saveStates = saveStates
        self.bios = bios
    }
}
