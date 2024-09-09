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
import PVLogging
import AsyncAlgorithms
import PVPlists
import PVPrimitives
import Systems

public extension AsyncSequence {
    
    /// Collects all elements of the sequence into an array.
    /// - Returns: An array of all elements in the sequence
    func collect() async rethrows -> [Element] {
        try await reduce(into: [Element]()) { $0.append($1) }
    }
}

#if os(tvOS)
    import TVServices
#endif

@objcMembers
public final class PVSystem: Object, Identifiable, SystemProtocol {
//    public var gameStructs: [Game]
    
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
    public dynamic var supported: Bool = true

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

    public var gameStructs: [Game] { get {
        games.map( { Game(withGame: $0) } )
    }}

    public var coreStructs: [Core] {
        let _cores: [Core]  = cores.map { Core(with: $0) }
        return _cores
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

    var biosesHave: [PVBIOS]? { get async {
        let have = await bioses.toArray().async.filter({ (bios) -> Bool in
            bios.online
        }).map(\.self).collect()

        return have.count > 0 ? have : nil
    }}

    var missingBIOSes: [PVBIOS]? { get async {
        let missing = await bioses.async.filter({ (bios) -> Bool in
            !bios.online
        }).map(\.self).collect()

        return !missing.isEmpty ? Array(missing) : nil
    }}

    var hasAllRequiredBIOSes: Bool { get async {
        return await missingBIOSes != nil
    }}

    #if os(tvOS)
        var imageType: TVContentItemImageShape {
            switch enumValue {
            case .NES, .Dreamcast, .GameCube, .Genesis, .Saturn, .SegaCD, .MasterSystem, .SG1000, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .AtariJaguar, .AtariJaguarCD, .Lynx, .WonderSwan, .WonderSwanColor, .PS2, .PS3, .PSP, .Intellivision, .ColecoVision, ._3DO, .Odyssey2, .Atari8bit, .Vectrex, .DOS, .AtariST, .EP128, .Macintosh, .MSX, .MSX2, .Supervision, .ZXSpectrum, .C64, .Wii, .PalmOS, .TIC80, .AppleII, .MAME:
                return .poster
            case .GameGear, .GB, .GBC, .GBA, .NeoGeo, .NGP, .NGPC, .PSX, .VirtualBoy, .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .DS, .Unknown, .Music, ._3DS, .MegaDuck:
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

    public func asRealm() async -> PVSystem {
        return await PVSystem.build({ object in
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
            #warning("TODO: BIOSes")
//            let database = RomDatabase.sharedInstance
//            BIOSes?.forEach { entry in
//                if let existingBIOS = database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: entry.expectedFilename) {
//                    if database.realm.isInWriteTransaction {
//                        existingBIOS.system = object
//                    } else {
//						do {
//							try database.writeTransaction {
//								existingBIOS.system = object
//							}
//						} catch {
//							ELOG("\(error.localizedDescription)")
//						}
//                    }
//                } else {
//                    let newBIOS = PVBIOS(withSystem: object, descriptionText: entry.descriptionText, optional: entry.optional, expectedMD5: entry.expectedMD5, expectedSize: entry.expectedSize, expectedFilename: entry.expectedFilename)
//
//                    if database.realm.isInWriteTransaction {
//                        database.realm.add(newBIOS)
//                    } else {
//						do {
//							try database.add(newBIOS)
//						} catch {
//							ELOG("\(error.localizedDescription)")
//						}
//                    }
//                }
//            }
            object.userPreferredCoreID = userPreferredCore?.identifier

            // TODO: Controler layouts?
//            object.controllerLayout = controlLayout
            object.portableSystem = portableSystem
            object.usesCDs = usesCDs
            object.supportsRumble = supportsRumble
            object.supported = supported
            object.headerByteSize = headerByteSize
        })
    }
}
