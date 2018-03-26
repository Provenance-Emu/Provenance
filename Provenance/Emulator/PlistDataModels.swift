//
//  PlistDataModels.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation

// MARK: - Systems.plist
public struct SystemPlistBIOSEntry: Codable {
    var Description: String
    var MD5: String
    var Name: String
    var Size: Int
    var Optional: Bool?
}

public struct ControlGroupButton: Codable {
    let PVControlType: String
    let PVControlTitle: String
    let PVControlFrame: String
    let PVControlTint: String?
}

public struct ControlLayoutEntry: Codable {
    let PVControlType: String
    let PVControlSize: String
    let PVControlTitle: String?
    let PVControlTint: String?
    let PVGroupedButtons: [ControlGroupButton]?

    private enum CodingKeys: String, CodingKey {
        case PVControlType
        case PVControlSize
        case PVControlTitle
        case PVControlTint
        case PVGroupedButtons
    }
}

public extension ControlLayoutEntry {
    public var dictionaryValue: [String: Any] {
        do {
            let data = try JSONEncoder().encode(self)
            let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dictionary!
        } catch {
            fatalError("Bad serialzied data")
        }
    }
}

public struct SytemPlistEntry: Codable {
    var PVSystemIdentifier: String
    var PVDatabaseID: String
    var PVRequiresBIOS: Bool?
    var PVManufacturer: String
    var PVBit: String
    var PVReleaseYear: String
    var PVSystemName: String
    var PVSystemShortName: String
    var PVSystemShortNameAlt: String?
    var PVBIOSNames: [SystemPlistBIOSEntry]?
    var PVSupportedExtensions: [String]
    var PVControlLayout: [ControlLayoutEntry]
    var PVHeaderByteSize: Int?
    var PVUsesCDs: Bool?
    var PVPortable: Bool?
    var PVScreenType: String?
    var PVSupportsRumble: Bool?
}

// MARK: Core.plist
public struct CorePlistEntry: Codable {
    let PVCoreIdentifier: String
    let PVPrincipleClass: String
    let PVSupportedSystems: [String]
    let PVProjectName: String
    let PVProjectURL: String
    let PVProjectVersion: String
}
