//
//  PVSystem.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import RealmSwift
import PVSupport
#if os(tvOS)
import TVServices
#endif

public enum ScreenType: String {
    case unknown = ""
    case monochromaticLCD = "MonoLCD"
    case colorLCD = "ColorLCD"
    case crt = "CRT"
    case modern = "Modern"
}

@objcMembers
public final class PVSystem: Object {
    dynamic public var name: String = ""
    dynamic public var shortName: String = ""
    dynamic public var shortNameAlt: String?
    dynamic public var manufacturer: String = ""
    dynamic public var releaseYear: Int = 0
    dynamic public var bit: Int = 0
    dynamic public var headerByteSize: Int = 0
    dynamic public var openvgDatabaseID: Int = 0
    dynamic public var requiresBIOS: Bool = false
    dynamic public var usesCDs: Bool = false
    dynamic public var portableSystem: Bool = false
    dynamic public var supportsRumble: Bool = false
    dynamic public var _screenType: String = ScreenType.unknown.rawValue

    public private(set) var supportedExtensions = List<String>()

    // Reverse Links
    public private(set) var bioses = LinkingObjects(fromType: PVBIOS.self, property: "system")
    public private(set) var games = LinkingObjects(fromType: PVGame.self, property: "system")
    public private(set) var cores = LinkingObjects(fromType: PVCore.self, property: "supportedSystems")

	dynamic public var userPreferredCoreID : String?

    dynamic public var identifier: String = ""

    override public static func primaryKey() -> String? {
        return "identifier"
    }

    // Hack to store controller layout because I don't want to make
    // all the complex objects it would require. Just store the plist dictionary data
    @objc dynamic private var controlLayoutData: Data?
    public var controllerLayout: [ControlLayoutEntry]? {
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
    public var screenType: ScreenType {
        get {
            return ScreenType(rawValue: _screenType)!
        }
        set {
//            try? realm?.write {
                _screenType = newValue.rawValue
//            }
        }
    }

    public var enumValue: SystemIdentifier {
        return SystemIdentifier(rawValue: identifier) ?? .Unknown
    }

    public var biosesHave: [PVBIOS]? {
        let have = bioses.filter({ (bios) -> Bool in
            return !bios.missing
        })

        return !have.isEmpty ? Array(have) : nil
    }

    public var missingBIOSes: [PVBIOS]? {
        let missing = bioses.filter({ (bios) -> Bool in
            return bios.missing
        })

        return !missing.isEmpty ? Array(missing) : nil
    }

    public var hasAllRequiredBIOSes: Bool {
        return missingBIOSes != nil
    }

	#if os(tvOS)
    public var imageType: TVContentItemImageShape {
        switch self.enumValue {
        case .NES, .Genesis, .SegaCD, .MasterSystem, .SG1000, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .Lynx, .WonderSwan, .WonderSwanColor:
            return .poster
        case .GameGear, .GB, .GBC, .GBA, .NGP, .NGPC, .PSX, .VirtualBoy, .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .Unknown:
            return .square
        case .N64, .SNES:
            return .HDTV
        }
    }
	#endif
}
