//
//  EmulatorCoreInfoPlistProvider.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation
import PVPlists

@objc public protocol EmulatorCoreInfoPlistProvider {
    static var corePlist: EmulatorCoreInfoPlist { get }
    static var resourceBundle: Bundle { get }
}

public extension EmulatorCoreInfoPlistProvider {
    var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
    var resourceBundle: Bundle { Self.resourceBundle }
}

public extension EmulatorCoreInfoProvider where Self: EmulatorCoreInfoPlistProvider {
    var identifier: String { Self.corePlist.identifier }
    var principleClass: String { Self.corePlist.principleClass }
    var supportedSystems: [String] { Self.corePlist.supportedSystems }
    var projectName: String { Self.corePlist.projectName }
    var projectURL: String { Self.corePlist.projectURL }
    var projectVersion: String { Self.corePlist.projectVersion }
}
