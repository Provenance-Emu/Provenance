//
//  System.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 9/5/24.
//

#if canImport(SwiftData)
import SwiftData
import Foundation
import PVLogging
import PVPlists
import PVPrimitives
import PVSystems

#if os(tvOS)
import TVServices
#endif

@Model
public class System_Data {
    public var name: String = ""
    public var shortName: String = ""
    public var shortNameAlt: String?
    public var manufacturer: String = ""
    public var releaseYear: Int = 0
    public var bit: Int = 0

    public var headerByteSize: Int = 0
    public var openvgDatabaseID: Int = 0
    public var requiresBIOS: Bool = false
    public var usesCDs: Bool = false
    public var portableSystem: Bool = false

    public var supportsRumble: Bool = false
    public var supported: Bool = true

    public var _screenType: String = ScreenType.unknown.rawValue

    public var supportedExtensions: [String] = []

    public var userPreferredCoreID: String?

    @Attribute(.unique) public var identifier: String = ""

    // Controller layout stored as JSON-encoded Data
    public var controlLayoutData: Data?

    // One-to-many: BIOS entries for this system (system owns its BIOSes)
    @Relationship(deleteRule: .cascade, inverse: \BIOS_Data.system)
    public var bioses: [BIOS_Data] = []

    // One-to-many: games for this system (system owns its games)
    @Relationship(deleteRule: .cascade, inverse: \Game_Data.system)
    public var games: [Game_Data] = []

    // Many-to-many: cores that support this system (inverse on Core_Data.supportedSystems)
    @Relationship(inverse: \Core_Data.supportedSystems)
    public var cores: [Core_Data] = []

    public var bits: SystemBits { SystemBits(rawValue: bit) ?? .unknown }

    public var options: SystemOptions {
        var systemOptions = [SystemOptions]()
        if usesCDs { systemOptions.append(.cds) }
        if portableSystem { systemOptions.append(.portable) }
        if supportsRumble { systemOptions.append(.rumble) }
        return SystemOptions(systemOptions)
    }

    public var extensions: [String] { supportedExtensions }

    public var BIOSes: [BIOS_Data]? { bioses.isEmpty ? nil : bioses }

    public var userPreferredCore: Core? {
        // TODO: Implement lookup via ModelContext
        return nil
    }

    public var controllerLayout: [ControlLayoutEntry]? {
        get {
            guard let controlLayoutData else { return nil }
            return try? JSONDecoder().decode([ControlLayoutEntry].self, from: controlLayoutData)
        }
        set {
            guard let newValue else { controlLayoutData = nil; return }
            controlLayoutData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(name: String = "", shortName: String = "", shortNameAlt: String? = nil,
                manufacturer: String = "", releaseYear: Int = 0, bit: Int = 0,
                headerByteSize: Int = 0, openvgDatabaseID: Int = 0,
                requiresBIOS: Bool = false, usesCDs: Bool = false, portableSystem: Bool = false,
                supportsRumble: Bool = false, supported: Bool = true,
                screenType: String = ScreenType.unknown.rawValue,
                supportedExtensions: [String] = [], bioses: [BIOS_Data] = [],
                games: [Game_Data] = [], cores: [Core_Data] = [],
                userPreferredCoreID: String? = nil, identifier: String = "",
                controlLayoutData: Data? = nil) {
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
        self._screenType = screenType
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
        get { ScreenType(rawValue: _screenType) ?? .unknown }
        set { _screenType = newValue.rawValue }
    }

    var enumValue: SystemIdentifier {
        SystemIdentifier(rawValue: identifier) ?? .Unknown
    }

    var biosesHave: [BIOS_Data]? {
        // TODO: filter by BIOS file presence
        return nil
    }

    var missingBIOSes: [BIOS_Data]? {
        // TODO: filter by BIOS file absence
        return nil
    }

    var hasAllRequiredBIOSes: Bool { missingBIOSes == nil }

    #if os(tvOS)
    var imageType: TVContentItemImageShape {
        switch enumValue {
        case .NES, .Dreamcast, .GameCube, .Genesis, .Saturn, .SegaCD, .MasterSystem,
             .SG1000, .Sega32X, .Atari2600, .Atari5200, .Atari7800, .AtariJaguar,
             .AtariJaguarCD, .Lynx, .WonderSwan, .WonderSwanColor, .PS2, .PS3, .PSP,
             .Intellivision, .ColecoVision, ._3DO, .Odyssey2, .Atari8bit, .Vectrex,
             .DOS, .AtariST, .EP128, .Macintosh, .MSX, .MSX2, .Supervision, .ZXSpectrum,
             .C64, .Wii, .PalmOS, .TIC80, .AppleII, .MAME:
            return .poster
        case .GameGear, .GB, .GBC, .GBA, .NeoGeo, .NGP, .NGPC, .PSX, .VirtualBoy,
             .PCE, .PCECD, .PCFX, .SGFX, .FDS, .PokemonMini, .DS, .Unknown, .Music,
             ._3DS, .MegaDuck:
            return .square
        case .N64, .SNES:
            return .HDTV
        }
    }
    #endif
}

#endif
