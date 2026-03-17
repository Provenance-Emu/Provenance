//
//  CorePlistEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import PVPrimitives

/// Raw Codable representation of a Core.plist dictionary.
///
/// `PVSupportedCheatTypes` is kept as `[String]?` to match the on-disk plist
/// format. Use `EmulatorCoreInfoPlist` or `EmulatorCoreInfoProvider.supportedCheatTypes`
/// to work with typed `[CheatCodeTypes]` values.
public struct CorePlistEntry: Codable, Equatable, Hashable {
    public let PVCoreIdentifier: String
    public let PVPrincipleClass: String
    public let PVSupportedSystems: [String]
    public let PVProjectName: String
    public let PVProjectURL: String
    public let PVProjectVersion: String
    public let PVDisabled: Bool?
    public let PVContentless: Bool?
    public let PVAppStoreDisabled: Bool?
    /// Raw cheat-type display-name strings as stored in Core.plist.
    /// Prefer `EmulatorCoreInfoProvider.supportedCheatTypes` for typed access.
    public let PVSupportedCheatTypes: [String]?
    public let PVCores: [CorePlistEntry]? // SubCoreEntry
    /// JIT requirement level for this core. Mirrors `PVJITRequirement` key in `Core.plist`.
    public let PVJITRequirement: String?
    /// When `true`, this core is currently disabled *only* because JIT is required but
    /// unavailable on the device.  The app layer can auto-enable the core when JIT is
    /// successfully acquired.  Mirrors `PVJITDisabledWithoutJIT` key in `Core.plist`.
    public let PVJITDisabledWithoutJIT: Bool?
    /// SPDX license identifier (e.g. `"GPL-2.0-only"`, `"MIT"`).
    /// Mirrors `PVLicenseName` key in `Core.plist`.
    public let PVLicenseName: String?
    /// URL pointing to the full license text for this core.
    /// Mirrors `PVLicenseURL` key in `Core.plist`.
    public let PVLicenseURL: String?
    /// Copyright statement(s) for this core.
    /// Mirrors `PVCopyright` key in `Core.plist`.
    public let PVCopyright: String?

    public init(
        PVCoreIdentifier: String,
        PVPrincipleClass: String,
        PVSupportedSystems: [String],
        PVProjectName: String,
        PVProjectURL: String,
        PVProjectVersion: String,
        PVDisabled: Bool? = nil,
        PVContentless: Bool? = nil,
        PVAppStoreDisabled: Bool? = nil,
        PVSupportedCheatTypes: [String]? = nil,
        PVCores: [CorePlistEntry]? = nil,
        PVJITRequirement: String? = nil,
        PVJITDisabledWithoutJIT: Bool? = nil,
        PVLicenseName: String? = nil,
        PVLicenseURL: String? = nil,
        PVCopyright: String? = nil
    ) {
        self.PVCoreIdentifier = PVCoreIdentifier
        self.PVPrincipleClass = PVPrincipleClass
        self.PVSupportedSystems = PVSupportedSystems
        self.PVProjectName = PVProjectName
        self.PVProjectURL = PVProjectURL
        self.PVProjectVersion = PVProjectVersion
        self.PVDisabled = PVDisabled
        self.PVContentless = PVContentless
        self.PVAppStoreDisabled = PVAppStoreDisabled
        self.PVSupportedCheatTypes = PVSupportedCheatTypes
        self.PVCores = PVCores
        self.PVJITRequirement = PVJITRequirement
        self.PVJITDisabledWithoutJIT = PVJITDisabledWithoutJIT
        self.PVLicenseName = PVLicenseName
        self.PVLicenseURL = PVLicenseURL
        self.PVCopyright = PVCopyright
    }
}

public extension CorePlistEntry {
    init(_ plist: EmulatorCoreInfoPlist) {
        let subCores = plist.subCores?.map { CorePlistEntry($0) }
        // Convert typed enum values back to display-name strings for serialization.
        let cheatTypeStrings = plist.supportedCheatTypes.isEmpty
            ? nil
            : plist.supportedCheatTypes.map { $0.stringValue }
        self.init(
            PVCoreIdentifier: plist.identifier,
            PVPrincipleClass: plist.principleClass,
            PVSupportedSystems: plist.supportedSystems,
            PVProjectName: plist.projectName,
            PVProjectURL: plist.projectURL,
            PVProjectVersion: plist.projectVersion,
            PVDisabled: plist.disabled,
            PVContentless: plist.contentless,
            PVAppStoreDisabled: plist.appStoreDisabled,
            PVSupportedCheatTypes: cheatTypeStrings,
            PVCores: subCores,
            PVJITRequirement: plist.jitRequirementRawValue,
            PVJITDisabledWithoutJIT: plist.jitDisabledWithoutJIT ? true : nil,
            PVLicenseName: plist.licenseName,
            PVLicenseURL: plist.licenseURL,
            PVCopyright: plist.copyright
        )
    }
}

func ==(lhs: CorePlistEntry, rhs: EmulatorCoreInfoPlist) -> Bool {
    let subCores = rhs.subCores?.map { CorePlistEntry($0) }
    let lhsCheatTypes: [CheatCodeTypes] = (lhs.PVSupportedCheatTypes ?? []).compactMap {
        CheatCodeTypes(string: $0)
    }
    return rhs.identifier == lhs.PVCoreIdentifier &&
    rhs.principleClass == lhs.PVPrincipleClass &&
    rhs.supportedSystems == lhs.PVSupportedSystems &&
    rhs.projectName == lhs.PVProjectName &&
    rhs.projectURL == lhs.PVProjectURL &&
    rhs.projectVersion == lhs.PVProjectVersion &&
    rhs.disabled == (lhs.PVDisabled ?? false) &&
    rhs.contentless == (lhs.PVContentless ?? false) &&
    rhs.appStoreDisabled == (lhs.PVAppStoreDisabled ?? false) &&
    rhs.supportedCheatTypes == lhsCheatTypes &&
    subCores == lhs.PVCores &&
    rhs.jitRequirementRawValue == lhs.PVJITRequirement &&
    rhs.jitDisabledWithoutJIT == (lhs.PVJITDisabledWithoutJIT ?? false) &&
    rhs.licenseName == lhs.PVLicenseName &&
    rhs.licenseURL == lhs.PVLicenseURL &&
    rhs.copyright == lhs.PVCopyright
}
