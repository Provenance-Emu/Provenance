//
//  ROMSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import SwiftCloudDrive

public extension RootRelativePath {
    static let roms = Self(path: "ROMs")
}

public class ROMSSyncer: CommonSyncer {
    public var relativeRootPath: RootRelativePath { .roms }

    
    public func sync() async throws {
    }
}
