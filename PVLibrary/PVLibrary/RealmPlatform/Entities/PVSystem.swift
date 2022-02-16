//
//  PVSystem.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/11/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
#if os(tvOS)
    import TVServices
#endif

public enum ScreenType: String, Codable {
    case unknown = ""
    case monochromaticLCD = "MonoLCD"
    case colorLCD = "ColorLCD"
    case crt = "CRT"
    case modern = "Modern"
}

public struct SystemOptions: OptionSet, Codable {
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int

    public static let cds = SystemOptions(rawValue: 1 << 0)
    public static let portable = SystemOptions(rawValue: 1 << 1)
    public static let rumble = SystemOptions(rawValue: 1 << 2)
}

@objcMembers
public final class PVSystem: Object, Identifiable, SystemProtocol {
    public typealias BIOSInfoProviderType = PVBIOS

    public dynamic var name: String = ""
    public dynamic var shortName: String = ""
    public dynamic var shortNameAlt: String?
    public dynamic var manufacturer: String = ""
    public dynamic var releaseYear: Int = 0
    public dynamic var bit: Int = 0
    public var bits: SystemBits {
        return SystemBits(rawValue: bit) ?? .unknown
    }

    public dynamic var headerByteSize: Int = 0
    public dynamic var openvgDatabaseID: Int = 0
    public dynamic var requiresBIOS: Bool = false
    public dynamic var usesCDs: Bool = false
    public dynamic var portableSystem: Bool = false

    public dynamic var supportsRumble: Bool = false
    public dynamic var _screenType: String = ScreenType.unknown.rawValue

    public var options: SystemOptions {
        var systemOptions = [SystemOptions]()
        if usesCDs { systemOptions.append(.cds) }
        if portableSystem { systemOptions.append(.portable) }
        if supportsRumble { systemOptions.append(.rumble) }

        return SystemOptions(systemOptions)
    }

    public private(set) var supportedExtensions = List<String>()

    public var BIOSes: [PVBIOS]? {
        return Array(bioses)
    }

    public var extensions: [String] {
		return supportedExtensions.map { $0 }
    }

    // Reverse Links
    public private(set) var bioses = LinkingObjects(fromType: PVBIOS.self, property: "system")
    public private(set) var games = LinkingObjects(fromType: PVGame.self, property: "system")
    public private(set) var cores = LinkingObjects(fromType: PVCore.self, property: "supportedSystems")

    public var gameStructs: [Game] {
        return games.map { Game(withGame: $0) }
    }

    public var coreStructs: [Core] {
        return cores.map { Core(with: $0) }
    }

    public var userPreferredCore: Core? {
        guard let userPreferredCoreID = userPreferredCoreID,
            let realm = try? Realm(),
            let preferredCore = realm.object(ofType: PVCore.self, forPrimaryKey: userPreferredCoreID) else {
            return nil
        }
        return Core(with: preferredCore)
    }

    public dynamic var userPreferredCoreID: String?

    public dynamic var identifier: String = ""

    public override static func primaryKey() -> String? {
        return "identifier"
    }

    // Hack to store controller layout because I don't want to make
    // all the complex objects it would require. Just store the plist dictionary data

    internal dynamic var controlLayoutData: Data?
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

    public override static func ignoredProperties() -> [String] {
        return ["controllerLayout"]
    }
}

public extension PVSystem {
    var screenType: ScreenType {
        get {
			return ScreenType(rawValue: _screenType) ?? .unknown
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
            bios.online
        })

        return !have.isEmpty ? Array(have) : nil
    }

    var missingBIOSes: [PVBIOS]? {
        let missing = bioses.filter({ (bios) -> Bool in
            !bios.online
        })

        return !missing.isEmpty ? Array(missing) : nil
    }

    var hasAllRequiredBIOSes: Bool {
        return missingBIOSes != nil
    }

    #if os(tvOS)
        var imageType: TVContentItemImageShape {
            switch enumValue {
            case .NES, .Dreamcast, .GameCube, .Genesis, .Saturn, .SegaCD, .MasterSystem, .SG1000, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .Lynx, .WonderSwan, .WonderSwanColor, .PS2, .PS3, .PSP, .Intellivision, .ColecoVision, ._3DO, .Odyssey2, .Atari8bit, .Vectrex:
                return .poster
            case .GameGear, .GB, .GBC, .GBA, .NeoGeo, .NGP, .NGPC, .PSX, .VirtualBoy, .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .DS, .Unknown:
                return .square
            case .N64, .SNES:
                return .HDTV
            }
        }
    #endif
}

extension PVSystem: DomainConvertibleType {
    public typealias DomainType = System

    public func asDomain() -> System {
        return System(with: self)
    }
}

extension System: RealmRepresentable {
    public var uid: String {
        return identifier
    }

    public func asRealm() -> PVSystem {
        return PVSystem.build({ object in
            object.name = name
            object.shortName = shortName
            object.shortNameAlt = shortNameAlt

            object.identifier = identifier

            object.manufacturer = manufacturer
            object.releaseYear = releaseYear
            object.bit = bits.rawValue

            object.openvgDatabaseID = openvgDatabaseID
            object.headerByteSize = headerByteSize
            object.requiresBIOS = requiresBIOS

            // Extensions
            object.supportedExtensions.removeAll()
            object.supportedExtensions.append(objectsIn: extensions)

            // BIOSes
            let database = RomDatabase.sharedInstance
            BIOSes?.forEach { entry in
                if let existingBIOS = database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: entry.expectedFilename) {
                    if database.realm.isInWriteTransaction {
                        existingBIOS.system = object
                    } else {
						do {
							try database.writeTransaction {
								existingBIOS.system = object
							}
						} catch {
							ELOG("\(error.localizedDescription)")
						}
                    }
                } else {
                    let newBIOS = PVBIOS(withSystem: object, descriptionText: entry.descriptionText, optional: entry.optional, expectedMD5: entry.expectedMD5, expectedSize: entry.expectedSize, expectedFilename: entry.expectedFilename)

                    if database.realm.isInWriteTransaction {
                        database.realm.add(newBIOS)
                    } else {
						do {
							try database.add(newBIOS)
						} catch {
							ELOG("\(error.localizedDescription)")
						}
                    }
                }
            }
            object.userPreferredCoreID = userPreferredCore?.identifier

            // TODO: Controler layouts?
//            object.controllerLayout = controlLayout
            object.portableSystem = portableSystem
            object.usesCDs = usesCDs
            object.supportsRumble = supportsRumble
            object.headerByteSize = headerByteSize
        })
    }
}
