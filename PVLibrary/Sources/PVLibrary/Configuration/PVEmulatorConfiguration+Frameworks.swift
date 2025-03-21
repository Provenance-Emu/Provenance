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
import PVPrimitives
import PVRealm

#if canImport(UIKit)
import UIKit
#endif

// MARK: - System Scanner

public extension PVEmulatorConfiguration {
    class func registerCore(_ core: EmulatorCoreInfoProvider) async throws {
        let database = RomDatabase.sharedInstance
        
        let supportedSystems = database.all(PVSystem.self, filter: NSPredicate(format: "identifier IN %@", argumentArray: [core.supportedSystems]))
        let unsupportedCoresAvailable: Bool = Defaults[.unsupportedCores]
        
        if core.disabled, unsupportedCoresAvailable {
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
                                 disabled: core.disabled,
                                 appStoreDisabled: core.appStoreDisabled,
                                 contentless: core.contentless)
            //            database.refresh()
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
                                        disabled: subCore.disabled,
                                        appStoreDisabled: subCore.appStoreDisabled,
                                        contentless: subCore.contentless
                )
                //                database.refresh()
                try newSubCore.add(update: true)
            } catch let error as DecodingError {
                ELOG("Failed to parse plist \(core.projectName) : \(error)")
            }
            }
        }
    }
    
    private static var coresInitialized = false
    /// Parse all core classes
    class func updateCores(fromPlists plists: [EmulatorCoreInfoPlist]) async {
        typealias CorePlistEntries = [CorePlistEntry]
        guard !coresInitialized else { return }
        defer {
            coresInitialized = true
        }
        
        await plists.concurrentForEach { corePlist in
            do {
                try await registerCore(corePlist)
            } catch {
                ELOG("Failed to register core \(corePlist.identifier)")
            }
        }
        //this calls refresh anyway
        await RomDatabase.reloadCache(force: true)
        #if DEBUG
        printListOfSystems()
        #endif
    }
    
    private static var systemsInitialized = false
    /// Parse plists to update PVSystems
    class func updateSystems(fromPlists plists: [URL]) async {
        guard !systemsInitialized else { return }
        defer {
            systemsInitialized = true
        }
        typealias SystemPlistEntries = [SystemPlistEntry]
        let decoder = PropertyListDecoder()
        
        await plists.asyncForEach { plist in
            await processSystemPlist(plist, using: decoder)
        }
    }
    
    /// Print a list of systems for debug use
    class func printListOfSystems() {
        let database = RomDatabase.sharedInstance
        let supportedSystems = database.all(PVSystem.self)
        let systemsList = supportedSystems
            .filter{ $0.cores.count > 0 }
            .sorted{ "\($0.manufacturer)\($0.name)" < "\($1.manufacturer)\($1.name)" }
            .map{ "\($0.manufacturer) - \($0.name)" }
            .joined(separator: "\n")
        ILOG("""
                Supported Systems:
                \(systemsList)
                """)
    }
    
    private static func processSystemPlist(_ plist: URL, using decoder: PropertyListDecoder) async {
        do {
            let systems = try loadSystemEntries(from: plist, using: decoder)
            await updateSystemEntries(systems)
        } catch {
            handlePlistError(error, for: plist)
        }
    }
    
    private static func loadSystemEntries(from url: URL, using decoder: PropertyListDecoder) throws -> [SystemPlistEntry] {
        let data = try Data(contentsOf: url)
        return try decoder.decode([SystemPlistEntry].self, from: data)
    }
    
    private static func updateSystemEntries(_ systems: [SystemPlistEntry]?) async {
        guard let systems = systems else { return }
        
        /// Create mapping of existing systems to their plist entries
        let database = RomDatabase.sharedInstance
        let systemMappings = systems.compactMap { system -> (PVSystem, SystemPlistEntry)? in
            if let existingSystem = database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.PVSystemIdentifier),
               !existingSystem.isInvalidated {
                return (existingSystem, system)
            }
            return nil
        }
        
        /// Process updates and creations separately
        await updateExistingSystems(systemMappings, using: database)
        
        /// Find systems that need to be created
        let newSystems = systems.filter { system in
            database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: system.PVSystemIdentifier) == nil
        }
        
        await createNewSystems(from: newSystems, using: database)
    }

    private static func updateExistingSystems(_ systemMappings: [(PVSystem, SystemPlistEntry)], using database: RomDatabase = .sharedInstance) async {
        do {
            RomDatabase.refresh()
            try database.writeTransaction {
                systemMappings.forEach { (existingSystem, system) in
                    setPropertiesTo(pvSystem: existingSystem, fromSystemPlistEntry: system)
                }
                VLOG("Updated \(systemMappings.count) systems")
            }
        } catch {
            ELOG("Failed to update systems: \(error)")
        }
    }

    private static func createNewSystems(from systems: [SystemPlistEntry], using database: RomDatabase) async {
        RomDatabase.refresh()
        let newSystems: [PVSystem] = systems.map { system in
            let newSystem = PVSystem()
            newSystem.identifier = system.PVSystemIdentifier
            setPropertiesTo(pvSystem: newSystem, fromSystemPlistEntry: system)
            return newSystem
        }
        
        do {
            try database.add(newSystems, update: true)
            DLOG("Added \(newSystems.count) new systems")
        } catch {
            ELOG("Failed to create new systems: \(error)")
        }
    }

    
    private static func createNewSystem(from systems: [SystemPlistEntry], using database: RomDatabase) async {
        
        RomDatabase.refresh()
        let newSystems: [PVSystem] = systems.map { system in
            let newSystem = PVSystem()
            newSystem.identifier = system.PVSystemIdentifier
            setPropertiesTo(pvSystem: newSystem, fromSystemPlistEntry: system)
            return newSystem
        }
        
        do {
            try database.add(newSystems, update: true)
            DLOG("Added new systems for ids \(systems.map(\.PVSystemIdentifier).joined(separator: ", "))")
        } catch {
            ELOG("Failed to create new system: \(error)")
        }
    }
    
    private static func handlePlistError(_ error: Error, for plist: URL) {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case let .keyNotFound(key, context):
                ELOG("""
                    Failed to parse plist \(plist.path)
                    Key: \(key)
                    Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: ","))
                    Error: \(error)
                    """)
            default:
                ELOG("Failed to parse plist \(plist.path): \(error)")
            }
        } else {
            ELOG("Failed to parse plist \(plist.path): \(error)")
        }
    }
    
    class func setPropertiesTo(pvSystem: PVSystem, fromSystemPlistEntry system: SystemPlistEntry) {
        guard !pvSystem.isInvalidated else { return }
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
        pvSystem.appStoreDisabled = system.PVAppStoreDisabled ?? false
        
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
                let database = RomDatabase.sharedInstance
                if database.realm.isInWriteTransaction {
                    database.realm.add(newBIOS)
                } else {
                    RomDatabase.refresh()
                    //avoids conflicts if two BIOS share the same name - looking at you jagboot.rom
                    do {
                        try database.add(newBIOS, update: true)
                    } catch {
                        ELOG("Failed to add BIOS: \(error)")
                    }
                }
            }
        }
    }
}
