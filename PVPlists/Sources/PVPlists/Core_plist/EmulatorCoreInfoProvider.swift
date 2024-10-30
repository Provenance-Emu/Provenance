//
//  EmulatorCoreInfoProvider.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation
import PVPlists

public protocol EmulatorCoreInfoProvider {
    var identifier: String { get }
    var principleClass: String { get }

    var supportedSystems: [String] { get }

    var projectName: String { get }
    var projectURL: String { get }
    var projectVersion: String { get }
    var disabled: Bool { get }
    var subCores: [Self]? { get }
}

extension EmulatorCoreInfoPlist: EmulatorCoreInfoProvider { }

extension CorePlistEntry: EmulatorCoreInfoProvider {

    public var identifier: String { PVCoreIdentifier }
    public var principleClass: String { PVPrincipleClass }
    public var supportedSystems: [String] { PVSupportedSystems }
    public var projectName: String { PVProjectName }
    public var projectURL: String { PVProjectURL }
    public var projectVersion: String { PVProjectVersion }
    public var disabled: Bool { PVDisabled ?? false }
    public var subCores: [CorePlistEntry]? { subCores }
}
