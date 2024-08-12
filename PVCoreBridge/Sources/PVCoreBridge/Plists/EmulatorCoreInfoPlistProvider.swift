//
//  EmulatorCoreInfoPlistProvider.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation
import PVPlists

@objc
public protocol EmulatorCoreInfoPlistProvider {
    static var corePlist: EmulatorCoreInfoPlist { get }
    static var resourceBundle: Bundle { get }
}

public extension EmulatorCoreInfoPlistProvider {
    public var corePlist: EmulatorCoreInfoPlist { Self.corePlist }
    public var resourceBundle: Bundle { Self.resourceBundle }
}

public extension EmulatorCoreInfoProvider where Self: EmulatorCoreInfoPlistProvider {
    public var identifier: String { Self.corePlist.identifier }
    public var principleClass: String { Self.corePlist.principleClass }
    public var supportedSystems: [String] { Self.corePlist.supportedSystems }
    public var projectName: String { Self.corePlist.projectName }
    public var projectURL: String { Self.corePlist.projectURL }
    public var projectVersion: String { Self.corePlist.projectVersion }
}
