//
//  PlistDataModels.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

// MARK: - Systems.plist

public struct SystemPlistBIOSEntry: Codable, Equatable, Hashable {
    public private(set) var Description: String
    public private(set) var MD5: String
    public private(set) var Name: String
    public private(set) var Size: Int
    public private(set) var Optional: Bool?
}

public struct ControlGroupButton: Codable, Equatable, Hashable {
    public let PVControlType: String
    public let PVControlTitle: String
    public let PVControlFrame: String
    public let PVControlTint: String?
}

public struct PVImporterOptions: Codable, Equatable, Hashable {
    public private(set) var PVImporterUseFolders: Bool?
}

public struct ControlLayoutEntry: Codable, Equatable, Hashable {
    public let PVControlType: String
    public let PVControlSize: String
    public let PVControlTitle: String?
    public let PVControlTint: String?
    public let PVGroupedButtons: [ControlGroupButton]?

    private enum CodingKeys: String, CodingKey {
        case PVControlType
        case PVControlSize
        case PVControlTitle
        case PVControlTint
        case PVGroupedButtons
    }
}

public extension ControlLayoutEntry {
    var dictionaryValue: [String: Any] {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dictionary!
        } catch {
            fatalError("Bad serialzied data")
        }
    }
}

// MARK: Systems.plist

public struct SytemPlistEntry: Codable, Equatable, Hashable {
    public private(set) var PVSystemIdentifier: String
    public private(set) var PVDatabaseID: String
    public private(set) var PVRequiresBIOS: Bool?
    public private(set) var PVManufacturer: String
    public private(set) var PVBit: String
    public private(set) var PVReleaseYear: String
    public private(set) var PVSystemName: String
    public private(set) var PVSystemShortName: String
    public private(set) var PVPlayerCount: String?
    public private(set) var PVSystemShortNameAlt: String?
    public private(set) var PVBIOSNames: [SystemPlistBIOSEntry]?
    public private(set) var PVSupportedExtensions: [String]
    public private(set) var PVControlLayout: [ControlLayoutEntry]
    public private(set) var PVHeaderByteSize: Int?
    public private(set) var PVUsesCDs: Bool?
    public private(set) var PVPortable: Bool?
    public private(set) var PVScreenType: String?
    public private(set) var PVSupportsRumble: Bool?
    public private(set) var PVImporterOptions: PVImporterOptions?

    public private(set) var PVRequiresMouse: Bool?
    public private(set) var PVRequiresKeyboard: Bool?
}

// MARK: Core.plist

public struct CorePlistEntry: Codable, Equatable, Hashable {
    public let PVCoreIdentifier: String
    public let PVPrincipleClass: String
    public let PVSupportedSystems: [String]
    public let PVProjectName: String
    public let PVProjectURL: String
    public let PVProjectVersion: String
    public let PVDisabled: Bool?
}
