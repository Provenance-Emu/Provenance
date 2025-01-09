//
//  BatterySyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import SwiftCloudDrive

public extension RootRelativePath {
    static let batteryStates = Self(path: "Battery States")
}


public class BatteryStatesSyncer: CommonSyncer {
    
    public var relativeRootPath: RootRelativePath { .roms }

    
    public func sync() async throws {
    }
}
