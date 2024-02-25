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
    static var coreClasses: [ClassInfo] {
        let libRetroCoreClass: AnyClass? = NSClassFromString("PVLibRetroCore")
        let libRetroGLESCoreClass: AnyClass? = NSClassFromString("PVLibRetroGLESCore")

        let motherClassInfo = [ClassInfo(PVEmulatorCore.self),
                               ClassInfo(libRetroCoreClass),
                               ClassInfo(libRetroGLESCoreClass)]
        var subclassList = [ClassInfo]()

        var count = UInt32(0)
        let classListPointer = objc_copyClassList(&count)!
        let classList = UnsafeBufferPointer(start: classListPointer, count: Int(count))

        let superclasses = ["PVEmulatorCore", "PVLibRetroCore", "PVLibRetroGLESCore"]
        for i in 0 ..< Int(count) {
            if let classInfo = ClassInfo(classList[i], withSuperclass: superclasses), motherClassInfo.intersects(with: motherClassInfo) {
                subclassList.append(classInfo)
            }
        }

        let filteredList = subclassList.filter {
            let notMasterClass = $0.className != "PVEmulatorCore"
            let className: String = $0.superclassInfo?.className ?? ""
            let inheritsClass = ["PVEmulatorCore", "PVLibRetroCore", "PVLibRetroGLESCore"].contains(className)
            return notMasterClass && inheritsClass
        }

        let classes = filteredList.map { $0.className }.joined(separator: ",")
        ILOG("\(classes)")

        return filteredList
    }

    class func updateCores(fromPlists plists: [URL]) {
        let database = RomDatabase.sharedInstance
        let decoder = PropertyListDecoder()

        plists.forEach { plist in
            do {
                let data = try Data(contentsOf: plist)
                let core = try decoder.decode(CorePlistEntry.self, from: data)
                let supportedSystems = database.all(PVSystem.self, filter: NSPredicate(format: "identifier IN %@", argumentArray: [core.PVSupportedSystems]))
				if let disabled = core.PVDisabled, disabled, !PVSettingsModel.shared.debugOptions.unsupportedCores {
                    // Do nothing
                    ILOG("Skipping disabled core \(core.PVCoreIdentifier)")
                } else {
                    DLOG("Importing core \(core.PVCoreIdentifier)")
                    let newCore = PVCore(withIdentifier: core.PVCoreIdentifier, principleClass: core.PVPrincipleClass, supportedSystems: Array(supportedSystems), name: core.PVProjectName, url: core.PVProjectURL, version: core.PVProjectVersion, disabled: core.PVDisabled ?? false)
                    database.refresh()
                    try newCore.add(update: true)
                }
                if let cores=core.PVCores {
                    try cores.forEach {
                        core in do {
                            let supportedSystems = database.all(PVSystem.self, filter: NSPredicate(format: "identifier IN %@", argumentArray: [core.PVSupportedSystems]))
                            let newCore = PVCore(withIdentifier: core.PVCoreIdentifier, principleClass: core.PVPrincipleClass, supportedSystems: Array(supportedSystems), name: core.PVProjectName, url: core.PVProjectURL, version: core.PVProjectVersion, disabled: core.PVDisabled ?? false)
                            database.refresh()
                            try newCore.add(update: true)
                        } catch let error as DecodingError {
                            ELOG("Failed to parse plist \(plist.path) : \(error)")
                        }
                    }
                }
            } catch let error as DecodingError {
                switch error {
                case let .keyNotFound(key, context):
                    ELOG("Failed to parse plist \(plist.path), \(key), \(context.codingPath): \(error)")
                default:
                    ELOG("Failed to parse plist \(plist.path), : \(error)")
                }
            } catch {
                // Handle error
                ELOG("Failed to parse plist \(plist.path) : \(error)")
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
