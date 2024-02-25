//
//  System.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 11/12/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

public enum SystemBits: Int, Codable {
    case unknown = 0
    case four = 4
    case eight = 8
    case sixteen = 16
    case thirtyTwo = 32
    case sixtyFour = 64
    case oneTwentyEight = 128
}

public enum SystemGeneration: UInt, Codable {
    case none = 0
    case first
    case second
    case third
    case fourth
    case fifth
    case sixth
    case seventh
    case eighth
    case ninth
    case tenth
}

public struct System: Codable, SystemProtocol {
    public let name: String
    public let identifier: String
    public let shortName: String
    public let shortNameAlt: String?
    public let manufacturer: String
    public let releaseYear: Int
    public let bits: SystemBits
    //    public let generation : SystemGeneration

    public let headerByteSize: Int
    public let openvgDatabaseID: Int

    public let requiresBIOS: Bool

    public let options: SystemOptions

    public let BIOSes: [BIOS]?

    public let extensions: [String]

    public let gameStructs: [Game]
    public let coreStructs: [Core]
    public let userPreferredCore: Core?

    public let usesCDs: Bool
    public let portableSystem: Bool

    public let supportsRumble: Bool
    public let screenType: ScreenType
    public let supported: Bool

    public init(name: String, identifier: String, shortName: String, shortNameAlt: String? = nil, manufacturer: String,
                releaseYear: Int, bits: SystemBits, headerByteSize: Int, openvgDatabaseID: Int, requiresBIOS: Bool = false,
                options: SystemOptions, bioses: [BIOS]? = nil, extensions: [String], games: [Game], cores: [Core], userPreferredCore: Core? = nil, usesCDs: Bool = false, portableSystem: Bool = false, supportsRumble: Bool = false, screenType: ScreenType, supported: Bool = true) {
        self.name = name
        self.identifier = identifier
        self.shortName = shortName
        self.shortNameAlt = shortNameAlt
        self.manufacturer = manufacturer
        self.releaseYear = releaseYear
        self.bits = bits
        self.headerByteSize = headerByteSize
        self.openvgDatabaseID = openvgDatabaseID
        self.requiresBIOS = requiresBIOS
        self.options = options
        self.BIOSes = bioses
        self.extensions = extensions
        self.gameStructs = games
        self.coreStructs = cores
        self.userPreferredCore = userPreferredCore
        self.usesCDs = usesCDs
        self.portableSystem = portableSystem
        self.supportsRumble = supportsRumble
        self.screenType = screenType
        self.supported = supported
    }
}

func compareThing1<T: LocalFileBacked>(_ thing1: T) -> Bool {
    return true
}

public extension System {
    init<S: SystemProtocol>(with system: S) where S.BIOSInfoProviderType: BIOSFileProvider {
        let name = system.name
        let identifier = system.identifier
        let shortName = system.shortName
        let shortNameAlt = system.shortNameAlt
        let manufacturer = system.manufacturer
        let releaseYear = system.releaseYear
        let bits = system.bits
        //        generation = system.generation
        let headerByteSize = system.headerByteSize
        let openvgDatabaseID = system.openvgDatabaseID

        let options = system.options
        let bioses = system.BIOSes?.map { (bios: BIOSInfoProvider) -> BIOS in

            let file: LocalFile?
            if let b = bios as? BIOS {
                file = b.file
            } else {
                file = nil
            }

            let status: BIOSStatus
            if let sp = bios as? BIOSStatusProvider {
                status = sp.status
            } else {
                let available: Bool
                let state: BIOSStatus.State

                if let file = file {
                    available = file.online
                    state = BIOSStatus.State(expectations: bios, file: file)
                } else {
                    available = false
                    state = .missing
                }

                status = BIOSStatus(available: available, required: !bios.optional, state: state)
            }

            return BIOS(descriptionText: bios.descriptionText,
                        regions: bios.regions,
                        version: bios.version,
                        expectedMD5: bios.expectedMD5,
                        expectedSize: bios.expectedSize,
                        expectedFilename: bios.expectedFilename,
                        optional: bios.optional,
                        status: status,
                        file: file)
        }

        let extensions = system.extensions
        let requiresBIOS = system.requiresBIOS
        let games = system.gameStructs
        let cores = system.coreStructs
        let userPreferredCore = system.userPreferredCore

        let usesCDs = system.usesCDs
        let portableSystem = system.portableSystem

        let supportsRumble = system.supportsRumble
        let screenType = system.screenType
        let supported = system.supported
        self.init(name: name, identifier: identifier, shortName: shortName, shortNameAlt: shortNameAlt, manufacturer: manufacturer,
                  releaseYear: releaseYear, bits: bits, headerByteSize: headerByteSize, openvgDatabaseID: openvgDatabaseID, requiresBIOS: requiresBIOS,
                  options: options, bioses: bioses, extensions: extensions, games: games, cores: cores, userPreferredCore: userPreferredCore, usesCDs: usesCDs, portableSystem: portableSystem, supportsRumble: supportsRumble, screenType: screenType, supported: supported)
    }
}
