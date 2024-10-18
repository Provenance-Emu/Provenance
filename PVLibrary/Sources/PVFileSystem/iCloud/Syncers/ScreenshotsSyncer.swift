//
//  ScreenshotsSyncer.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 10/11/24.
//

import Foundation
import SwiftCloudDrive

public extension RootRelativePath {
    static let screenshots = Self(path: "Screenshots")
}


public class ScreenshotsSyncer: CommonSyncer {
    
    public var relativeRootPath: RootRelativePath { .screenshots }

    public func sync() async throws {
    }
}
