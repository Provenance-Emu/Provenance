//
//  CorePlistEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public struct CorePlistEntry: Codable, Equatable, Hashable {
    public let PVCoreIdentifier: String
    public let PVPrincipleClass: String
    public let PVSupportedSystems: [String]
    public let PVProjectName: String
    public let PVProjectURL: String
    public let PVProjectVersion: String
    public let PVDisabled: Bool?
    public let PVCores: [CorePlistEntry]? // SubCoreEntry
}

public extension CorePlistEntry {
    init(_ plist: EmulatorCoreInfoPlist) {
        let subCores = plist.subCores?.map { CorePlistEntry($0) }
        self.init(PVCoreIdentifier: plist.identifier, PVPrincipleClass: plist.principleClass, PVSupportedSystems: plist.supportedSystems, PVProjectName: plist.projectName, PVProjectURL: plist.projectURL, PVProjectVersion: plist.projectVersion, PVDisabled: plist.disabled, PVCores: subCores)
    }
}

func ==(lhs: CorePlistEntry, rhs: EmulatorCoreInfoPlist) -> Bool {
    let subCores = rhs.subCores?.map { CorePlistEntry($0) }
    return rhs.identifier == lhs.PVCoreIdentifier &&
    rhs.principleClass == lhs.PVPrincipleClass &&
    rhs.supportedSystems == lhs.PVSupportedSystems &&
    rhs.projectName == lhs.PVProjectName &&
    rhs.projectURL == lhs.PVProjectURL &&
    rhs.projectVersion == lhs.PVProjectVersion &&
    rhs.disabled == lhs.PVDisabled
    && subCores == lhs.PVCores
}
