//
//  BIOSSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import SwiftCloudDrive

public extension RootRelativePath {
    static let bioses = Self(path: "BIOS")
}

public class BIOSSyncer: CommonSyncer {
    public var relativeRootPath: RootRelativePath { .bioses }

    
    public func sync() async throws {
    }
}
