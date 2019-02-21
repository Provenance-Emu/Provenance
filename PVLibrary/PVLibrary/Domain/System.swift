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
    case nineth
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
}

public extension System {
    init<S: SystemProtocol>(with system: S) where S.BIOSInfoProviderType: BIOSFileProvider {
        name = system.name
        identifier = system.identifier
        shortName = system.shortName
        shortNameAlt = system.shortNameAlt
        manufacturer = system.manufacturer
        releaseYear = system.releaseYear
        bits = system.bits
        //        generation = system.generation
        headerByteSize = system.headerByteSize
        openvgDatabaseID = system.openvgDatabaseID

        options = system.options
        BIOSes = system.BIOSes?.map { (bios: BIOSInfoProvider) in

            #warning("FIX ME, file shoudl be able to beread from incoming if we can test type conformance confidiontally")
            var file: LocalFile?
            //            if bios is LocalFileBacked {
            //                file = (bios as! LocalFileBacked).file
            //            }

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

        extensions = system.extensions
        requiresBIOS = system.requiresBIOS
        gameStructs = system.gameStructs
        coreStructs = system.coreStructs
        userPreferredCore = system.userPreferredCore

        usesCDs = system.usesCDs
        portableSystem = system.portableSystem

        supportsRumble = system.supportsRumble
        screenType = system.screenType
    }
}
