//
//  PVSystem.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift

public enum ScreenType: String {
    case unknown = ""
    case monochromaticLCD = "MonoLCD"
    case colorLCD = "ColorLCD"
    case crt = "CRT"
    case modern = "Modern"
}

@objcMembers public class PVSystem: Object {
    dynamic var name: String = ""
    dynamic var shortName: String = ""
    dynamic var shortNameAlt: String?
    dynamic var manufacturer: String = ""
    dynamic var releaseYear: Int = 0
    dynamic var bit: Int = 0
    dynamic var headerByteSize: Int = 0
    dynamic var openvgDatabaseID: Int = 0
    dynamic var requiresBIOS: Bool = false
    dynamic var usesCDs: Bool = false
    dynamic var portableSystem: Bool = false
    dynamic var supportsRumble: Bool = false
    dynamic var _screenType: String = ScreenType.unknown.rawValue

    var supportedExtensions = List<String>()

    // Reverse Links
    var bioses = LinkingObjects(fromType: PVBIOS.self, property: "system")
    var games = LinkingObjects(fromType: PVGame.self, property: "system")
    var cores = LinkingObjects(fromType: PVCore.self, property: "supportedSystems")

	dynamic var userPreferredCoreID : String?

    dynamic var identifier: String = ""

    override public static func primaryKey() -> String? {
        return "identifier"
    }

    // Hack to store controller layout because I don't want to make
    // all the complex objects it would require. Just store the plist dictionary data
    @objc private dynamic var controlLayoutData: Data?
    var controllerLayout: [ControlLayoutEntry]? {
        get {
            guard let controlLayoutData = controlLayoutData else {
                return nil
            }
            do {
                let dict = try JSONDecoder().decode([ControlLayoutEntry].self, from: controlLayoutData)
                return dict
            } catch {
                return nil
            }
        }

        set {
            guard let newDictionaryData = newValue else {
                controlLayoutData = nil
                return
            }

            do {
                let data = try JSONEncoder().encode(newDictionaryData)
                controlLayoutData = data
            } catch {
                controlLayoutData = nil
                ELOG("\(error)")
            }
        }
    }

    override public static func ignoredProperties() -> [String] {
        return ["controllerLayout"]
    }
}

public extension PVSystem {
    var screenType: ScreenType {
        get {
            return ScreenType(rawValue: _screenType)!
        }
        set {
//            try? realm?.write {
                _screenType = newValue.rawValue
//            }
        }
    }

    var enumValue: SystemIdentifier {
        return SystemIdentifier(rawValue: identifier) ?? .Unknown
    }

    var biosesHave: [PVBIOS]? {
        let have = bioses.filter({ (bios) -> Bool in
            return !bios.missing
        })

        return !have.isEmpty ? Array(have) : nil
    }

    var missingBIOSes: [PVBIOS]? {
        let missing = bioses.filter({ (bios) -> Bool in
            return bios.missing
        })

        return !missing.isEmpty ? Array(missing) : nil
    }

    var hasAllRequiredBIOSes: Bool {
        return missingBIOSes != nil
    }
}
