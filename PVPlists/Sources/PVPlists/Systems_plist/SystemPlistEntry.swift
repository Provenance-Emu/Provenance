//
//  SystemPlistEntry.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

public struct SystemPlistEntry: Codable, Equatable, Hashable {
    public private(set) var PVSystemIdentifier: String
    public private(set) var PVDatabaseID: String
    public private(set) var PVRequiresBIOS: Bool?
    public private(set) var PVManufacturer: String
    public private(set) var PVBit: String
    public private(set) var PVReleaseYear: String
    public private(set) var PVSystemName: String
    public private(set) var PVSystemShortName: String
    public private(set) var PVSystemShortNameAlt: String?
    public private(set) var PVBIOSNames: [SystemPlistBIOSEntry]?
    public private(set) var PVSupportedExtensions: [String]
    public private(set) var PVControlLayout: [ControlLayoutEntry]
    public private(set) var PVHeaderByteSize: Int?
    public private(set) var PVUsesCDs: Bool?
    public private(set) var PVPortable: Bool?
    public private(set) var PVScreenType: String?
    public private(set) var PVSupportsRumble: Bool?
    public private(set) var PVAppStoreDisabled: Bool?
}
