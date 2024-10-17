//
//  SaveStatesSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/13/24.
//

import Foundation
import SwiftCloudDrive

public extension RootRelativePath {
    static let saveStates = Self(path: "Save States")
}

public class SaveStatesSyncer: CommonSyncer {
    public var relativeRootPath: RootRelativePath { .saveStates }

    
    public func sync() async throws{
    }
}
