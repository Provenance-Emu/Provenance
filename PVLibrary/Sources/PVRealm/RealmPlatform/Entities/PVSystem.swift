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

    @Persisted(indexed: true) public var name: String = ""
    @Persisted public var shortName: String = ""
    @Persisted public var shortNameAlt: String?
    @Persisted public var manufacturer: String = ""
    @Persisted public var releaseYear: Int = 0
    @Persisted public var bit: Int = 0
    public var bits: SystemBits {
        return SystemBits(rawValue: bit) ?? .unknown
    }

    @Persisted public var headerByteSize: Int = 0
    @Persisted public var openvgDatabaseID: Int = 0
    @Persisted public var requiresBIOS: Bool = false
    @Persisted public var usesCDs: Bool = false
    @Persisted public var portableSystem: Bool = false

    @Persisted public var supportsRumble: Bool = false
    @Persisted public var supported: Bool = true
    @Persisted public var appStoreDisabled: Bool = false

    @Persisted public var _screenType: String = ScreenType.unknown.rawValue

    public var options: SystemOptions {
        var systemOptions = [SystemOptions]()
        if usesCDs { systemOptions.append(.cds) }
        if portableSystem { systemOptions.append(.portable) }
        if supportsRumble { systemOptions.append(.rumble) }

        return SystemOptions(systemOptions)
    }

    @Persisted public private(set) var supportedExtensions: List<String>

    public var BIOSes: [PVBIOS]? {
        return Array(bioses)
    }

    public var extensions: [String] {
		return supportedExtensions.map { $0 }
    }

    // Reverse Links
    @Persisted(originProperty: "system") public private(set) var bioses: LinkingObjects<PVBIOS>
    @Persisted(originProperty: "system") public private(set) var games: LinkingObjects<PVGame>
    @Persisted(originProperty: "supportedSystems") public private(set) var cores: LinkingObjects<PVCore>

    public lazy var gameStructs: () -> [Game] = { [self] in
        games.map( { Game(withGame: $0) } )
    }

    public lazy var coreStructs: () -> [Core] = { [self] in
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

    @Persisted public var userPreferredCoreID: String?

    @Persisted(primaryKey: true) public var identifier: String = ""

    // Hack to store controller layout because I don't want to make
    // all the complex objects it would require. Just store the plist dictionary data

    @Persisted internal dynamic var controlLayoutData: Data?
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
        return ["controllerLayout", "gameStructs", "coreStructs"]
    }
}

/// Mock testing
public extension PVSystem {
    public convenience init(
        identifier: String,
        name: String,
        shortName: String,
        manufacturer: String,
        screenType: ScreenType = .crt
    ) {
        self.init()
        self.identifier = id
        self.name = name
        self.shortName = shortName
        self.manufacturer = manufacturer
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
            case .GameGear, .GB, .GBC, .GBA, .NeoGeo, .NGP, .NGPC, .PSX, .VirtualBoy, .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .DS, .Unknown, .Music, ._3DS, .MegaDuck, .RetroArch:
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
