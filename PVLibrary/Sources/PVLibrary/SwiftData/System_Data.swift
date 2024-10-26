//
//  System.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData) && !os(tvOS)
import SwiftData
import Foundation
import PVSupport
import RealmSwift
import PVLogging
import AsyncAlgorithms
import PVPlists
import PVPrimitives
import Systems

#if os(tvOS)
import TVServices
#endif

@Model
public class System_Data {
    public typealias BIOSInfoProviderType = BIOS_Data

    public var name: String = ""
    public var shortName: String = ""
    public var shortNameAlt: String?
    public var manufacturer: String = ""
    public var releaseYear: Int = 0
    public var bit: Int = 0
    public var bits: SystemBits {
        return SystemBits(rawValue: bit) ?? .unknown
    }

    public var headerByteSize: Int = 0
    public var openvgDatabaseID: Int = 0
    public var requiresBIOS: Bool = false
    public var usesCDs: Bool = false
    public var portableSystem: Bool = false

    public var supportsRumble: Bool = false
    public var supported: Bool = true

    public var _screenType: String = ScreenType.unknown.rawValue

    public var options: SystemOptions {
        var systemOptions = [SystemOptions]()
        if usesCDs { systemOptions.append(.cds) }
        if portableSystem { systemOptions.append(.portable) }
        if supportsRumble { systemOptions.append(.rumble) }

        return SystemOptions(systemOptions)
    }

    public private(set) var supportedExtensions: [String] = []

    public var BIOSes: [BIOS_Data]? {
        return Array(bioses)
    }

    public var extensions: [String] {
        return supportedExtensions.map { $0 }
    }

    // Reverse Links
    public private(set) var bioses: [BIOS_Data]
    public private(set) var games: [Game_Data]
    public private(set) var cores: [Core_Data]

//    public var gameStructs: [Game] { get {
//        games.map( { Game(withGame: $0) } )
//    }}
//
//    public var coreStructs: [Core] {
//        let _cores: [Core]  = cores.map { Core(with: $0) }
//        return _cores
//    }

    public var userPreferredCore: Core? {
        
        #warning("TODO: Implement this")
//        guard let userPreferredCoreID = userPreferredCoreID,
//            let realm = try? Realm(),
//            let preferredCore = realm.object(ofType: PVCore.self, forPrimaryKey: userPreferredCoreID) else {
//            return nil
//        }
//        return Core(with: preferredCore)
        return nil
    }

    public var userPreferredCoreID: String?

    public var identifier: String = ""


    // Hack to store controller layout because I don't want to make
    // all the complex objects it would require. Just store the plist dictionary data

    internal var controlLayoutData: Data?
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

    init(name: String, shortName: String, shortNameAlt: String? = nil, manufacturer: String, releaseYear: Int, bit: Int, headerByteSize: Int, openvgDatabaseID: Int, requiresBIOS: Bool, usesCDs: Bool, portableSystem: Bool, supportsRumble: Bool, supported: Bool, _screenType: String, supportedExtensions: [String], bioses: [BIOS_Data], games: [Game_Data], cores: [Core_Data], userPreferredCoreID: String? = nil, identifier: String, controlLayoutData: Data? = nil) {
        self.name = name
        self.shortName = shortName
        self.shortNameAlt = shortNameAlt
        self.manufacturer = manufacturer
        self.releaseYear = releaseYear
        self.bit = bit
        self.headerByteSize = headerByteSize
        self.openvgDatabaseID = openvgDatabaseID
        self.requiresBIOS = requiresBIOS
        self.usesCDs = usesCDs
        self.portableSystem = portableSystem
        self.supportsRumble = supportsRumble
        self.supported = supported
        self._screenType = _screenType
        self.supportedExtensions = supportedExtensions
        self.bioses = bioses
        self.games = games
        self.cores = cores
        self.userPreferredCoreID = userPreferredCoreID
        self.identifier = identifier
        self.controlLayoutData = controlLayoutData
    }
}

public extension System_Data {
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

    var biosesHave: [BIOS_Data]? { get  {
        #warning("TODO: Implement this")
//        let have = bioses.filter({ (bios) -> Bool in
//            bios.online
//        }).map(\.self).collect()
//
//        return have.count > 0 ? have : nil
        return nil
    }}

    var missingBIOSes: [BIOS_Data]? { get async {
#warning("TODO: Implement this")
//        let missing = await bioses.async.filter({ (bios) -> Bool in
//            !bios.online
//        }).map(\.self).collect()
//
//        return !missing.isEmpty ? Array(missing) : nil
        return nil
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

#endif
