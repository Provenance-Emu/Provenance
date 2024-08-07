//  PVEmulatorConfiguration.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/10/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import Foundation
import PVSupport
import RealmSwift
import PVLogging
import PVCoreBridge
import PVPlists

#if canImport(UIKit)
import UIKit
#endif

extension Sequence where Iterator.Element : Hashable {

    func intersects<S : Sequence>(with sequence: S) -> Bool
    where S.Iterator.Element == Iterator.Element {
        let sequenceSet = Set(sequence)
        return self.contains(where: sequenceSet.contains)
    }
}

// MARK: - System Scanner

public extension PVEmulatorConfiguration {
    @MainActor class func registerCore(_ core: EmulatorCoreInfoProvider) async throws {
        let database = RomDatabase.sharedInstance

        let supportedSystems = database.all(PVSystem.self, filter: NSPredicate(format: "identifier IN %@", argumentArray: [core.supportedSystems]))
        let unsupportedCoresAvailable = Task {
            return  await !PVSettingsModel.shared.debugOptions.unsupportedCores
        }

        if core.disabled, await !unsupportedCoresAvailable.value {
            // Do nothing
            ILOG("Skipping disabled core \(core.identifier)")
        } else {
            DLOG("Importing core \(core.identifier)")
            let newCore = PVCore(withIdentifier: core.identifier,
                                 principleClass: core.principleClass,
                                 supportedSystems: Array(supportedSystems),
                                 name: core.projectName,
                                 url: core.projectURL,
                                 version: core.projectVersion,
                                 disabled: core.disabled)
            database.refresh()
            try newCore.add(update: true)
        }
        if let subCorescores = core.subCores {
            try subCorescores.forEach { subCore in do {
                let supportedSystems = database.all(
                    PVSystem.self,
                    filter: NSPredicate(format: "identifier IN %@", argumentArray: [subCore.supportedSystems]))
                let newSubCore = PVCore(withIdentifier: subCore.identifier,
                                        principleClass: subCore.principleClass,
                                        supportedSystems: Array(supportedSystems),
                                        name: subCore.projectName,
                                        url: subCore.projectURL,
                                        version: subCore.projectVersion,
                                        disabled: subCore.disabled)
                database.refresh()
                try newSubCore.add(update: true)
            } catch let error as DecodingError {
                ELOG("Failed to parse plist \(core.projectName) : \(error)")
            }
            }
        }
    }

    class func updateCores(fromPlists plists: [EmulatorCoreInfoPlist]) async {
        typealias CorePlistEntries = [CorePlistEntry]

        await plists.concurrentForEach { corePlist in
            do {
                try await registerCore(corePlist)
            } catch {
                ELOG("Failed to register core \(corePlist.identifier)")
            }
        }
    }

    class func updateSystems(fromPlists plists: [URL]) {
        typealias SystemPlistEntries = [SystemPlistEntry]
        let database = RomDatabase.sharedInstance
        let decoder = PropertyListDecoder()

        plists.forEach { plist in
            do {
                let data = try Data(contentsOf: plist)
                let systems: SystemPlistEntries? = try decoder.decode(SystemPlistEntries.self, from: data)

                systems?.forEach { system in
                    if let existingSystem = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.PVSystemIdentifier) {
                        do {
                            database.refresh()
                            try database.writeTransaction {
                                setPropertiesTo(pvSystem: existingSystem, fromSystemPlistEntry: system)
                                VLOG("Updated system for id \(system.PVSystemIdentifier)")
                            }
                        } catch {
                            ELOG("Failed to make update system: \(error)")
                        }
                    } else {
                        let newSystem = PVSystem()
                        newSystem.identifier = system.PVSystemIdentifier
                        setPropertiesTo(pvSystem: newSystem, fromSystemPlistEntry: system)
                        do {
                            database.refresh()
                            try database.add(newSystem, update: true)
                            DLOG("Added new system for id \(system.PVSystemIdentifier)")
                        } catch {
                            ELOG("Failed to make new system: \(error)")
                        }
                    }
                }
            } catch let error as DecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    ELOG("Failed to parse plist \(plist.path)\n, key:\(key),\n codingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: ","))\nError: \(error)")
                default:
                    ELOG("Failed to parse plist \(plist.path), : \(error)")
                }
            } catch {
                // Handle error
                ELOG("Failed to parse plist \(plist.path) : \(error)")
            }
        }
    }

    class func setPropertiesTo(pvSystem: PVSystem, fromSystemPlistEntry system: SystemPlistEntry) {
        pvSystem.openvgDatabaseID = Int(system.PVDatabaseID) ?? -1
        pvSystem.requiresBIOS = system.PVRequiresBIOS ?? false
        pvSystem.manufacturer = system.PVManufacturer
        pvSystem.bit = Int(system.PVBit) ?? 0
        pvSystem.releaseYear = Int(system.PVReleaseYear)!
        pvSystem.name = system.PVSystemName
#if os(tvOS)    // Show full system names on tvOS
        pvSystem.shortName = system.PVSystemName
#else           // And short names on iOS???
        pvSystem.shortName = system.PVSystemShortName
#endif
        pvSystem.shortNameAlt = system.PVSystemShortNameAlt
        pvSystem.controllerLayout = system.PVControlLayout
        pvSystem.portableSystem = system.PVPortable ?? false
        pvSystem.usesCDs = system.PVUsesCDs ?? false
        pvSystem.supportsRumble = system.PVSupportsRumble ?? false
        pvSystem.headerByteSize = system.PVHeaderByteSize ?? 0

        if let screenType = system.PVScreenType {
            pvSystem.screenType = ScreenType(rawValue: screenType) ?? .unknown
        } else {
            pvSystem.screenType = .unknown
        }
        
        // Iterate extensions and add to Realm object
        pvSystem.supportedExtensions.removeAll()
        pvSystem.supportedExtensions.append(objectsIn: system.PVSupportedExtensions)
        let database = RomDatabase.sharedInstance

        system.PVBIOSNames?.forEach { entry in
            if let existingBIOS = database.object(ofType: PVBIOS.self, wherePrimaryKeyEquals: entry.Name) {
                if database.realm.isInWriteTransaction {
                    existingBIOS.system = pvSystem
                } else {
                    try! database.writeTransaction {
                        existingBIOS.system = pvSystem
                    }
                }
            } else {
                let newBIOS = PVBIOS(withSystem: pvSystem, descriptionText: entry.Description, optional: entry.Optional ?? false, expectedMD5: entry.MD5, expectedSize: entry.Size, expectedFilename: entry.Name)

                if database.realm.isInWriteTransaction {
                    database.realm.add(newBIOS)
                } else {
                    database.refresh()
                    try! database.add(newBIOS)
                }
            }
        }
    }
}
