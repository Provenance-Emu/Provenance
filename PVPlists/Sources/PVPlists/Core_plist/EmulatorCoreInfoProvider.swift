//
//  EmulatorCoreInfoProvider.swift
//  PVCoreBridge
//
//  Created by Joseph Mattiello on 8/12/24.
//

import Foundation
import PVPrimitives

public protocol EmulatorCoreInfoProvider {
    var identifier: String { get }
    var principleClass: String { get }

    var supportedSystems: [String] { get }

    var projectName: String { get }
    var projectURL: String { get }
    var projectVersion: String { get }
    var disabled: Bool { get }
    var contentless: Bool { get }
    var appStoreDisabled: Bool { get }
    /// The cheat code formats declared as supported by this core.
    var supportedCheatTypes: [CheatCodeTypes] { get }
    var subCores: [Self]? { get }
    /// SPDX license identifier (e.g. `"GPL-2.0-only"`, `"MIT"`). `nil` if not specified.
    var licenseName: String? { get }
    /// URL to the full license text. `nil` if not specified.
    var licenseURL: String? { get }
    /// Copyright statement(s) for this core. `nil` if not specified.
    var copyright: String? { get }
}

public extension EmulatorCoreInfoProvider {
    var supportedCheatTypes: [CheatCodeTypes] { [] }
    var licenseName: String? { nil }
    var licenseURL: String? { nil }
    var copyright: String? { nil }
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
    public var contentless: Bool { PVContentless ?? false }
    public var appStoreDisabled: Bool { PVAppStoreDisabled ?? false }
    /// Converts the raw plist string values to typed `CheatCodeTypes`, silently dropping unknowns.
    public var supportedCheatTypes: [CheatCodeTypes] {
        (PVSupportedCheatTypes ?? []).compactMap { CheatCodeTypes(string: $0) }
    }
    public var subCores: [CorePlistEntry]? { PVCores }
    public var licenseName: String? { PVLicenseName }
    public var licenseURL: String? { PVLicenseURL }
    public var copyright: String? { PVCopyright }
}
